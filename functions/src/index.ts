import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { selectFeedCards, type FeedCardState } from "./feed.js";
import type { LearningEvent, LearningItem, UserLearningState } from "./generator.js";
import { generatePersonalizedExerciseCardsWithMetadata } from "./generationPipeline.js";
import { buildCardLifecycleMutation, buildInteractionMutation, type CardInteractionType, type CardLifecycleEventType, type ServerSRSItemState, type ServerSkillState } from "./interaction.js";
import { VertexAIGeminiClient, type LLMClient } from "./llmGenerator.js";
import { seedLearningContent } from "./seedContent.js";
import { buildSessionSummary, type BackendProfile } from "./sessionSummary.js";

initializeApp();

const supportedLanguageCodes = new Set(["es", "fr", "de", "it", "pt", "ja", "ko", "zh-Hans", "ru", "en"]);

type GenerateExercisesRequest = {
  languageCode?: unknown;
  existingCardIDs?: unknown;
  limit?: unknown;
};

type RecordCardInteractionRequest = {
  cardId?: unknown;
  interactionType?: unknown;
  response?: unknown;
  responseDuration?: unknown;
  sessionId?: unknown;
};

type RecordCardLifecycleEventRequest = {
  cardId?: unknown;
  eventType?: unknown;
  sessionId?: unknown;
};

type StartLearningSessionRequest = {
  languageCode?: unknown;
  nativeLanguageCode?: unknown;
  goals?: unknown;
  interests?: unknown;
  limit?: unknown;
};

type GetNextFeedCardsRequest = {
  languageCode?: unknown;
  sessionId?: unknown;
  currentCardId?: unknown;
  excludeCardIds?: unknown;
  limit?: unknown;
};

type EndLearningSessionRequest = {
  sessionId?: unknown;
};

export const generateExercises = onCall<GenerateExercisesRequest>(
  {
    region: "us-central1",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    const userID = request.auth?.uid;
    if (!userID) {
      throw new HttpsError("unauthenticated", "Sign in before generating exercises.");
    }

    const languageCode = supportedLanguageCodeValue(request.data.languageCode, "languageCode");
    const existingCardIDs = stringArrayValue(request.data.existingCardIDs, "existingCardIDs");
    const limit = numberValue(request.data.limit, "limit", 6);
    if (limit < 1 || limit > 12) {
      throw new HttpsError("invalid-argument", "limit must be between 1 and 12.");
    }

    const database = getFirestore();
    const [itemsSnapshot, stateSnapshot, itemStatesSnapshot, skillStatesSnapshot, eventsSnapshot] = await Promise.all([
      database.collection("learning_items").where("languageCode", "==", languageCode).get(),
      database.collection("users").doc(userID).collection("learning").doc("state").get(),
      database.collection("users").doc(userID).collection("learning_item_states").get(),
      database.collection("users").doc(userID).collection("skill_states").get(),
      database.collection("users").doc(userID).collection("card_events").orderBy("createdAt", "desc").limit(50).get(),
    ]);

    const items = itemsSnapshot.docs.map((document) => ({ id: document.id, ...document.data() }) as LearningItem);
    const stateData = stateSnapshot.data() ?? {};
    const itemStates = Object.fromEntries(
      itemStatesSnapshot.docs.map((document) => [document.id, srsStateFromFirestore(document.id, document.data())]),
    );
    const userState: UserLearningState = {
      preferences: preferencesFromFirestore(languageCode, stateData.preferences),
      itemStates,
      skillStates: skillStatesFromSnapshot(skillStatesSnapshot),
      recentEvents: eventsSnapshot.docs.map((document) => eventFromFirestore(document.data())),
    };

    const generationStartedAt = Date.now();
    const generation = await generatePersonalizedExerciseCardsWithMetadata({
      languageCode,
      items,
      userState,
      existingCardIDs: new Set(existingCardIDs),
      limit,
      now: new Date(),
    }, {
      llmClient: generationClient(),
    });
    const cards = generation.cards;
    const generationLatencyMs = Date.now() - generationStartedAt;

    const generationRunRef = database.collection("users").doc(userID).collection("generation_runs").doc();
    const inputItemIDs = items
      .filter((item) => item.languageCode === languageCode)
      .slice(0, 20)
      .map((item) => item.id);

    const batch = database.batch();
    if (cards.length > 0) {
      for (const card of cards) {
        batch.set(
          database.collection("cards").doc(card.id),
          {
            ...card,
            languageCode,
            status: "active",
            generated: true,
            generatedBy: userID,
            generatedWith: generation.provider,
            createdAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }

    batch.set(generationRunRef, {
      provider: generation.provider,
      requestedProvider: generation.requestedProvider ?? generation.provider,
      model: generation.provider === "gemini" ? geminiModelName() : null,
      languageCode,
      inputItemIDs,
      existingCardCount: existingCardIDs.length,
      requestedLimit: limit,
      cardIDs: cards.map((card) => card.id),
      status: generation.fallbackUsed ? "fallback" : "success",
      fallbackUsed: generation.fallbackUsed,
      fallbackReason: generation.fallbackReason ?? null,
      acceptedCardCount: generation.diagnostics.acceptedCardCount,
      rejectedCardCount: generation.diagnostics.rejectedCardCount,
      rejectReasons: generation.diagnostics.rejectReasons,
      lessonTypeDistribution: generation.diagnostics.lessonTypeDistribution,
      latencyMs: generationLatencyMs,
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return { cards };
  },
);

export const recordCardInteraction = onCall<RecordCardInteractionRequest>(
  {
    region: "us-central1",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const userID = request.auth?.uid;
    if (!userID) {
      throw new HttpsError("unauthenticated", "Sign in before recording card interactions.");
    }

    const cardID = stringValue(request.data.cardId, "cardId");
    const sessionID = stringValue(request.data.sessionId, "sessionId");
    const interactionType = interactionTypeValue(request.data.interactionType);
    const response = optionalStringValue(request.data.response, "response") ?? "";
    const responseDuration = optionalNumberValue(request.data.responseDuration, "responseDuration");
    const database = getFirestore();

    const cardSnapshot = await database.collection("cards").doc(cardID).get();
    if (!cardSnapshot.exists) {
      throw new HttpsError("not-found", "Card not found.");
    }

    const card = generatedCardFromFirestore(cardSnapshot.id, cardSnapshot.data() ?? {});
    const itemStateRefs = card.targetItemIDs.map((itemID) => database.collection("users").doc(userID).collection("learning_item_states").doc(itemID));
    const skillTags = [...new Set(card.skillTags)];
    const skillStateRefs = skillTags.map((skillTag) => database.collection("users").doc(userID).collection("skill_states").doc(skillTag));
    const [cardStateSnapshot, itemStateSnapshots, skillStateSnapshots] = await Promise.all([
      database.collection("users").doc(userID).collection("card_states").doc(cardID).get(),
      Promise.all(itemStateRefs.map((ref) => ref.get())),
      Promise.all(skillStateRefs.map((ref) => ref.get())),
    ]);
    const existingItemStates = Object.fromEntries(
      itemStateSnapshots.map((snapshot, index) => [
        card.targetItemIDs[index],
        snapshot.exists ? srsStateFromFirestore(card.targetItemIDs[index], snapshot.data() ?? {}) : undefined,
      ]).filter((entry): entry is [string, ServerSRSItemState] => entry[1] !== undefined),
    );
    const existingSkillStates = Object.fromEntries(
      skillStateSnapshots.map((snapshot, index) => [
        skillTags[index],
        snapshot.exists ? skillStateFromFirestore(skillTags[index], snapshot.data() ?? {}) : undefined,
      ]).filter((entry): entry is [string, ServerSkillState] => entry[1] !== undefined),
    );

    const mutation = buildInteractionMutation({
      userID,
      sessionID,
      interactionType,
      response,
      responseDuration,
      card,
      existingItemStates,
      existingSkillStates,
      existingCardState: cardStateSnapshot.data(),
      now: new Date(),
    });

    const userRef = database.collection("users").doc(userID);
    const batch = database.batch();
    const eventData = {
      ...mutation.event,
      createdAt: FieldValue.serverTimestamp(),
      parameters: compactObject(mutation.event.parameters),
    };
    batch.set(userRef.collection("card_events").doc(), eventData);
    batch.set(userRef.collection("events").doc(), eventData);
    batch.set(userRef.collection("card_states").doc(cardID), {
      ...compactObject(mutation.cardState),
      cardID,
      sessionID,
      targetItemIDs: card.targetItemIDs,
      lessonType: card.type,
      skillTags: card.skillTags,
      difficulty: card.difficulty,
      lastInteractionAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    for (const [itemID, state] of Object.entries(mutation.itemStates)) {
      batch.set(userRef.collection("learning_item_states").doc(itemID), srsStateToFirestore(state), { merge: true });
    }

    for (const [skillTag, state] of Object.entries(mutation.skillStates)) {
      batch.set(userRef.collection("skill_states").doc(skillTag), skillStateToFirestore(state), { merge: true });
    }

    batch.set(userRef.collection("session_stats").doc(sessionID), {
      answered: FieldValue.increment(mutation.sessionStatsDelta.answered),
      correct: FieldValue.increment(mutation.sessionStatsDelta.correct),
      skipped: FieldValue.increment(mutation.sessionStatsDelta.skipped),
      deferred: FieldValue.increment(mutation.sessionStatsDelta.deferred),
      tooEasy: FieldValue.increment(mutation.sessionStatsDelta.tooEasy),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    const learningPatch: Record<string, unknown> = {
      seenCardIDs: FieldValue.arrayUnion(cardID),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (interactionType === "answer") learningPatch.answeredCardIDs = FieldValue.arrayUnion(cardID);
    if (interactionType === "tooEasy") learningPatch.tooEasyCardIDs = FieldValue.arrayUnion(cardID);
    batch.set(userRef.collection("learning").doc("state"), learningPatch, { merge: true });

    await batch.commit();
    const nextCard = (await loadFeedCards(database, userID, String(card.languageCode ?? ""), 1, new Set([cardID])))[0] ?? null;

    return {
      isCorrect: mutation.isCorrect ?? null,
      reviewQuality: mutation.reviewQuality ?? null,
      nextCard,
      sessionStatsDelta: mutation.sessionStatsDelta,
    };
  },
);

export const recordCardLifecycleEvent = onCall<RecordCardLifecycleEventRequest>(
  {
    region: "us-central1",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const userID = request.auth?.uid;
    if (!userID) {
      throw new HttpsError("unauthenticated", "Sign in before recording card lifecycle events.");
    }

    const cardID = stringValue(request.data.cardId, "cardId");
    const sessionID = stringValue(request.data.sessionId, "sessionId");
    const eventType = lifecycleEventTypeValue(request.data.eventType);
    const database = getFirestore();

    const [cardSnapshot, cardStateSnapshot] = await Promise.all([
      database.collection("cards").doc(cardID).get(),
      database.collection("users").doc(userID).collection("card_states").doc(cardID).get(),
    ]);
    if (!cardSnapshot.exists) {
      throw new HttpsError("not-found", "Card not found.");
    }

    const card = generatedCardFromFirestore(cardSnapshot.id, cardSnapshot.data() ?? {});
    const mutation = buildCardLifecycleMutation({
      userID,
      sessionID,
      eventType,
      card,
      existingCardState: cardStateSnapshot.data(),
      now: new Date(),
    });

    const userRef = database.collection("users").doc(userID);
    const eventData = {
      ...mutation.event,
      createdAt: FieldValue.serverTimestamp(),
      parameters: compactObject(mutation.event.parameters),
    };
    const cardStatePatch = compactObject({
      ...mutation.cardState,
      cardID,
      sessionID,
      targetItemIDs: card.targetItemIDs,
      lessonType: card.type,
      skillTags: card.skillTags,
      difficulty: card.difficulty,
      lastInteractionAt: FieldValue.serverTimestamp(),
      lastViewedAt: eventType === "viewed" ? FieldValue.serverTimestamp() : undefined,
      lastReturnedAt: eventType === "returned" ? FieldValue.serverTimestamp() : undefined,
    });

    const batch = database.batch();
    batch.set(userRef.collection("card_events").doc(), eventData);
    batch.set(userRef.collection("events").doc(), eventData);
    batch.set(userRef.collection("card_states").doc(cardID), cardStatePatch, { merge: true });
    batch.set(userRef.collection("learning").doc("state"), {
      seenCardIDs: FieldValue.arrayUnion(cardID),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();

    return {
      eventName: mutation.event.name,
      cardState: mutation.cardState,
    };
  },
);

export const startLearningSession = onCall<StartLearningSessionRequest>(
  {
    region: "us-central1",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const userID = request.auth?.uid;
    if (!userID) {
      throw new HttpsError("unauthenticated", "Sign in before starting a learning session.");
    }

    const languageCode = supportedLanguageCodeValue(request.data.languageCode, "languageCode");
    const nativeLanguageCode = supportedLanguageCodeValue(request.data.nativeLanguageCode ?? "en", "nativeLanguageCode");
    const goals = learningGoalsValue(request.data.goals);
    const interests = optionalStringArrayValue(request.data.interests, "interests") ?? defaultInterestsForGoals(goals);
    const limit = boundedLimit(request.data.limit, 5, 1, 12);
    const database = getFirestore();
    await database.collection("users").doc(userID).collection("learning").doc("state").set({
      preferences: {
        targetLanguageCode: languageCode,
        nativeLanguageCode,
        goal: goals[0],
        goals,
        interests,
      },
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    const cards = await loadFeedCards(database, userID, languageCode, limit, new Set(), nativeLanguageCode);
    const sessionID = `session-${languageCode}-${database.collection("users").doc().id.slice(0, 8)}`;
    await database.collection("users").doc(userID).collection("session_stats").doc(sessionID).set({
      languageCode,
      nativeLanguageCode,
      answered: 0,
      correct: 0,
      skipped: 0,
      deferred: 0,
      tooEasy: 0,
      startedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      sessionID,
      cards,
      profile: await loadProfile(database, userID),
      stats: {
        answered: 0,
        correct: 0,
        skipped: 0,
      },
    };
  },
);

export const getNextFeedCards = onCall<GetNextFeedCardsRequest>(
  {
    region: "us-central1",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const userID = request.auth?.uid;
    if (!userID) {
      throw new HttpsError("unauthenticated", "Sign in before loading feed cards.");
    }

    const languageCode = supportedLanguageCodeValue(request.data.languageCode, "languageCode");
    const limit = boundedLimit(request.data.limit, 3, 1, 12);
    const excludeCardIDs = new Set(stringArrayValue(request.data.excludeCardIds ?? [], "excludeCardIds"));
    const currentCardID = optionalStringValue(request.data.currentCardId, "currentCardId");
    if (currentCardID) excludeCardIDs.add(currentCardID);

    const cards = await loadFeedCards(getFirestore(), userID, languageCode, limit, excludeCardIDs);
    return { cards };
  },
);

export const endLearningSession = onCall<EndLearningSessionRequest>(
  {
    region: "us-central1",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const userID = request.auth?.uid;
    if (!userID) {
      throw new HttpsError("unauthenticated", "Sign in before ending a learning session.");
    }

    const sessionID = stringValue(request.data.sessionId, "sessionId");
    const database = getFirestore();
    const userRef = database.collection("users").doc(userID);
    const [sessionStatsSnapshot, skillStatesSnapshot, profile] = await Promise.all([
      userRef.collection("session_stats").doc(sessionID).get(),
      userRef.collection("skill_states").get(),
      loadProfile(database, userID),
    ]);

    return buildSessionSummary({
      sessionStats: sessionStatsSnapshot.data() ?? {},
      profile: profile as BackendProfile,
      skillStates: Object.values(skillStatesFromSnapshot(skillStatesSnapshot)),
    });
  },
);

function generationClient(): LLMClient | undefined {
  if (process.env.LLM_PROVIDER === "rules") return undefined;

  try {
    return new VertexAIGeminiClient();
  } catch {
    return undefined;
  }
}

function geminiModelName(): string {
  return process.env.GEMINI_MODEL ?? "gemini-2.5-flash";
}

function stringValue(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} must be a non-empty string.`);
  }
  return value.trim();
}

function supportedLanguageCodeValue(value: unknown, field: string): string {
  const languageCode = stringValue(value, field);
  if (!supportedLanguageCodes.has(languageCode)) {
    throw new HttpsError("invalid-argument", `${field} must be one of: ${[...supportedLanguageCodes].join(", ")}.`);
  }
  return languageCode;
}

function stringArrayValue(value: unknown, field: string): string[] {
  if (!Array.isArray(value) || !value.every((item) => typeof item === "string")) {
    throw new HttpsError("invalid-argument", `${field} must be an array of strings.`);
  }
  return value;
}

function optionalStringArrayValue(value: unknown, field: string): string[] | undefined {
  if (value == null) return undefined;
  return stringArrayValue(value, field);
}

function learningGoalsValue(value: unknown): string[] {
  const rawGoals = optionalStringArrayValue(value, "goals") ?? ["travel"];
  const uniqueGoals = [...new Set(rawGoals.map((goal) => goal.trim()).filter((goal) => goal.length > 0))];
  const supportedGoals = new Set(["travel", "work", "dating", "relocation", "study", "everyday"]);
  const goals = uniqueGoals.filter((goal) => supportedGoals.has(goal));
  if (goals.length === 0) return ["travel"];
  return goals;
}

function defaultInterestsForGoals(goals: string[]): string[] {
  const byGoal: Record<string, string[]> = {
    travel: ["airport", "hotel", "restaurant", "directions"],
    work: ["career", "meetings", "email", "small_talk"],
    dating: ["small_talk", "feelings", "compliments", "plans"],
    relocation: ["housing", "documents", "healthcare", "banking"],
    study: ["campus", "classroom", "exams", "friends"],
    everyday: ["shopping", "coffee", "transport", "home"],
  };
  return [...new Set(goals.flatMap((goal) => byGoal[goal] ?? []))].slice(0, 8);
}

function numberValue(value: unknown, field: string, fallback: number): number {
  if (value == null) return fallback;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${field} must be a number.`);
  }
  return Math.round(value);
}

function boundedLimit(value: unknown, fallback: number, minimum: number, maximum: number): number {
  const limit = numberValue(value, "limit", fallback);
  if (limit < minimum || limit > maximum) {
    throw new HttpsError("invalid-argument", `limit must be between ${minimum} and ${maximum}.`);
  }
  return limit;
}

function optionalNumberValue(value: unknown, field: string): number | undefined {
  if (value == null) return undefined;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${field} must be a number.`);
  }
  return value;
}

function optionalStringValue(value: unknown, field: string): string | undefined {
  if (value == null) return undefined;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  return value;
}

function interactionTypeValue(value: unknown): CardInteractionType {
  if (value === "answer" || value === "skip" || value === "defer" || value === "tooEasy") return value;
  throw new HttpsError("invalid-argument", "interactionType must be answer, skip, defer, or tooEasy.");
}

function lifecycleEventTypeValue(value: unknown): CardLifecycleEventType {
  if (value === "viewed" || value === "returned") return value;
  throw new HttpsError("invalid-argument", "eventType must be viewed or returned.");
}

function preferencesFromFirestore(languageCode: string, value: unknown, nativeLanguageCode = "en"): UserLearningState["preferences"] {
  const data = isRecord(value) ? value : {};
  return {
    targetLanguageCode: stringOrDefault(data.targetLanguageCode, languageCode),
    nativeLanguageCode: stringOrDefault(data.nativeLanguageCode, nativeLanguageCode),
    level: stringOrDefault(data.level, "A1"),
    goal: stringOrDefault(data.goal, "travel"),
    goals: Array.isArray(data.goals)
      ? data.goals.filter((item): item is string => typeof item === "string")
      : [stringOrDefault(data.goal, "travel")],
    interests: Array.isArray(data.interests) ? data.interests.filter((item): item is string => typeof item === "string") : [],
    dailyMinutes: typeof data.dailyMinutes === "number" ? data.dailyMinutes : 5,
  };
}

function srsStateFromFirestore(itemID: string, data: FirebaseFirestore.DocumentData): UserLearningState["itemStates"][string] {
  return {
    itemID,
    kind: stringOrDefault(data.kind, "phrase"),
    strength: numberOrDefault(data.strength, 0.25),
    difficulty: numberOrDefault(data.difficulty, 0.5),
    repetitions: numberOrDefault(data.repetitions, 0),
    lapses: numberOrDefault(data.lapses, 0),
    nextReviewAt: dateString(data.nextReviewAt),
  };
}

function srsStateToFirestore(state: ServerSRSItemState): FirebaseFirestore.DocumentData {
  return compactObject({
    itemID: state.itemID,
    kind: state.kind,
    strength: state.strength,
    difficulty: state.difficulty,
    repetitions: state.repetitions,
    lapses: state.lapses,
    lastReviewedAt: state.lastReviewedAt ? new Date(state.lastReviewedAt) : undefined,
    nextReviewAt: new Date(state.nextReviewAt),
  });
}

function skillStateFromFirestore(skillTag: string, data: FirebaseFirestore.DocumentData): ServerSkillState {
  return {
    skillTag,
    weakness: numberOrDefault(data.weakness, 0.5),
    attempts: numberOrDefault(data.attempts, 0),
    correct: numberOrDefault(data.correct, 0),
    lastReviewedAt: dateString(data.lastReviewedAt),
  };
}

function skillStateToFirestore(state: ServerSkillState): FirebaseFirestore.DocumentData {
  return compactObject({
    skillTag: state.skillTag,
    weakness: state.weakness,
    attempts: state.attempts,
    correct: state.correct,
    lastReviewedAt: state.lastReviewedAt ? new Date(state.lastReviewedAt) : undefined,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function generatedCardFromFirestore(id: string, data: FirebaseFirestore.DocumentData) {
  return {
    id,
    type: stringOrDefault(data.type, "translate") as "translate",
    context: stringOrDefault(data.context, ""),
    situation: stringOrDefault(data.situation, ""),
    prompt: stringOrDefault(data.prompt, ""),
    options: stringArrayOrEmpty(data.options),
    correctAnswer: stringOrDefault(data.correctAnswer, ""),
    explanation: stringOrDefault(data.explanation, ""),
    chatMessages: Array.isArray(data.chatMessages) ? data.chatMessages : [],
    targetItemIDs: stringArrayOrEmpty(data.targetItemIDs),
    skillTags: stringArrayOrEmpty(data.skillTags),
    difficulty: numberOrDefault(data.difficulty, 1),
    missionID: stringOrDefault(data.missionID, ""),
    languageCode: stringOrDefault(data.languageCode, ""),
    generatedWith: typeof data.generatedWith === "string" ? data.generatedWith : data.generated === true ? "rules" : "seed",
  };
}

async function loadFeedCards(
  database: FirebaseFirestore.Firestore,
  userID: string,
  languageCode: string,
  limit: number,
  excludeCardIDs: Set<string> = new Set(),
  nativeLanguageCode = "en",
): Promise<Array<Record<string, unknown>>> {
  const [cardsSnapshot, cardStatesSnapshot, itemStatesSnapshot, skillStatesSnapshot, stateSnapshot, eventsSnapshot] = await Promise.all([
    database.collection("cards").where("languageCode", "==", languageCode).where("status", "==", "active").limit(50).get(),
    database.collection("users").doc(userID).collection("card_states").get(),
    database.collection("users").doc(userID).collection("learning_item_states").get(),
    database.collection("users").doc(userID).collection("skill_states").get(),
    database.collection("users").doc(userID).collection("learning").doc("state").get(),
    database.collection("users").doc(userID).collection("card_events").orderBy("createdAt", "desc").limit(20).get(),
  ]);

  const stateData = stateSnapshot.data() ?? {};
  const cards = cardsSnapshot.docs.map((document) => generatedCardFromFirestore(document.id, document.data()));
  const userState: UserLearningState = {
    preferences: preferencesFromFirestore(languageCode, stateData.preferences, nativeLanguageCode),
    itemStates: Object.fromEntries(itemStatesSnapshot.docs.map((document) => [document.id, srsStateFromFirestore(document.id, document.data())])),
    skillStates: skillStatesFromSnapshot(skillStatesSnapshot),
    recentEvents: eventsSnapshot.docs.map((document) => eventFromFirestore(document.data())),
  };
  const cardStates = Object.fromEntries(cardStatesSnapshot.docs.map((document) => [document.id, document.data() as FeedCardState]));
  let selected = selectFeedCards({
    cards,
    cardStates,
    userState,
    recentEvents: userState.recentEvents ?? [],
    now: new Date(),
    limit,
    excludeCardIDs,
  });

  if (selected.length < limit) {
    const itemsSnapshot = await database.collection("learning_items").where("languageCode", "==", languageCode).get();
    if (itemsSnapshot.empty && cards.length === 0) {
      const seed = seedLearningContent(languageCode);
      const batch = database.batch();
      for (const item of seed.items) {
        batch.set(database.collection("learning_items").doc(item.id), item, { merge: true });
      }
      for (const card of seed.cards) {
        batch.set(database.collection("cards").doc(card.id), {
          ...card,
          languageCode,
          status: "active",
          generated: false,
          generatedWith: "seed",
          createdAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      await batch.commit();

      selected = selectFeedCards({
        cards: seed.cards,
        cardStates,
        userState,
        recentEvents: userState.recentEvents ?? [],
        now: new Date(),
        limit,
        excludeCardIDs,
      });
    }

    if (selected.length >= limit) {
      return selected.map((card) => ({ ...card, languageCode }));
    }

    const generationStartedAt = Date.now();
    const items = itemsSnapshot.empty
      ? seedLearningContent(languageCode).items
      : itemsSnapshot.docs.map((document) => ({ id: document.id, ...document.data() }) as LearningItem);
    const generation = await generatePersonalizedExerciseCardsWithMetadata({
      languageCode,
      items,
      userState,
      existingCardIDs: new Set([...cards.map((card) => card.id), ...excludeCardIDs]),
      limit: limit - selected.length,
      now: new Date(),
    }, { llmClient: generationClient() });
    if (generation.cards.length > 0) {
      const generationLatencyMs = Date.now() - generationStartedAt;
      const batch = database.batch();
      for (const card of generation.cards) {
        batch.set(database.collection("cards").doc(card.id), {
          ...card,
          languageCode,
          status: "active",
          generated: true,
          generatedBy: userID,
          generatedWith: generation.provider,
          createdAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      batch.set(database.collection("users").doc(userID).collection("generation_runs").doc(), {
        provider: generation.provider,
        requestedProvider: generation.requestedProvider ?? generation.provider,
        model: generation.provider === "gemini" ? geminiModelName() : null,
        languageCode,
        inputItemIDs: items.slice(0, 20).map((item) => item.id),
        existingCardCount: cards.length + excludeCardIDs.size,
        requestedLimit: limit - selected.length,
        cardIDs: generation.cards.map((card) => card.id),
        status: generation.fallbackUsed ? "fallback" : "success",
        fallbackUsed: generation.fallbackUsed,
        fallbackReason: generation.fallbackReason ?? null,
        acceptedCardCount: generation.diagnostics.acceptedCardCount,
        rejectedCardCount: generation.diagnostics.rejectedCardCount,
        rejectReasons: generation.diagnostics.rejectReasons,
        lessonTypeDistribution: generation.diagnostics.lessonTypeDistribution,
        latencyMs: generationLatencyMs,
        createdAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
      selected = [...selected, ...generation.cards].slice(0, limit);
    }
  }

  return selected.map((card) => ({ ...card, languageCode }));
}

async function loadProfile(database: FirebaseFirestore.Firestore, userID: string): Promise<Record<string, unknown>> {
  const [itemStatesSnapshot, skillStatesSnapshot] = await Promise.all([
    database.collection("users").doc(userID).collection("learning_item_states").get(),
    database.collection("users").doc(userID).collection("skill_states").get(),
  ]);
  const states = itemStatesSnapshot.docs.map((document) => srsStateFromFirestore(document.id, document.data()));
  const weakSkillTopics = Object.values(skillStatesFromSnapshot(skillStatesSnapshot))
    .filter((state) => state.weakness >= 0.55 && state.attempts > 0)
    .sort((left, right) => right.weakness - left.weakness || left.skillTag.localeCompare(right.skillTag))
    .slice(0, 3)
    .map((state) => state.skillTag);
  return {
    streak: 1,
    totalLearned: states.filter((state) => state.strength >= 0.65).length,
    weakTopics: weakSkillTopics.length > 0
      ? weakSkillTopics
      : states.filter((state) => state.strength < 0.45 && state.repetitions > 0).slice(0, 3).map((state) => state.itemID),
  };
}

function skillStatesFromSnapshot(snapshot: FirebaseFirestore.QuerySnapshot): NonNullable<UserLearningState["skillStates"]> {
  return Object.fromEntries(
    snapshot.docs.map((document) => [document.id, skillStateFromFirestore(document.id, document.data())]),
  );
}

function eventFromFirestore(data: FirebaseFirestore.DocumentData): LearningEvent {
  const parameters = isRecord(data.parameters) ? data.parameters : {};
  return {
    name: stringOrDefault(data.name, "unknown"),
    createdAt: dateString(data.createdAt),
    parameters: {
      card_id: typeof parameters.card_id === "string" ? parameters.card_id : undefined,
      is_correct: typeof parameters.is_correct === "boolean" ? parameters.is_correct : undefined,
      target_item_ids: stringArrayOrEmpty(parameters.target_item_ids),
      lesson_type: typeof parameters.lesson_type === "string" ? parameters.lesson_type : typeof data.lessonType === "string" ? data.lessonType : undefined,
    },
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function stringOrDefault(value: unknown, fallback: string): string {
  return typeof value === "string" && value.length > 0 ? value : fallback;
}

function numberOrDefault(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function stringArrayOrEmpty(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function compactObject<T extends Record<string, unknown>>(value: T): Partial<T> {
  return Object.fromEntries(Object.entries(value).filter(([, item]) => item !== undefined)) as Partial<T>;
}

function dateString(value: unknown): string {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "string") return value;
  return new Date(0).toISOString();
}

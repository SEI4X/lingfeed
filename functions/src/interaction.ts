import type { GeneratedCard, UserLearningState } from "./generator.js";

export type CardInteractionType = "answer" | "skip" | "defer" | "tooEasy";
export type CardLifecycleEventType = "viewed" | "returned";
export type ReviewQuality = "again" | "hard" | "good" | "easy";
export type CardStateStatus = "unseen" | "seen" | "deferred" | "answered" | "skipped" | "tooEasy";

export type ServerSRSItemState = UserLearningState["itemStates"][string] & {
  lastReviewedAt?: string;
};

export type ServerCardState = {
  status?: CardStateStatus;
  answerCount?: number;
  viewCount?: number;
  returnCount?: number;
  lastAnswerCorrect?: boolean;
  lastInteractionAt?: string;
};

export type ServerSkillState = {
  skillTag: string;
  weakness: number;
  attempts: number;
  correct: number;
  lastReviewedAt?: string;
};

export type InteractionEvent = {
  name: "card_answered" | "card_skipped" | "card_deferred" | "card_too_easy" | "card_viewed" | "card_returned";
  userID: string;
  sessionID: string;
  cardID: string;
  itemIDs: string[];
  lessonType: GeneratedCard["type"];
  skillTags: string[];
  difficulty: number;
  generationSource?: string;
  createdAt: string;
  parameters: {
    card_id: string;
    target_item_ids: string[];
    is_correct?: boolean;
    response?: string;
    response_duration?: number;
    review_quality?: ReviewQuality;
  };
};

export type CardLifecycleMutationInput = {
  userID: string;
  sessionID: string;
  eventType: CardLifecycleEventType;
  card: GeneratedCard & { generatedWith?: string };
  existingCardState?: ServerCardState;
  now: Date;
};

export type CardLifecycleMutation = {
  cardState: Required<Pick<ServerCardState, "status" | "answerCount" | "viewCount" | "returnCount" | "lastInteractionAt">> & Pick<ServerCardState, "lastAnswerCorrect">;
  event: InteractionEvent;
  sessionStatsDelta: InteractionMutation["sessionStatsDelta"];
};

export type InteractionMutationInput = {
  userID: string;
  sessionID: string;
  interactionType: CardInteractionType;
  response?: string;
  responseDuration?: number;
  card: GeneratedCard & { generatedWith?: string };
  existingItemStates: Record<string, ServerSRSItemState>;
  existingSkillStates?: Record<string, ServerSkillState>;
  existingCardState?: ServerCardState;
  now: Date;
};

export type InteractionMutation = {
  isCorrect?: boolean;
  reviewQuality?: ReviewQuality;
  itemStates: Record<string, ServerSRSItemState>;
  skillStates: Record<string, ServerSkillState>;
  cardState: Required<Pick<ServerCardState, "status" | "answerCount" | "lastInteractionAt">> & Pick<ServerCardState, "lastAnswerCorrect">;
  event: InteractionEvent;
  sessionStatsDelta: {
    answered: number;
    correct: number;
    skipped: number;
    deferred: number;
    tooEasy: number;
  };
};

export function buildInteractionMutation(input: InteractionMutationInput): InteractionMutation {
  const now = input.now.toISOString();
  const isAnswer = input.interactionType === "answer";
  const isCorrect = isAnswer ? normalize(input.response ?? "") === normalize(input.card.correctAnswer) : undefined;
  const reviewQuality = reviewQualityFor(input.interactionType, isCorrect, input.responseDuration);
  const itemStates = reviewQuality && input.interactionType !== "defer"
    ? reviewedItemStates(input.card, input.existingItemStates, reviewQuality, input.now)
    : {};
  const skillStates = reviewQuality && input.interactionType !== "defer"
    ? reviewedSkillStates(input.card, input.existingSkillStates ?? {}, reviewQuality, isCorrect, input.now)
    : {};
  const answerCount = (input.existingCardState?.answerCount ?? 0) + (isAnswer ? 1 : 0);
  const cardState = {
    status: statusFor(input.interactionType),
    answerCount,
    lastInteractionAt: now,
    lastAnswerCorrect: isAnswer ? isCorrect : input.existingCardState?.lastAnswerCorrect,
  };

  return {
    isCorrect,
    reviewQuality,
    itemStates,
    skillStates,
    cardState,
    event: {
      name: eventNameFor(input.interactionType),
      userID: input.userID,
      sessionID: input.sessionID,
      cardID: input.card.id,
      itemIDs: input.card.targetItemIDs,
      lessonType: input.card.type,
      skillTags: input.card.skillTags,
      difficulty: input.card.difficulty,
      generationSource: input.card.generatedWith,
      createdAt: now,
      parameters: {
        card_id: input.card.id,
        target_item_ids: input.card.targetItemIDs,
        is_correct: isCorrect,
        response: isAnswer ? input.response ?? "" : undefined,
        response_duration: input.responseDuration,
        review_quality: reviewQuality,
      },
    },
    sessionStatsDelta: sessionStatsDeltaFor(input.interactionType, isCorrect),
  };
}

export function buildCardLifecycleMutation(input: CardLifecycleMutationInput): CardLifecycleMutation {
  const now = input.now.toISOString();
  const existingStatus = input.existingCardState?.status;
  const isReturn = input.eventType === "returned";
  const cardState = {
    status: isReturn ? existingStatus ?? "seen" : statusAfterView(existingStatus),
    answerCount: input.existingCardState?.answerCount ?? 0,
    viewCount: (input.existingCardState?.viewCount ?? 0) + (isReturn ? 0 : 1),
    returnCount: (input.existingCardState?.returnCount ?? 0) + (isReturn ? 1 : 0),
    lastInteractionAt: now,
    lastAnswerCorrect: input.existingCardState?.lastAnswerCorrect,
  };

  return {
    cardState,
    event: {
      name: isReturn ? "card_returned" : "card_viewed",
      userID: input.userID,
      sessionID: input.sessionID,
      cardID: input.card.id,
      itemIDs: input.card.targetItemIDs,
      lessonType: input.card.type,
      skillTags: input.card.skillTags,
      difficulty: input.card.difficulty,
      generationSource: input.card.generatedWith,
      createdAt: now,
      parameters: {
        card_id: input.card.id,
        target_item_ids: input.card.targetItemIDs,
      },
    },
    sessionStatsDelta: {
      answered: 0,
      correct: 0,
      skipped: 0,
      deferred: 0,
      tooEasy: 0,
    },
  };
}

export function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLocaleLowerCase("en-US")
    .replace(/[^\p{Letter}\p{Number}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function reviewedItemStates(
  card: GeneratedCard,
  existingItemStates: Record<string, ServerSRSItemState>,
  quality: ReviewQuality,
  now: Date,
): Record<string, ServerSRSItemState> {
  return Object.fromEntries(card.targetItemIDs.map((itemID) => [
    itemID,
    applyReview(existingItemStates[itemID] ?? newItemState(itemID, now), quality, now),
  ]));
}

function newItemState(itemID: string, now: Date): ServerSRSItemState {
  return {
    itemID,
    kind: "phrase",
    strength: 0.25,
    difficulty: 0.5,
    repetitions: 0,
    lapses: 0,
    nextReviewAt: now.toISOString(),
  };
}

function applyReview(state: ServerSRSItemState, quality: ReviewQuality, now: Date): ServerSRSItemState {
  const updated = { ...state, lastReviewedAt: now.toISOString() };
  const previous = { ...state };
  switch (quality) {
    case "again":
      updated.lapses += 1;
      updated.strength = round2(Math.max(0.05, updated.strength - (0.22 + Math.min(0.12, updated.lapses * 0.03))));
      updated.difficulty = round2(Math.min(1, updated.difficulty + 0.1));
      updated.nextReviewAt = addSeconds(now, 10 * 60);
      break;
    case "hard":
      updated.repetitions += 1;
      updated.strength = round2(Math.min(1, updated.strength + 0.08));
      updated.difficulty = round2(Math.min(1, updated.difficulty + 0.04));
      updated.nextReviewAt = addSeconds(now, 24 * 60 * 60);
      break;
    case "good":
      updated.repetitions += 1;
      updated.strength = round2(Math.min(1, updated.strength + 0.18));
      updated.difficulty = round2(Math.max(0, updated.difficulty - 0.02));
      updated.nextReviewAt = addDays(now, dynamicIntervalDays(previous, "good"));
      break;
    case "easy":
      updated.repetitions += 1;
      updated.strength = round2(Math.min(1, updated.strength + 0.32));
      updated.difficulty = round2(Math.max(0, updated.difficulty - 0.06));
      updated.nextReviewAt = addDays(now, dynamicIntervalDays(previous, "easy"));
      break;
  }
  return updated;
}

function reviewedSkillStates(
  card: GeneratedCard,
  existingSkillStates: Record<string, ServerSkillState>,
  quality: ReviewQuality,
  isCorrect: boolean | undefined,
  now: Date,
): Record<string, ServerSkillState> {
  return Object.fromEntries(unique(card.skillTags).map((skillTag) => [
    skillTag,
    applySkillReview(existingSkillStates[skillTag] ?? newSkillState(skillTag), quality, isCorrect, now),
  ]));
}

function newSkillState(skillTag: string): ServerSkillState {
  return {
    skillTag,
    weakness: 0.5,
    attempts: 0,
    correct: 0,
  };
}

function applySkillReview(
  state: ServerSkillState,
  quality: ReviewQuality,
  isCorrect: boolean | undefined,
  now: Date,
): ServerSkillState {
  const correct = quality === "easy" || quality === "good" || (quality === "hard" && isCorrect !== false);
  const weaknessDelta = (() => {
    if (quality === "again") return 0.22;
    if (quality === "hard") return 0.08;
    if (quality === "good") return -0.08;
    return -0.16;
  })();

  return {
    skillTag: state.skillTag,
    weakness: round2(clamp(state.weakness + weaknessDelta, 0, 1)),
    attempts: state.attempts + 1,
    correct: state.correct + (correct ? 1 : 0),
    lastReviewedAt: now.toISOString(),
  };
}

function dynamicIntervalDays(state: ServerSRSItemState, quality: "good" | "easy"): number {
  const raw = quality === "good"
    ? 1 + state.repetitions * 1.4 + state.strength * 4 - state.difficulty * 1.5 - state.lapses * 0.5
    : 3 + state.repetitions * 2.2 + state.strength * 7 - state.difficulty * 1.5 - state.lapses * 0.5;
  return Math.round(clamp(raw, quality === "good" ? 1 : 3, quality === "good" ? 21 : 45));
}

function reviewQualityFor(type: CardInteractionType, isCorrect: boolean | undefined, responseDuration: number | undefined): ReviewQuality | undefined {
  if (type === "defer") return undefined;
  if (type === "skip") return "again";
  if (type === "tooEasy") return "easy";
  if (!isCorrect) return "again";
  if (responseDuration == null) return "good";
  if (responseDuration <= 8) return "easy";
  if (responseDuration >= 20) return "hard";
  return "good";
}

function statusFor(type: CardInteractionType): CardStateStatus {
  switch (type) {
    case "answer": return "answered";
    case "skip": return "skipped";
    case "defer": return "deferred";
    case "tooEasy": return "tooEasy";
  }
}

function statusAfterView(status: CardStateStatus | undefined): CardStateStatus {
  if (status == null || status === "unseen") return "seen";
  return status;
}

function eventNameFor(type: CardInteractionType): InteractionEvent["name"] {
  switch (type) {
    case "answer": return "card_answered";
    case "skip": return "card_skipped";
    case "defer": return "card_deferred";
    case "tooEasy": return "card_too_easy";
  }
}

function sessionStatsDeltaFor(type: CardInteractionType, isCorrect: boolean | undefined): InteractionMutation["sessionStatsDelta"] {
  return {
    answered: type === "answer" || type === "skip" ? 1 : 0,
    correct: type === "answer" && isCorrect ? 1 : 0,
    skipped: type === "skip" ? 1 : 0,
    deferred: type === "defer" ? 1 : 0,
    tooEasy: type === "tooEasy" ? 1 : 0,
  };
}

function addSeconds(date: Date, seconds: number): string {
  return new Date(date.getTime() + seconds * 1_000).toISOString();
}

function addDays(date: Date, days: number): string {
  return addSeconds(date, days * 24 * 60 * 60);
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}

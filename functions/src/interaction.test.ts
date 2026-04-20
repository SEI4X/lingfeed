import assert from "node:assert/strict";
import test from "node:test";
import { buildCardLifecycleMutation, buildInteractionMutation } from "./interaction.js";
import type { GeneratedCard } from "./generator.js";

test("answer interaction computes correctness and updates item state, card state, event, and session stats", () => {
  const mutation = buildInteractionMutation({
    userID: "user-1",
    sessionID: "session-1",
    interactionType: "answer",
    response: "para llevar",
    responseDuration: 4,
    card: card(),
    existingItemStates: {},
    existingCardState: undefined,
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.isCorrect, true);
  assert.equal(mutation.reviewQuality, "easy");
  assert.equal(mutation.event.name, "card_answered");
  assert.equal(mutation.event.parameters.is_correct, true);
  assert.equal(mutation.event.parameters.response_duration, 4);
  assert.equal(mutation.cardState.status, "answered");
  assert.equal(mutation.cardState.answerCount, 1);
  assert.equal(mutation.cardState.lastAnswerCorrect, true);
  assert.equal(mutation.itemStates.es_phrase_para_llevar?.repetitions, 1);
  assert.equal(mutation.itemStates.es_phrase_para_llevar?.nextReviewAt, "2026-04-23T08:00:00.000Z");
  assert.deepEqual(mutation.sessionStatsDelta, { answered: 1, correct: 1, skipped: 0, deferred: 0, tooEasy: 0 });
});

test("defer interaction records card state without reviewing target items", () => {
  const mutation = buildInteractionMutation({
    userID: "user-1",
    sessionID: "session-1",
    interactionType: "defer",
    response: "",
    card: card(),
    existingItemStates: {},
    existingCardState: undefined,
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.isCorrect, undefined);
  assert.equal(mutation.reviewQuality, undefined);
  assert.equal(mutation.event.name, "card_deferred");
  assert.equal(mutation.cardState.status, "deferred");
  assert.equal(mutation.cardState.answerCount, 0);
  assert.deepEqual(mutation.itemStates, {});
  assert.deepEqual(mutation.sessionStatsDelta, { answered: 0, correct: 0, skipped: 0, deferred: 1, tooEasy: 0 });
});

test("wrong answer brings reviewed items back soon and increments lapses", () => {
  const mutation = buildInteractionMutation({
    userID: "user-1",
    sessionID: "session-1",
    interactionType: "answer",
    response: "por favor",
    responseDuration: 11,
    card: card(),
    existingItemStates: {
      es_phrase_para_llevar: {
        itemID: "es_phrase_para_llevar",
        kind: "phrase",
        strength: 0.7,
        difficulty: 0.4,
        repetitions: 3,
        lapses: 0,
        nextReviewAt: "2026-04-19T08:00:00.000Z",
      },
    },
    existingCardState: { answerCount: 2, status: "seen" },
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.isCorrect, false);
  assert.equal(mutation.reviewQuality, "again");
  assert.equal(mutation.cardState.answerCount, 3);
  assert.equal(mutation.itemStates.es_phrase_para_llevar?.repetitions, 3);
  assert.equal(mutation.itemStates.es_phrase_para_llevar?.lapses, 1);
  assert.equal(mutation.itemStates.es_phrase_para_llevar?.nextReviewAt, "2026-04-19T08:10:00.000Z");
  assert.deepEqual(mutation.sessionStatsDelta, { answered: 1, correct: 0, skipped: 0, deferred: 0, tooEasy: 0 });
});

test("easy review interval grows for stronger repeated items instead of staying fixed", () => {
  const mutation = buildInteractionMutation({
    userID: "user-1",
    sessionID: "session-1",
    interactionType: "answer",
    response: "para llevar",
    responseDuration: 3,
    card: card(),
    existingItemStates: {
      es_phrase_para_llevar: {
        itemID: "es_phrase_para_llevar",
        kind: "phrase",
        strength: 0.78,
        difficulty: 0.2,
        repetitions: 5,
        lapses: 0,
        nextReviewAt: "2026-04-19T08:00:00.000Z",
      },
    },
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.reviewQuality, "easy");
  assert.equal(mutation.itemStates.es_phrase_para_llevar?.nextReviewAt, "2026-05-08T08:00:00.000Z");
});

test("interaction updates skill weakness separately from item SRS", () => {
  const mutation = buildInteractionMutation({
    userID: "user-1",
    sessionID: "session-1",
    interactionType: "answer",
    response: "wrong",
    responseDuration: 6,
    card: card(),
    existingItemStates: {},
    existingSkillStates: {
      coffee: {
        skillTag: "coffee",
        weakness: 0.4,
        attempts: 2,
        correct: 1,
      },
    },
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.skillStates.coffee?.attempts, 3);
  assert.equal(mutation.skillStates.coffee?.correct, 1);
  assert.equal(mutation.skillStates.coffee?.weakness, 0.62);
  assert.equal(mutation.skillStates.coffee?.lastReviewedAt, "2026-04-19T08:00:00.000Z");
});

test("answer normalization keeps Cyrillic letters distinct", () => {
  const mutation = buildInteractionMutation({
    userID: "user-1",
    sessionID: "session-1",
    interactionType: "answer",
    response: "кофе",
    responseDuration: 4,
    card: {
      ...card(),
      correctAnswer: "Я хочу кофе",
      targetItemIDs: ["ru_lexeme_ya", "ru_lexeme_hochu", "ru_lexeme_kofe"],
    },
    existingItemStates: {},
    existingCardState: undefined,
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.isCorrect, false);
});

test("viewed lifecycle event marks unseen card as seen without SRS or stats changes", () => {
  const mutation = buildCardLifecycleMutation({
    userID: "user-1",
    sessionID: "session-1",
    eventType: "viewed",
    card: card(),
    existingCardState: undefined,
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.event.name, "card_viewed");
  assert.equal(mutation.cardState.status, "seen");
  assert.equal(mutation.cardState.viewCount, 1);
  assert.equal(mutation.cardState.returnCount, 0);
  assert.equal(mutation.cardState.answerCount, 0);
  assert.equal(mutation.event.parameters.card_id, "card-1");
  assert.deepEqual(mutation.sessionStatsDelta, { answered: 0, correct: 0, skipped: 0, deferred: 0, tooEasy: 0 });
});

test("returned lifecycle event keeps answered card state while counting returns", () => {
  const mutation = buildCardLifecycleMutation({
    userID: "user-1",
    sessionID: "session-1",
    eventType: "returned",
    card: card(),
    existingCardState: {
      status: "answered",
      answerCount: 1,
      viewCount: 2,
      returnCount: 1,
      lastAnswerCorrect: false,
    },
    now: new Date("2026-04-19T08:00:00.000Z"),
  });

  assert.equal(mutation.event.name, "card_returned");
  assert.equal(mutation.cardState.status, "answered");
  assert.equal(mutation.cardState.viewCount, 2);
  assert.equal(mutation.cardState.returnCount, 2);
  assert.equal(mutation.cardState.answerCount, 1);
  assert.equal(mutation.cardState.lastAnswerCorrect, false);
});

function card(): GeneratedCard {
  return {
    id: "card-1",
    type: "translate",
    context: "A1 / coffee",
    situation: "You are ordering coffee.",
    prompt: "to go",
    options: [],
    correctAnswer: "para llevar",
    explanation: "Use para llevar for takeaway orders.",
    chatMessages: [],
    targetItemIDs: ["es_phrase_para_llevar"],
    skillTags: ["coffee"],
    difficulty: 1,
    missionID: "coffee",
  };
}

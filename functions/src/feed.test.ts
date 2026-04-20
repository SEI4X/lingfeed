import assert from "node:assert/strict";
import test from "node:test";
import { selectFeedCards } from "./feed.js";
import type { GeneratedCard, UserLearningState } from "./generator.js";

test("selects due weak cards before new cards and excludes answered or too easy cards", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const cards = [
    card("answered", "translate", ["new_item"]),
    card("fresh", "translate", ["new_item"]),
    card("due", "fillGap", ["due_item"]),
    card("too-easy", "reorder", ["new_item"]),
  ];

  const selected = selectFeedCards({
    cards,
    cardStates: {
      answered: { status: "answered" },
      "too-easy": { status: "tooEasy" },
    },
    userState: state({
      due_item: {
        itemID: "due_item",
        kind: "phrase",
        strength: 0.2,
        difficulty: 0.5,
        repetitions: 1,
        lapses: 0,
        nextReviewAt: "2026-04-19T07:00:00.000Z",
      },
    }),
    recentEvents: [],
    now,
    limit: 3,
  });

  assert.deepEqual(selected.map((item) => item.id), ["due", "fresh"]);
});

test("prefers variety by not repeating the last lesson type when scores are close", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const selected = selectFeedCards({
    cards: [
      card("translate-next", "translate", ["item_a"]),
      card("choice-next", "multipleChoice", ["item_b"]),
    ],
    cardStates: {},
    userState: state({}),
    recentEvents: [{ name: "card_answered", parameters: { lesson_type: "translate" } }],
    now,
    limit: 2,
  });

  assert.equal(selected[0]?.id, "choice-next");
});

test("can return deferred cards later without treating them as blocked", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const selected = selectFeedCards({
    cards: [card("deferred", "chat", ["item_a"])],
    cardStates: { deferred: { status: "deferred" } },
    userState: state({}),
    recentEvents: [],
    now,
    limit: 1,
  });

  assert.deepEqual(selected.map((item) => item.id), ["deferred"]);
});

test("prioritizes cards that train weak skill tags", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const selected = selectFeedCards({
    cards: [
      { ...card("grammar-card", "translate", ["item_a"]), skillTags: ["grammar"] },
      { ...card("coffee-card", "translate", ["item_b"]), skillTags: ["coffee"] },
    ],
    cardStates: {},
    userState: {
      ...state({}),
      skillStates: {
        grammar: { skillTag: "grammar", weakness: 0.9, attempts: 5, correct: 1 },
        coffee: { skillTag: "coffee", weakness: 0.1, attempts: 5, correct: 5 },
      },
    },
    recentEvents: [],
    now,
    limit: 2,
  });

  assert.equal(selected[0]?.id, "grammar-card");
});

test("boosts cards for items that were recently answered wrong", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const selected = selectFeedCards({
    cards: [
      card("fresh-new-card", "translate", ["new_item"]),
      card("recent-miss-card", "translate", ["missed_item"]),
    ],
    cardStates: {},
    userState: state({
      missed_item: {
        itemID: "missed_item",
        kind: "phrase",
        strength: 0.95,
        difficulty: 0.5,
        repetitions: 2,
        lapses: 0,
        nextReviewAt: "2026-04-20T08:00:00.000Z",
      },
    }),
    recentEvents: [
      {
        name: "card_answered",
        parameters: {
          card_id: "previous-miss",
          is_correct: false,
          target_item_ids: ["missed_item"],
          lesson_type: "fillGap",
        },
      },
    ],
    now,
    limit: 2,
  });

  assert.equal(selected[0]?.id, "recent-miss-card");
});

test("suppresses recently too easy targets below comparable new cards", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const selected = selectFeedCards({
    cards: [
      card("aaa-too-easy-target", "translate", ["easy_item"]),
      card("zzz-new-target", "translate", ["new_item"]),
    ],
    cardStates: {},
    userState: state({}),
    recentEvents: [
      {
        name: "card_too_easy",
        parameters: {
          card_id: "easy-card",
          target_item_ids: ["easy_item"],
          lesson_type: "translate",
        },
      },
    ],
    now,
    limit: 2,
  });

  assert.equal(selected[0]?.id, "zzz-new-target");
});

test("prioritizes selected goal cards but keeps exploration cards eligible", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const selected = selectFeedCards({
    cards: [
      { ...card("dating-card", "translate", ["item_a"]), missionID: "dating" },
      { ...card("travel-card", "translate", ["item_b"]), missionID: "travel" },
      { ...card("work-card", "translate", ["item_c"]), missionID: "work" },
    ],
    cardStates: {},
    userState: state({}, { goals: ["work", "study"] }),
    recentEvents: [],
    now,
    limit: 3,
  });

  assert.equal(selected[0]?.id, "work-card");
  assert.deepEqual(selected.map((item) => item.id).sort(), ["dating-card", "travel-card", "work-card"]);
});

test("does not let unrelated starter cards outrank selected goals on a fresh feed", () => {
  const now = new Date("2026-04-19T08:00:00.000Z");
  const selected = selectFeedCards({
    cards: [
      { ...card("coffee-card", "translate", ["coffee_item"]), missionID: "travel", skillTags: ["coffee"] },
      { ...card("dating-card", "multipleChoice", ["dating_item"]), missionID: "dating", skillTags: ["dating"] },
      { ...card("work-card", "translate", ["work_item"]), missionID: "work", skillTags: ["work"] },
    ],
    cardStates: {},
    userState: state({}, { goals: ["work", "dating"], goal: "work" }),
    recentEvents: [],
    now,
    limit: 2,
  });

  assert.deepEqual(selected.map((item) => item.id), ["dating-card", "work-card"]);
});

function card(id: string, type: GeneratedCard["type"], targetItemIDs: string[]): GeneratedCard {
  return {
    id,
    type,
    context: "A1 / test",
    situation: "Testing.",
    prompt: "Prompt",
    options: type === "multipleChoice" ? ["Answer", "Other"] : [],
    correctAnswer: "Answer",
    explanation: "Explanation.",
    chatMessages: [],
    targetItemIDs,
    skillTags: ["test"],
    difficulty: 1,
    missionID: "test",
  };
}

function state(
  itemStates: UserLearningState["itemStates"],
  preferenceOverrides: Partial<UserLearningState["preferences"]> = {},
): UserLearningState {
  return {
    preferences: {
      targetLanguageCode: "es",
      nativeLanguageCode: "en",
      level: "A1",
      goal: "travel",
      goals: ["travel"],
      interests: [],
      dailyMinutes: 5,
      ...preferenceOverrides,
    },
    itemStates,
    recentEvents: [],
  };
}

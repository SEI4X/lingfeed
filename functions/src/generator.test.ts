import assert from "node:assert/strict";
import test from "node:test";
import { generateExerciseCards } from "./generator.js";
import { validateCardQuality } from "./cardQuality.js";

test("generates unseen exercises from weakest learning items", () => {
  const cards = generateExerciseCards({
    languageCode: "es",
    existingCardIDs: new Set(["gen-es-phrase-translate-1"]),
    items: [
      {
        id: "phrase",
        kind: "phrase",
        languageCode: "es",
        value: "para llevar",
        translation: "to go",
        explanation: "Use para llevar for takeaway orders.",
        tags: ["coffee"],
        level: "A1",
      },
      {
        id: "thanks",
        kind: "lexeme",
        languageCode: "es",
        value: "gracias",
        translation: "thank you",
        tags: ["small_talk"],
        level: "A1",
      },
    ],
    userState: {
      preferences: {
        targetLanguageCode: "es",
        nativeLanguageCode: "en",
        level: "A1",
        goal: "travel",
        interests: ["coffee"],
        dailyMinutes: 5,
      },
      itemStates: {
        phrase: {
          itemID: "phrase",
          kind: "phrase",
          strength: 0.1,
          difficulty: 0.6,
          repetitions: 1,
          lapses: 0,
          nextReviewAt: new Date(Date.now() - 60_000).toISOString(),
        },
      },
    },
    limit: 2,
    now: new Date("2026-04-19T00:00:00.000Z"),
  });

  assert.equal(cards.length, 2);
  assert.deepEqual(cards[0]?.targetItemIDs, ["phrase"]);
  assert.equal(cards[0]?.id, "gen-es-phrase-choice-1");
  assert.equal(cards[1]?.id, "gen-es-phrase-fill-1");
});

test("does not generate cards for another language", () => {
  const cards = generateExerciseCards({
    languageCode: "fr",
    existingCardIDs: new Set(),
    items: [
      {
        id: "phrase",
        kind: "phrase",
        languageCode: "es",
        value: "para llevar",
        tags: ["coffee"],
        level: "A1",
      },
    ],
    userState: {
      preferences: {
        targetLanguageCode: "fr",
        nativeLanguageCode: "en",
        level: "A1",
        goal: "travel",
        interests: ["coffee"],
        dailyMinutes: 5,
      },
      itemStates: {},
    },
    limit: 3,
    now: new Date("2026-04-19T00:00:00.000Z"),
  });

  assert.deepEqual(cards, []);
});

test("prioritizes items from recent wrong answers", () => {
  const cards = generateExerciseCards({
    languageCode: "es",
    existingCardIDs: new Set(),
    items: [
      {
        id: "known",
        kind: "phrase",
        languageCode: "es",
        value: "gracias",
        translation: "thank you",
        tags: ["chat"],
        level: "A1",
      },
      {
        id: "mistake",
        kind: "phrase",
        languageCode: "es",
        value: "para llevar",
        translation: "to go",
        tags: ["coffee"],
        level: "A1",
      },
    ],
    userState: {
      preferences: {
        targetLanguageCode: "es",
        nativeLanguageCode: "en",
        level: "A1",
        goal: "travel",
        interests: [],
        dailyMinutes: 5,
      },
      itemStates: {
        known: {
          itemID: "known",
          kind: "phrase",
          strength: 0.2,
          difficulty: 0.5,
          repetitions: 2,
          lapses: 0,
          nextReviewAt: new Date("2026-04-20T00:00:00.000Z").toISOString(),
        },
        mistake: {
          itemID: "mistake",
          kind: "phrase",
          strength: 0.7,
          difficulty: 0.5,
          repetitions: 2,
          lapses: 0,
          nextReviewAt: new Date("2026-04-20T00:00:00.000Z").toISOString(),
        },
      },
      recentEvents: [
        {
          name: "card_answered",
          parameters: {
            is_correct: false,
            target_item_ids: ["mistake"],
          },
        },
      ],
    },
    limit: 1,
    now: new Date("2026-04-19T00:00:00.000Z"),
  });

  assert.deepEqual(cards[0]?.targetItemIDs, ["mistake"]);
});

test("does not keep generating cards for recent too easy items", () => {
  const cards = generateExerciseCards({
    languageCode: "es",
    existingCardIDs: new Set(),
    items: [
      {
        id: "easy",
        kind: "phrase",
        languageCode: "es",
        value: "gracias",
        translation: "thank you",
        tags: ["chat"],
        level: "A1",
      },
      {
        id: "fresh",
        kind: "phrase",
        languageCode: "es",
        value: "para llevar",
        translation: "to go",
        tags: ["coffee"],
        level: "A1",
      },
    ],
    userState: {
      preferences: {
        targetLanguageCode: "es",
        nativeLanguageCode: "en",
        level: "A1",
        goal: "travel",
        interests: [],
        dailyMinutes: 5,
      },
      itemStates: {
        easy: {
          itemID: "easy",
          kind: "phrase",
          strength: 0.05,
          difficulty: 0.5,
          repetitions: 0,
          lapses: 0,
          nextReviewAt: new Date("2026-04-18T00:00:00.000Z").toISOString(),
        },
      },
      recentEvents: [
        {
          name: "card_too_easy",
          parameters: {
            target_item_ids: ["easy"],
          },
        },
      ],
    },
    limit: 1,
    now: new Date("2026-04-19T00:00:00.000Z"),
  });

  assert.deepEqual(cards[0]?.targetItemIDs, ["fresh"]);
});

test("rule based generator can produce every supported card type", () => {
  const cards = generateExerciseCards({
    languageCode: "es",
    existingCardIDs: new Set(),
    items: [
      {
        id: "identity",
        kind: "grammarPattern",
        languageCode: "es",
        value: "Yo soy estudiante",
        translation: "I am a student",
        explanation: "Use soy with yo for identity.",
        tags: ["introductions"],
        level: "A1",
      },
      {
        id: "thanks",
        kind: "phrase",
        languageCode: "es",
        value: "gracias",
        translation: "thank you",
        tags: ["chat"],
        level: "A1",
      },
      {
        id: "coffee",
        kind: "lexeme",
        languageCode: "es",
        value: "cafe",
        translation: "coffee",
        tags: ["coffee"],
        level: "A1",
      },
    ],
    userState: {
      preferences: {
        targetLanguageCode: "es",
        nativeLanguageCode: "en",
        level: "A1",
        goal: "travel",
        interests: ["introductions"],
        dailyMinutes: 5,
      },
      itemStates: {},
    },
    limit: 12,
    now: new Date("2026-04-19T00:00:00.000Z"),
  });

  assert.deepEqual(new Set(cards.map((card) => card.type)), new Set([
    "translate",
    "multipleChoice",
    "fillGap",
    "reorder",
    "fixMistake",
    "chat",
  ]));
  assert.ok(cards.find((card) => card.type === "multipleChoice")?.options.includes("Yo soy estudiante"));
  assert.ok(cards.find((card) => card.type === "reorder")?.options.length);
  assert.match(cards.find((card) => card.type === "fixMistake")?.prompt ?? "", /Yo es estudiante/);
});

test("rule based fill gap cards include options and pass quality validation", () => {
  const items = [
    {
      id: "coffee",
      kind: "phrase",
      languageCode: "en",
      value: "I want coffee",
      translation: "Я хочу кофе",
      tags: ["coffee"],
      level: "A1",
    },
    {
      id: "tea",
      kind: "phrase",
      languageCode: "en",
      value: "I want tea",
      translation: "Я хочу чай",
      tags: ["coffee"],
      level: "A1",
    },
  ];
  const cards = generateExerciseCards({
    languageCode: "en",
    existingCardIDs: new Set([
      "gen-en-coffee-translate-1",
      "gen-en-coffee-choice-1",
      "gen-en-coffee-chat-1",
    ]),
    items,
    userState: userState("en", "ru"),
    limit: 1,
    now: new Date("2026-04-19T00:00:00.000Z"),
  });
  const card = cards[0];

  assert.equal(card?.type, "fillGap");
  assert.ok(card.options.includes("coffee"));
  assert.ok(card.options.length >= 2);
  assert.deepEqual(validateCardQuality({ card, itemsByID: new Map(items.map((item) => [item.id, item])) }), { valid: true, reasons: [] });
});

test("rule based generator occasionally creates exploration cards outside selected goals", () => {
  const state = userState("es", "en");
  state.preferences.goal = "work";
  state.preferences.goals = ["work"];
  const items = [
    {
      id: "es_phrase_long",
      kind: "phrase",
      languageCode: "es",
      value: "quiero cafe ahora",
      translation: "I want coffee now",
      tags: ["coffee"],
      level: "A1",
    },
  ];

  const cards = generateExerciseCards({
    languageCode: "es",
    existingCardIDs: new Set(),
    items,
    userState: state,
    limit: 6,
    now: new Date("2026-04-19T00:00:00.000Z"),
  });

  assert.ok(cards.some((card) => card.missionID === "work"));
  assert.ok(cards.some((card) => card.missionID !== "work"));
});

test("quality validation rejects unclear fill gap and unfocused fix mistake cards", () => {
  const items = [
    {
      id: "coffee",
      kind: "phrase",
      languageCode: "en",
      value: "I want coffee",
      translation: "Я хочу кофе",
      tags: ["coffee"],
      level: "A1",
    },
    {
      id: "student",
      kind: "grammarPattern",
      languageCode: "en",
      value: "I am a student",
      translation: "Я студент",
      tags: ["introductions"],
      level: "A1",
    },
  ];
  const itemsByID = new Map(items.map((item) => [item.id, item]));

  assert.deepEqual(validateCardQuality({
    card: {
      id: "bad-gap",
      type: "fillGap",
      context: "A1 / coffee",
      situation: "At a cafe asking for a drink.",
      prompt: "I want ___.",
      options: [],
      correctAnswer: "coffee",
      explanation: "Coffee means кофе.",
      chatMessages: [],
      targetItemIDs: ["coffee"],
      skillTags: ["coffee"],
      difficulty: 1,
      missionID: "travel",
    },
    itemsByID,
  }), { valid: false, reasons: ["missing_fill_gap_options"] });

  assert.deepEqual(validateCardQuality({
    card: {
      id: "bad-fix",
      type: "fixMistake",
      context: "A1 / introductions",
      situation: "Introduce yourself.",
      prompt: "Fix the sentence: I is student.",
      options: [],
      correctAnswer: "I am a student",
      explanation: "Use am with I.",
      chatMessages: [],
      targetItemIDs: ["student"],
      skillTags: ["introductions"],
      difficulty: 1,
      missionID: "travel",
    },
    itemsByID,
  }), { valid: false, reasons: ["unfocused_fix_mistake"] });
});

test("quality validation rejects ambiguous chat cards and lexical chat answers", () => {
  const itemsByID = new Map([
    ["coffee", {
      id: "coffee",
      kind: "lexeme",
      languageCode: "en",
      value: "coffee",
      translation: "кофе",
      tags: ["coffee"],
      level: "A1",
    }],
    ["thanks", {
      id: "thanks",
      kind: "phrase",
      languageCode: "en",
      value: "Thank you",
      translation: "спасибо",
      tags: ["chat"],
      level: "A1",
    }],
  ]);

  assert.deepEqual(validateCardQuality({
    card: {
      id: "bad-chat",
      type: "chat",
      context: "A1 / coffee",
      situation: "You are at a cafe.",
      prompt: "Reply naturally.",
      options: [],
      correctAnswer: "coffee",
      explanation: "coffee means кофе.",
      chatMessages: [],
      targetItemIDs: ["coffee"],
      skillTags: ["coffee"],
      difficulty: 1,
      missionID: "travel",
    },
    itemsByID,
  }), { valid: false, reasons: ["ambiguous_chat_prompt", "missing_chat_options", "missing_chat_message", "lexical_chat_answer"] });

  assert.deepEqual(validateCardQuality({
    card: {
      id: "good-chat",
      type: "chat",
      context: "A1 / dating",
      situation: "Someone greets you.",
      prompt: "Choose the natural reply.",
      options: ["Thank you", "Blue", "Yesterday"],
      correctAnswer: "Thank you",
      explanation: "Thank you is a clear reply.",
      chatMessages: [{ id: "m1", text: "Nice to meet you.", isUser: false }],
      targetItemIDs: ["thanks"],
      skillTags: ["chat"],
      difficulty: 1,
      missionID: "dating",
    },
    itemsByID,
  }), { valid: true, reasons: [] });
});

function userState(targetLanguageCode: string, nativeLanguageCode: string) {
  return {
    preferences: {
      targetLanguageCode,
      nativeLanguageCode,
      level: "A1",
      goal: "travel",
      goals: ["travel"],
      interests: ["coffee"],
      dailyMinutes: 5,
    },
    itemStates: {},
  };
}

import assert from "node:assert/strict";
import test from "node:test";
import { buildGenerationContext } from "./personalizationContext.js";
import type { GenerateExerciseInput } from "./generator.js";

test("builds compact generation context from weak items and recent behavior", () => {
  const context = buildGenerationContext(input());

  assert.equal(context.level, "A1");
  assert.equal(context.nativeLanguageCode, "en");
  assert.equal(context.targetLanguageCode, "es");
  assert.deepEqual(context.weakItemIDs, ["es_phrase_para_llevar", "es_grammar_yo_soy"]);
  assert.deepEqual(context.recentlyFailedPhrases, ["para llevar"]);
  assert.deepEqual(context.recentlySeenCardIDs, ["card-answered", "card-viewed"]);
  assert.deepEqual(context.bannedRepeats, ["card-existing", "card-answered", "card-viewed"]);
  assert.deepEqual(context.lessonTypeBalance, { translate: 1, fillGap: 1 });
  assert.deepEqual(context.weakSkillTags, ["grammar"]);
  assert.equal(context.targetScenario, "work, study / coffee");
});

function input(): GenerateExerciseInput {
  return {
    languageCode: "es",
    existingCardIDs: new Set(["card-existing"]),
    items: [
      {
        id: "es_phrase_para_llevar",
        kind: "phrase",
        languageCode: "es",
        value: "para llevar",
        translation: "to go",
        tags: ["coffee"],
        level: "A1",
      },
      {
        id: "es_grammar_yo_soy",
        kind: "grammarPattern",
        languageCode: "es",
        value: "yo soy",
        translation: "I am",
        tags: ["introductions"],
        level: "A1",
      },
    ],
    userState: {
      preferences: {
        targetLanguageCode: "es",
        nativeLanguageCode: "en",
        level: "A1",
        goal: "travel",
        goals: ["work", "study"],
        interests: ["coffee"],
        dailyMinutes: 5,
      },
      itemStates: {
        es_phrase_para_llevar: {
          itemID: "es_phrase_para_llevar",
          kind: "phrase",
          strength: 0.2,
          difficulty: 0.7,
          repetitions: 2,
          lapses: 1,
          nextReviewAt: "2026-04-18T00:00:00.000Z",
        },
        es_grammar_yo_soy: {
          itemID: "es_grammar_yo_soy",
          kind: "grammarPattern",
          strength: 0.3,
          difficulty: 0.8,
          repetitions: 0,
          lapses: 0,
          nextReviewAt: "2026-04-21T00:00:00.000Z",
        },
      },
      skillStates: {
        grammar: {
          skillTag: "grammar",
          weakness: 0.82,
          attempts: 5,
          correct: 2,
        },
        coffee: {
          skillTag: "coffee",
          weakness: 0.2,
          attempts: 5,
          correct: 5,
        },
      },
      recentEvents: [
        {
          name: "card_answered",
          createdAt: "2026-04-19T08:00:00.000Z",
          parameters: {
            card_id: "card-answered",
            is_correct: false,
            target_item_ids: ["es_phrase_para_llevar"],
            lesson_type: "translate",
          },
        },
        {
          name: "card_viewed",
          createdAt: "2026-04-19T08:01:00.000Z",
          parameters: {
            card_id: "card-viewed",
            target_item_ids: ["es_grammar_yo_soy"],
            lesson_type: "fillGap",
          },
        },
      ],
    },
    limit: 4,
    now: new Date("2026-04-19T09:00:00.000Z"),
  };
}

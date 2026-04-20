import assert from "node:assert/strict";
import test from "node:test";
import { generatePersonalizedExerciseCards, generatePersonalizedExerciseCardsWithMetadata } from "./generationPipeline.js";
import type { GenerateExerciseInput } from "./generator.js";

test("uses validated LLM cards before rule based fallback", async () => {
  const cards = await generatePersonalizedExerciseCards(baseInput(), {
    llmClient: {
      createResponse: async () => ({
        output_text: JSON.stringify({
          cards: [
            {
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
              difficulty: 2,
              missionID: "travel",
            },
          ],
        }),
      }),
    },
  });

  assert.equal(cards[0]?.id, "llm-es-es_phrase_para_llevar-translate-1");
});

test("falls back to rule based cards when LLM returns nothing", async () => {
  const cards = await generatePersonalizedExerciseCards(baseInput(), {
    llmClient: {
      createResponse: async () => ({ output_text: JSON.stringify({ cards: [] }) }),
    },
  });

  assert.equal(cards[0]?.id, "gen-es-es_phrase_para_llevar-translate-1");
});

test("returns generation metadata for provider success", async () => {
  const result = await generatePersonalizedExerciseCardsWithMetadata(baseInput(), {
    llmClient: {
      providerName: "gemini",
      createResponse: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    cards: [
                      {
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
                        difficulty: 2,
                        missionID: "travel",
                      },
                    ],
                  }),
                },
              ],
            },
          },
        ],
      }),
    },
  });

  assert.equal(result.provider, "gemini");
  assert.equal(result.fallbackUsed, false);
  assert.equal(result.cards[0]?.id, "gemini-es-es_phrase_para_llevar-translate-1");
});

test("returns fallback metadata when provider returns no valid cards", async () => {
  const result = await generatePersonalizedExerciseCardsWithMetadata(baseInput(), {
    llmClient: {
      providerName: "gemini",
      createResponse: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify({ cards: [{ type: "translate" }] }) }] } }] }),
    },
  });

  assert.equal(result.provider, "rules");
  assert.equal(result.requestedProvider, "gemini");
  assert.equal(result.fallbackUsed, true);
  assert.equal(result.fallbackReason, "no_valid_llm_cards");
  assert.equal(result.diagnostics.acceptedCardCount, 0);
  assert.equal(result.diagnostics.rejectedCardCount, 1);
  assert.deepEqual(result.diagnostics.rejectReasons, { missing_required_fields: 1 });
  assert.equal(result.cards[0]?.id, "gen-es-es_phrase_para_llevar-translate-1");
});

test("reports generation lesson type distribution for accepted cards", async () => {
  const result = await generatePersonalizedExerciseCardsWithMetadata(baseInput(), {
    llmClient: {
      providerName: "gemini",
      createResponse: async () => ({ output_text: JSON.stringify({ cards: [validTranslateCard()] }) }),
    },
  });

  assert.deepEqual(result.diagnostics.lessonTypeDistribution, { translate: 1 });
  assert.equal(result.diagnostics.acceptedCardCount, 1);
});

function baseInput(): GenerateExerciseInput {
  return {
    languageCode: "es",
    existingCardIDs: new Set(),
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
      itemStates: {},
    },
    limit: 2,
    now: new Date("2026-04-19T00:00:00.000Z"),
  };
}

function validTranslateCard() {
  return {
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
    difficulty: 2,
    missionID: "travel",
  };
}

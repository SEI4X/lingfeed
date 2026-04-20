import assert from "node:assert/strict";
import test from "node:test";
import { VertexAIGeminiClient, generateLLMExerciseCards } from "./llmGenerator.js";
import type { GenerateExerciseInput } from "./generator.js";

test("generates validated cards from a structured LLM response", async () => {
  const input = baseInput();
  const cards = await generateLLMExerciseCards(input, {
    createResponse: async () => ({
      output_text: JSON.stringify({
        cards: [
          {
            type: "fillGap",
            context: "A1 / coffee",
            situation: "You are ordering coffee.",
            prompt: "Quiero cafe ___.",
            options: ["para llevar", "ayer", "azul"],
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
  });

  assert.equal(cards.length, 1);
  assert.equal(cards[0]?.id, "llm-es-es_phrase_para_llevar-fillGap-1");
  assert.equal(cards[0]?.type, "fillGap");
  assert.deepEqual(cards[0]?.targetItemIDs, ["es_phrase_para_llevar"]);
});

test("filters invalid LLM cards before returning them", async () => {
  const input = baseInput();
  const cards = await generateLLMExerciseCards(input, {
    createResponse: async () => ({
      output_text: JSON.stringify({
        cards: [
          {
            type: "translate",
            context: "A1 / coffee",
            prompt: "Say: to go",
            correctAnswer: "para llevar",
            explanation: "Use para llevar for takeaway orders.",
            targetItemIDs: ["unknown_item"],
            skillTags: ["coffee"],
            difficulty: 2,
          },
          {
            type: "fillGap",
            context: "A1 / coffee",
            prompt: "Quiero cafe ___.",
            correctAnswer: "para llevar",
            explanation: "Use para llevar for takeaway orders.",
            targetItemIDs: ["es_phrase_para_llevar"],
            skillTags: ["coffee"],
            difficulty: 9,
          },
        ],
      }),
    }),
  });

  assert.deepEqual(cards, []);
});

test("rejects unsupported speaking cards", async () => {
  const cards = await generateLLMExerciseCards(baseInput(), {
    createResponse: async () => ({
      output_text: JSON.stringify({
        cards: [
          {
            type: "translate",
            context: "A1 / coffee",
            prompt: "Say: to go",
            correctAnswer: "para llevar",
            explanation: "Say the phrase naturally.",
            targetItemIDs: ["es_phrase_para_llevar"],
            skillTags: ["coffee"],
            difficulty: 2,
          },
          {
            type: "translate",
            context: "A1 / coffee",
            prompt: "Pronounce this word.",
            correctAnswer: "para llevar",
            explanation: "Practice pronunciation.",
            targetItemIDs: ["es_phrase_para_llevar"],
            skillTags: ["coffee"],
            difficulty: 2,
          },
        ],
      }),
    }),
  });

  assert.deepEqual(cards, []);
});

test("rejects fill gap cards with multiple blanks or composite answers", async () => {
  const cards = await generateLLMExerciseCards(introductionInput(), {
    createResponse: async () => ({
      output_text: JSON.stringify({
        cards: [
          {
            type: "fillGap",
            context: "A1 / introductions",
            prompt: "Yo ___ ___. ____",
            correctAnswer: "soy, Gracias",
            explanation: "Soy means I am and gracias means thank you.",
            targetItemIDs: ["es_grammar_yo_soy", "es_phrase_gracias"],
            skillTags: ["introductions"],
            difficulty: 1,
          },
          {
            type: "fillGap",
            context: "A1 / introductions",
            prompt: "Yo ___ estudiante.",
            correctAnswer: "soy, gracias",
            explanation: "Use soy with yo.",
            targetItemIDs: ["es_grammar_yo_soy"],
            skillTags: ["introductions"],
            difficulty: 1,
          },
        ],
      }),
    }),
  });

  assert.deepEqual(cards, []);
});

test("returns no LLM cards when the provider fails", async () => {
  const cards = await generateLLMExerciseCards(baseInput(), {
    createResponse: async () => {
      throw new Error("provider unavailable");
    },
  });

  assert.deepEqual(cards, []);
});

test("uses the provider name when assigning generated card ids", async () => {
  const cards = await generateLLMExerciseCards(baseInput(), {
    providerName: "gemini",
    createResponse: async () => ({
      output_text: JSON.stringify({
        cards: [validCard()],
      }),
    }),
  });

  assert.equal(cards[0]?.id, "gemini-es-es_phrase_para_llevar-fillGap-1");
});

test("sends compact personalization context to the LLM provider", async () => {
  let capturedRequest: Record<string, unknown> = {};
  await generateLLMExerciseCards(baseInput(), {
    providerName: "gemini",
    createResponse: async (request) => {
      capturedRequest = request;
      return { output_text: JSON.stringify({ cards: [validCard()] }) };
    },
  });

  const inputPayload = JSON.parse(String(capturedRequest.input));
  assert.deepEqual(inputPayload.generationContext.weakItemIDs, ["es_phrase_para_llevar"]);
  assert.deepEqual(inputPayload.generationContext.recentlyFailedPhrases, ["para llevar"]);
  assert.deepEqual(inputPayload.generationContext.lessonTypeBalance, {});
  assert.match(capturedRequest.instructions as string, /Use generationContext/);
});

test("parses Gemini candidate text responses", async () => {
  const cards = await generateLLMExerciseCards(baseInput(), {
    providerName: "gemini",
    createResponse: async () => ({
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({ cards: [validCard()] }),
              },
            ],
          },
        },
      ],
    }),
  });

  assert.equal(cards[0]?.id, "gemini-es-es_phrase_para_llevar-fillGap-1");
});

test("builds a Vertex AI Gemini generateContent request", async () => {
  let capturedURL = "";
  let capturedBody: any;
  const client = new VertexAIGeminiClient({
    projectID: "ling-feed",
    location: "us-central1",
    model: "gemini-2.5-flash",
    accessTokenProvider: async () => "token",
    fetchFn: async (url: Parameters<typeof fetch>[0], init: Parameters<typeof fetch>[1]) => {
      capturedURL = String(url);
      capturedBody = JSON.parse(String(init?.body));
      return {
        ok: true,
        status: 200,
        json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify({ cards: [validCard()] }) }] } }] }),
      } as Response;
    },
  });

  const cards = await generateLLMExerciseCards(baseInput(), client);

  assert.equal(capturedURL, "https://us-central1-aiplatform.googleapis.com/v1/projects/ling-feed/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent");
  assert.equal(capturedBody.generationConfig.responseMimeType, "application/json");
  assert.equal(capturedBody.generationConfig.responseSchema.type, "object");
  assert.match(capturedBody.contents[0].parts[0].text, /languageCode/);
  assert.match(capturedBody.contents[0].parts[0].text, /preferences\.nativeLanguageCode/);
  assert.match(capturedBody.contents[0].parts[0].text, /Fill-gap cards must.*include 3-4 answer options/);
  assert.match(capturedBody.contents[0].parts[0].text, /Fix-mistake cards must require exactly one local correction/);
  assert.equal(cards[0]?.id, "gemini-es-es_phrase_para_llevar-fillGap-1");
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
        explanation: "Use para llevar for takeaway orders.",
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
      itemStates: {
        es_phrase_para_llevar: {
          itemID: "es_phrase_para_llevar",
          kind: "phrase",
          strength: 0.2,
          difficulty: 0.5,
          repetitions: 1,
          lapses: 1,
          nextReviewAt: new Date("2026-04-18T00:00:00.000Z").toISOString(),
        },
      },
      recentEvents: [
        {
          name: "card_answered",
          parameters: {
            is_correct: false,
            target_item_ids: ["es_phrase_para_llevar"],
          },
        },
      ],
    },
    limit: 3,
    now: new Date("2026-04-19T00:00:00.000Z"),
  };
}

function introductionInput(): GenerateExerciseInput {
  const input = baseInput();
  return {
    ...input,
    items: [
      ...input.items,
      {
        id: "es_grammar_yo_soy",
        kind: "grammarPattern",
        languageCode: "es",
        value: "yo + soy",
        translation: "I am",
        tags: ["introductions"],
        level: "A1",
      },
      {
        id: "es_phrase_gracias",
        kind: "phrase",
        languageCode: "es",
        value: "gracias",
        translation: "thank you",
        tags: ["introductions"],
        level: "A1",
      },
    ],
  };
}

function validCard() {
  return {
    type: "fillGap",
    context: "A1 / coffee",
    situation: "You are ordering coffee.",
    prompt: "Quiero cafe ___.",
    options: ["para llevar", "ayer", "azul"],
    correctAnswer: "para llevar",
    explanation: "Use para llevar for takeaway orders.",
    chatMessages: [],
    targetItemIDs: ["es_phrase_para_llevar"],
    skillTags: ["coffee"],
    difficulty: 2,
    missionID: "travel",
  };
}

import assert from "node:assert/strict";
import test from "node:test";
import { evaluateCardsForCleanup } from "./cleanupBadCards.js";
import type { GeneratedCard, LearningItem } from "./generator.js";

test("marks broken active cards for archival with reject reasons", () => {
  const result = evaluateCardsForCleanup({
    cards: [
      { ...card("good", "fillGap", "Quiero cafe ___.", "para llevar", ["es_phrase_para_llevar"]), options: ["para llevar", "ayer"] },
      card("broken", "fillGap", "Yo ___ ___. ____", "soy, gracias", ["es_phrase_para_llevar"]),
    ],
    items: [item()],
  });

  assert.deepEqual(result.archive.map((entry) => entry.cardID), ["broken"]);
  assert.deepEqual(result.archive[0]?.rejectReasons, ["invalid_fill_gap_blank_count", "missing_fill_gap_options", "composite_fill_gap_answer", "answer_not_in_targets"]);
  assert.equal(result.keepCount, 1);
});

test("marks Spanish seed cards stored under English for archival", () => {
  const result = evaluateCardsForCleanup({
    cards: [
      {
        ...card("en_spanish_seed", "chat", "Reply naturally.", "Gracias", ["en_phrase_gracias"]),
        chatMessages: [{ id: "prompt", text: "Aqui tienes tu cafe.", isUser: false }],
        options: ["Gracias", "Buenas noches", "Tengo dos", "Hasta ayer"],
        languageCode: "en",
      },
    ],
    items: [
      {
        id: "en_phrase_gracias",
        kind: "phrase",
        languageCode: "en",
        value: "gracias",
        translation: "thank you",
        tags: ["chat"],
        level: "A1",
      },
    ],
  });

  assert.deepEqual(result.archive.map((entry) => entry.cardID), ["en_spanish_seed"]);
  assert.deepEqual(result.archive[0]?.rejectReasons, ["target_language_content_mismatch"]);
  assert.equal(result.keepCount, 0);
});

function item(): LearningItem {
  return {
    id: "es_phrase_para_llevar",
    kind: "phrase",
    languageCode: "es",
    value: "para llevar",
    translation: "to go",
    tags: ["coffee"],
    level: "A1",
  };
}

function card(
  id: string,
  type: GeneratedCard["type"],
  prompt: string,
  correctAnswer: string,
  targetItemIDs: string[],
): GeneratedCard & { languageCode: string; status: string } {
  return {
    id,
    type,
    context: "A1 / coffee",
    situation: "Ordering coffee.",
    prompt,
    options: [],
    correctAnswer,
    explanation: "Test.",
    chatMessages: [],
    targetItemIDs,
    skillTags: ["coffee"],
    difficulty: 1,
    missionID: "travel",
    languageCode: "es",
    status: "active",
  };
}

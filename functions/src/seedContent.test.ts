import assert from "node:assert/strict";
import test from "node:test";
import { validateCardQuality } from "./cardQuality.js";
import { seedLearningContent } from "./seedContent.js";

const supportedLanguageCodes = ["es", "fr", "de", "it", "pt", "ja", "ko", "zh-Hans", "ru", "en"];
const spanishSeedPattern = /quiero|gracias|para llevar|buenas noches|tengo dos|hasta ayer|aqui tienes|un cafe/i;

test("seedLearningContent creates stable cards and learning items for a language", () => {
  const seed = seedLearningContent("es");

  assert.ok(seed.items.length >= 11);
  assert.ok(seed.cards.length >= 22);
  assert.equal(seed.items[0]?.id, "es_lexeme_quiero");
  assert.ok(seed.cards.some((card) => card.id === "es_coffee_translate_quiero_cafe"));
  assert.deepEqual(seed.cards.find((card) => card.id === "es_coffee_translate_quiero_cafe")?.targetItemIDs, ["es_lexeme_quiero", "es_lexeme_cafe"]);
});

test("seedLearningContent keeps every card linked to existing learning items", () => {
  const seed = seedLearningContent("es");
  const itemIDs = new Set(seed.items.map((item) => item.id));

  for (const card of seed.cards) {
    assert.ok(card.targetItemIDs.length > 0);
    assert.ok(card.targetItemIDs.every((itemID) => itemIDs.has(itemID)));
  }
});

test("seedLearningContent creates Russian starter content for ru", () => {
  const seed = seedLearningContent("ru");

  assert.equal(seed.items[0]?.id, "ru_lexeme_ya");
  assert.equal(seed.items[0]?.value, "я");
  assert.equal(seed.items[2]?.value, "кофе");
  const coffeeCard = seed.cards.find((card) => card.id === "ru_coffee_translate_ya_hochu_kofe");
  assert.equal(coffeeCard?.correctAnswer, "Я хочу кофе");
  assert.deepEqual(coffeeCard?.targetItemIDs, ["ru_lexeme_ya", "ru_lexeme_hochu", "ru_lexeme_kofe"]);
});

test("seedLearningContent creates English starter content for en instead of Spanish content", () => {
  const seed = seedLearningContent("en");
  const allText = JSON.stringify(seed);

  assert.equal(seed.items[0]?.id, "en_lexeme_i");
  assert.equal(seed.items[0]?.value, "I");
  assert.equal(seed.cards.find((card) => card.id === "en_coffee_translate_i_want_coffee")?.correctAnswer, "I want coffee");
  assert.doesNotMatch(allText, /quiero|gracias|para llevar|Aqui tienes/i);
});

test("Russian starter cards pass quality validation", () => {
  const seed = seedLearningContent("ru");
  const itemsByID = new Map(seed.items.map((item) => [item.id, item]));

  for (const card of seed.cards) {
    assert.deepEqual(validateCardQuality({ card, itemsByID }), { valid: true, reasons: [] });
  }
});

test("English starter cards pass quality validation", () => {
  const seed = seedLearningContent("en");
  const itemsByID = new Map(seed.items.map((item) => [item.id, item]));

  for (const card of seed.cards) {
    assert.deepEqual(validateCardQuality({ card, itemsByID }), { valid: true, reasons: [] });
  }
});

test("every supported target language has language-specific valid starter cards", () => {
  for (const languageCode of supportedLanguageCodes) {
    const seed = seedLearningContent(languageCode);
    const itemsByID = new Map(seed.items.map((item) => [item.id, item]));

    assert.ok(seed.items.length > 0, `${languageCode} has no seed items`);
    assert.ok(seed.cards.length > 0, `${languageCode} has no seed cards`);
    assert.ok(seed.items.every((item) => item.languageCode === languageCode), `${languageCode} has item language mismatch`);
    for (const card of seed.cards) {
      assert.deepEqual(validateCardQuality({ card, itemsByID }), { valid: true, reasons: [] }, `${languageCode} ${card.id}`);
    }

    if (languageCode !== "es") {
      assert.doesNotMatch(JSON.stringify(seed), spanishSeedPattern, `${languageCode} leaked Spanish starter content`);
    }
  }
});

test("starter content includes clear cards for every learning goal", () => {
  for (const languageCode of supportedLanguageCodes) {
    const seed = seedLearningContent(languageCode);
    const missions = new Set(seed.cards.map((card) => card.missionID));

    for (const goal of ["travel", "work", "dating", "relocation", "study", "everyday"]) {
      assert.ok(missions.has(goal), `${languageCode} missing starter cards for ${goal}`);
    }
  }
});

import type { GeneratedCard, LearningItem } from "./generator.js";

export type CardQualityInput = {
  card: Partial<GeneratedCard>;
  itemsByID: Map<string, LearningItem>;
};

export type CardQualityResult = {
  valid: boolean;
  reasons: string[];
};

const cardTypes = new Set<GeneratedCard["type"]>([
  "translate",
  "multipleChoice",
  "fillGap",
  "reorder",
  "fixMistake",
  "chat",
]);

export function validateCardQuality(input: CardQualityInput): CardQualityResult {
  const reasons: string[] = [];
  const card = input.card;
  if (!isStructurallyComplete(card)) {
    return { valid: false, reasons: ["missing_required_fields"] };
  }

  if (!cardTypes.has(card.type)) reasons.push("unsupported_card_type");
  if (card.difficulty < 1 || card.difficulty > 5) reasons.push("difficulty_out_of_range");
  if (containsUnsupportedInstruction(card)) reasons.push("unsupported_instruction");

  const targetItems = card.targetItemIDs.map((itemID) => input.itemsByID.get(itemID));
  if (targetItems.length === 0 || targetItems.some((item) => item === undefined)) {
    reasons.push("unknown_target_item");
    return { valid: false, reasons };
  }

  const items = targetItems as LearningItem[];
  switch (card.type) {
    case "translate":
      if (!answerMatchesTargets(card.correctAnswer, items)) reasons.push("answer_not_in_targets");
      break;
    case "multipleChoice":
      if (!card.options.includes(card.correctAnswer)) reasons.push("correct_answer_missing_from_options");
      if (!answerMatchesTargets(card.correctAnswer, items)) reasons.push("answer_not_in_targets");
      break;
    case "fillGap":
      if (blankMarkerCount(card.prompt) !== 1) reasons.push("invalid_fill_gap_blank_count");
      if (card.options.length === 0) reasons.push("missing_fill_gap_options");
      if (isCompositeFillAnswer(card.correctAnswer)) reasons.push("composite_fill_gap_answer");
      if (!answerAppearsInTargets(card.correctAnswer, items)) reasons.push("answer_not_in_targets");
      break;
    case "reorder":
      if (card.options.length === 0) reasons.push("missing_reorder_options");
      if (!answerMatchesTargets(card.correctAnswer, items)) reasons.push("answer_not_in_targets");
      if (!sameTokens(card.options.join(" "), card.correctAnswer)) reasons.push("reorder_tokens_mismatch");
      break;
    case "fixMistake":
      if (!isFocusedFixMistake(card.prompt, card.correctAnswer)) reasons.push("unfocused_fix_mistake");
      if (!answerAppearsInTargets(card.correctAnswer, items)) reasons.push("answer_not_in_targets");
      break;
    case "chat":
      if (isAmbiguousChatPrompt(card.prompt)) reasons.push("ambiguous_chat_prompt");
      if (card.options.length === 0 || !card.options.includes(card.correctAnswer)) reasons.push("missing_chat_options");
      if (card.chatMessages.length === 0) reasons.push("missing_chat_message");
      if (items.some((item) => item.kind === "lexeme")) reasons.push("lexical_chat_answer");
      if (!answerAppearsInTargets(card.correctAnswer, items)) reasons.push("answer_not_in_targets");
      break;
  }

  return { valid: reasons.length === 0, reasons };
}

function isAmbiguousChatPrompt(prompt: string): boolean {
  const normalizedPrompt = normalizeText(prompt);
  return normalizedPrompt === "reply naturally"
    || normalizedPrompt === "respond naturally"
    || normalizedPrompt === "answer naturally"
    || normalizedPrompt === "ответьте естественно"
    || normalizedPrompt === "ответь естественно";
}

function isStructurallyComplete(card: Partial<GeneratedCard>): card is GeneratedCard {
  return typeof card.type === "string"
    && typeof card.context === "string"
    && card.context.length > 0
    && typeof card.prompt === "string"
    && card.prompt.length > 0
    && Array.isArray(card.options)
    && typeof card.correctAnswer === "string"
    && card.correctAnswer.length > 0
    && typeof card.explanation === "string"
    && card.explanation.length > 0
    && Array.isArray(card.chatMessages)
    && Array.isArray(card.targetItemIDs)
    && card.targetItemIDs.every((item) => typeof item === "string")
    && Array.isArray(card.skillTags)
    && card.skillTags.every((item) => typeof item === "string")
    && typeof card.difficulty === "number"
    && Number.isInteger(card.difficulty)
    && typeof card.missionID === "string";
}

function containsUnsupportedInstruction(card: GeneratedCard): boolean {
  const text = normalizeText([card.context, card.situation, card.prompt, card.explanation].join(" "));
  const prompt = normalizeText(card.prompt);
  if (prompt === "say" || prompt.startsWith("say ")) return true;

  return [
    "pronounce",
    "pronunciation",
    "speak",
    "say aloud",
    "read aloud",
    "listen",
    "listening",
    "audio",
  ].some((phrase) => text.includes(phrase));
}

function answerMatchesTargets(answer: string, targetItems: LearningItem[]): boolean {
  const normalizedAnswer = normalizeText(answer);
  if (!normalizedAnswer) return false;

  const targetValues = targetItems.map((item) => normalizeText(item.value)).filter(Boolean);
  if (targetValues.includes(normalizedAnswer)) return true;
  if (normalizeText(targetValues.join(" ")) === normalizedAnswer) return true;

  const answerTokens = new Set(normalizedAnswer.split(" "));
  const targetTokens = new Set(targetValues.join(" ").split(" ").filter(Boolean));
  return [...answerTokens].every((token) => targetTokens.has(token));
}

function answerAppearsInTargets(answer: string, targetItems: LearningItem[]): boolean {
  const normalizedAnswer = normalizeText(answer);
  if (!normalizedAnswer) return false;

  const targetText = normalizeText(targetItems.map((item) => item.value).join(" "));
  return targetText.includes(normalizedAnswer) || answerMatchesTargets(answer, targetItems);
}

function blankMarkerCount(prompt: string): number {
  const matches = prompt.match(/_{2,}|\[\s*blank\s*\]|\{\s*blank\s*\}/gi);
  return matches?.length ?? 0;
}

function isCompositeFillAnswer(answer: string): boolean {
  if (/[,;/\n\r]/.test(answer)) return true;
  return normalizeText(answer).split(" ").filter(Boolean).length > 4;
}

function isFocusedFixMistake(prompt: string, correctAnswer: string): boolean {
  const incorrect = mistakeSentence(prompt);
  if (!incorrect) return false;

  const incorrectTokens = normalizeText(incorrect).split(" ").filter(Boolean);
  const correctTokens = normalizeText(correctAnswer).split(" ").filter(Boolean);
  if (incorrectTokens.length !== correctTokens.length || incorrectTokens.length === 0) return false;

  const differences = incorrectTokens.filter((token, index) => token !== correctTokens[index]).length;
  return differences === 1;
}

function mistakeSentence(prompt: string): string | undefined {
  const marker = ":";
  const markerIndex = prompt.indexOf(marker);
  const sentence = markerIndex >= 0 ? prompt.slice(markerIndex + marker.length) : prompt;
  const trimmed = sentence.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function sameTokens(left: string, right: string): boolean {
  const leftTokens = normalizeText(left).split(" ").filter(Boolean).sort();
  const rightTokens = normalizeText(right).split(" ").filter(Boolean).sort();
  return leftTokens.length === rightTokens.length && leftTokens.every((token, index) => token === rightTokens[index]);
}

function normalizeText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLocaleLowerCase("en-US")
    .replace(/[^\p{Letter}\p{Number}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

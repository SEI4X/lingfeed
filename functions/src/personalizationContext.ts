import type { GenerateExerciseInput, LearningItem } from "./generator.js";

export type GenerationContext = {
  level: string;
  nativeLanguageCode: string;
  targetLanguageCode: string;
  weakItemIDs: string[];
  recentlyFailedPhrases: string[];
  recentlySeenCardIDs: string[];
  lessonTypeBalance: Record<string, number>;
  weakSkillTags: string[];
  targetScenario: string;
  bannedRepeats: string[];
};

export function buildGenerationContext(input: GenerateExerciseInput): GenerationContext {
  const itemsByID = new Map(input.items.map((item) => [item.id, item]));
  const recentEvents = input.userState.recentEvents ?? [];
  const recentlySeenCardIDs = unique(
    recentEvents
      .map((event) => event.parameters.card_id)
      .filter((cardID): cardID is string => typeof cardID === "string" && cardID.length > 0),
  ).slice(0, 20);

  return {
    level: input.userState.preferences.level,
    nativeLanguageCode: input.userState.preferences.nativeLanguageCode,
    targetLanguageCode: input.languageCode,
    weakItemIDs: weakItemIDs(input),
    recentlyFailedPhrases: recentlyFailedPhrases(recentEvents, itemsByID),
    recentlySeenCardIDs,
    lessonTypeBalance: lessonTypeBalance(recentEvents),
    weakSkillTags: weakSkillTags(input),
    targetScenario: targetScenario(input),
    bannedRepeats: unique([...input.existingCardIDs, ...recentlySeenCardIDs]).slice(0, 40),
  };
}

function weakItemIDs(input: GenerateExerciseInput): string[] {
  return input.items
    .filter((item) => item.languageCode === input.languageCode)
    .map((item) => ({ item, score: weaknessScore(item, input) }))
    .filter(({ score }) => score > 0)
    .sort((left, right) => {
      if (left.score === right.score) return left.item.id.localeCompare(right.item.id);
      return right.score - left.score;
    })
    .map(({ item }) => item.id)
    .slice(0, 8);
}

function weaknessScore(item: LearningItem, input: GenerateExerciseInput): number {
  const state = input.userState.itemStates[item.id];
  if (!state) return 20;

  let score = 0;
  if (state.strength < 0.45) score += (0.45 - state.strength) * 100;
  if (Date.parse(state.nextReviewAt) <= input.now.getTime()) score += 25;
  score += state.lapses * 20;
  score += Math.max(0, state.difficulty - 0.5) * 10;
  return score;
}

function recentlyFailedPhrases(
  recentEvents: NonNullable<GenerateExerciseInput["userState"]["recentEvents"]>,
  itemsByID: Map<string, LearningItem>,
): string[] {
  const phrases: string[] = [];
  for (const event of recentEvents) {
    if (event.name !== "card_answered" || event.parameters.is_correct !== false) continue;
    for (const itemID of event.parameters.target_item_ids ?? []) {
      const value = itemsByID.get(itemID)?.value;
      if (value) phrases.push(value);
    }
  }
  return unique(phrases).slice(0, 8);
}

function lessonTypeBalance(recentEvents: NonNullable<GenerateExerciseInput["userState"]["recentEvents"]>): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const event of recentEvents) {
    const lessonType = event.parameters.lesson_type;
    if (!lessonType) continue;
    counts[lessonType] = (counts[lessonType] ?? 0) + 1;
  }
  return counts;
}

function targetScenario(input: GenerateExerciseInput): string {
  const interest = input.userState.preferences.interests[0];
  const goals = input.userState.preferences.goals?.filter((goal) => goal.length > 0) ?? [];
  const goalText = goals.length > 0 ? goals.join(", ") : input.userState.preferences.goal;
  return interest ? `${goalText} / ${interest}` : goalText;
}

function weakSkillTags(input: GenerateExerciseInput): string[] {
  return Object.values(input.userState.skillStates ?? {})
    .filter((state) => state.weakness >= 0.5 && state.attempts > 0)
    .sort((left, right) => right.weakness - left.weakness || left.skillTag.localeCompare(right.skillTag))
    .slice(0, 6)
    .map((state) => state.skillTag);
}

function unique<T>(values: Iterable<T>): T[] {
  return [...new Set(values)];
}

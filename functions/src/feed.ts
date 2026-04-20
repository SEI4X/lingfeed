import type { GeneratedCard, LearningEvent, UserLearningState } from "./generator.js";
import type { CardStateStatus } from "./interaction.js";

export type FeedCardState = {
  status?: CardStateStatus;
  lastInteractionAt?: string;
};

export type SelectFeedCardsInput = {
  cards: GeneratedCard[];
  cardStates: Record<string, FeedCardState>;
  userState: UserLearningState;
  recentEvents: LearningEvent[];
  now: Date;
  limit: number;
  excludeCardIDs?: Set<string>;
};

type RecentFeedSignals = {
  failedItemWeights: Record<string, number>;
  easyItemWeights: Record<string, number>;
  lessonTypeCounts: Record<string, number>;
};

const weights = {
  base: 10,
  newItem: 18,
  dueReview: 45,
  lowStrength: 24,
  lapse: 10,
  deferred: 6,
  immediateLessonRepeatPenalty: 8,
  recentLessonRepeatPenalty: 3,
  weakSkill: 22,
  recentFailure: 32,
  recentTooEasyPenalty: 24,
  easyCardDifficultyBonus: 6,
  selectedGoal: 45,
  explorationGoalPenalty: 20,
} as const;

export function selectFeedCards(input: SelectFeedCardsInput): GeneratedCard[] {
  const lastLessonType = recentLessonType(input.recentEvents);
  const recentSignals = buildRecentFeedSignals(input.recentEvents);
  return input.cards
    .filter((card) => isEligible(card, input.cardStates[card.id], input.excludeCardIDs))
    .map((card) => ({
      card,
      score: scoreCard(card, input.cardStates[card.id], input.userState, input.now, lastLessonType, recentSignals),
    }))
    .sort((left, right) => {
      if (left.score === right.score) return left.card.id.localeCompare(right.card.id);
      return right.score - left.score;
    })
    .slice(0, input.limit)
    .map((item) => item.card);
}

function isEligible(card: GeneratedCard, state: FeedCardState | undefined, excludeCardIDs: Set<string> | undefined): boolean {
  if (excludeCardIDs?.has(card.id)) return false;
  if (!state?.status) return true;
  return state.status !== "answered" && state.status !== "tooEasy" && state.status !== "skipped";
}

function scoreCard(
  card: GeneratedCard,
  cardState: FeedCardState | undefined,
  userState: UserLearningState,
  now: Date,
  lastLessonType: string | undefined,
  recentSignals: RecentFeedSignals,
): number {
  let score = weights.base;
  for (const itemID of card.targetItemIDs) {
    const itemState = userState.itemStates[itemID];
    if (!itemState) {
      score += weights.newItem;
      score -= (recentSignals.easyItemWeights[itemID] ?? 0) * weights.recentTooEasyPenalty;
      continue;
    }
    if (Date.parse(itemState.nextReviewAt) <= now.getTime()) score += weights.dueReview;
    score += (1 - itemState.strength) * weights.lowStrength;
    score += itemState.lapses * weights.lapse;
    score += (recentSignals.failedItemWeights[itemID] ?? 0) * weights.recentFailure;
    score -= (recentSignals.easyItemWeights[itemID] ?? 0) * weights.recentTooEasyPenalty;
  }

  if (cardState?.status === "deferred") score += weights.deferred;
  if (card.type === lastLessonType) score -= weights.immediateLessonRepeatPenalty;
  score -= (recentSignals.lessonTypeCounts[card.type] ?? 0) * weights.recentLessonRepeatPenalty;
  if (card.missionID) {
    const selectedGoals = selectedGoalIDs(userState);
    if (selectedGoals.has(card.missionID)) {
      score += weights.selectedGoal;
    } else {
      score -= weights.explorationGoalPenalty;
    }
  }
  for (const skillTag of card.skillTags) {
    const skillState = userState.skillStates?.[skillTag];
    if (skillState && skillState.attempts > 0) {
      score += Math.min(28, skillState.weakness * weights.weakSkill + Math.log1p(skillState.attempts) * 1.5);
    }
  }
  score += Math.max(0, weights.easyCardDifficultyBonus - card.difficulty);
  return score;
}

function selectedGoalIDs(userState: UserLearningState): Set<string> {
  const goals = userState.preferences.goals?.filter((goal) => goal.length > 0) ?? [];
  return new Set(goals.length > 0 ? goals : [userState.preferences.goal]);
}

function buildRecentFeedSignals(events: LearningEvent[]): RecentFeedSignals {
  const failedItemWeights: Record<string, number> = {};
  const easyItemWeights: Record<string, number> = {};
  const lessonTypeCounts: Record<string, number> = {};

  for (const [index, event] of events.slice(0, 12).entries()) {
    const decay = Math.max(0.25, 1 - index * 0.08);
    const lessonType = event.parameters.lesson_type;
    if (lessonType) lessonTypeCounts[lessonType] = (lessonTypeCounts[lessonType] ?? 0) + decay;

    if (event.name === "card_answered" && event.parameters.is_correct === false) {
      addItemWeights(failedItemWeights, event.parameters.target_item_ids ?? [], decay);
    }

    if (event.name === "card_too_easy") {
      addItemWeights(easyItemWeights, event.parameters.target_item_ids ?? [], decay);
    }
  }

  return { failedItemWeights, easyItemWeights, lessonTypeCounts };
}

function addItemWeights(target: Record<string, number>, itemIDs: string[], weight: number): void {
  for (const itemID of itemIDs) {
    target[itemID] = Math.min(1.5, (target[itemID] ?? 0) + weight);
  }
}

function recentLessonType(events: LearningEvent[]): string | undefined {
  for (const event of events) {
    const lessonType = event.parameters.lesson_type;
    if (typeof lessonType === "string" && lessonType.length > 0) return lessonType;
  }
  return undefined;
}

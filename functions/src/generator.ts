export type LearningItem = {
  id: string;
  kind: string;
  languageCode: string;
  value: string;
  translation?: string;
  explanation?: string;
  tags: string[];
  level: string;
};

export type UserLearningState = {
  preferences: {
    targetLanguageCode: string;
    nativeLanguageCode: string;
    level: string;
    goal: string;
    goals?: string[];
    interests: string[];
    dailyMinutes: number;
  };
  itemStates: Record<string, {
    itemID: string;
    kind: string;
    strength: number;
    difficulty: number;
    repetitions: number;
    lapses: number;
    nextReviewAt: string;
  }>;
  skillStates?: Record<string, {
    skillTag: string;
    weakness: number;
    attempts: number;
    correct: number;
    lastReviewedAt?: string;
  }>;
  recentEvents?: LearningEvent[];
};

export type LearningEvent = {
  name: "card_answered" | "card_skipped" | "card_too_easy" | string;
  createdAt?: string;
  parameters: {
    is_correct?: boolean;
    target_item_ids?: string[];
    card_id?: string;
    lesson_type?: string;
  };
};

export type GeneratedCard = {
  id: string;
  type: "translate" | "multipleChoice" | "fillGap" | "reorder" | "fixMistake" | "chat";
  context: string;
  situation: string;
  prompt: string;
  options: string[];
  correctAnswer: string;
  explanation: string;
  chatMessages: Array<{ id: string; text: string; isUser: boolean }>;
  targetItemIDs: string[];
  skillTags: string[];
  difficulty: number;
  missionID: string;
};

export type GenerateExerciseInput = {
  languageCode: string;
  items: LearningItem[];
  userState: UserLearningState;
  existingCardIDs: Set<string>;
  limit: number;
  now: Date;
};

export function generateExerciseCards(input: GenerateExerciseInput): GeneratedCard[] {
  if (input.limit <= 0) return [];

  const generated: GeneratedCard[] = [];
  const rankedItems = input.items
    .filter((item) => item.languageCode === input.languageCode)
    .sort((left, right) => {
      const leftScore = scoreItem(left, input.userState, input.now);
      const rightScore = scoreItem(right, input.userState, input.now);
      if (leftScore === rightScore) return left.id.localeCompare(right.id);
      return rightScore - leftScore;
    });

  for (const item of rankedItems) {
    const usedIDs = new Set([...input.existingCardIDs, ...generated.map((card) => card.id)]);
    for (const card of templatesFor(item, input.userState, usedIDs, rankedItems)) {
      generated.push(card);
      if (generated.length === input.limit) return generated;
    }
  }

  return generated;
}

function scoreItem(item: LearningItem, userState: UserLearningState, now: Date): number {
  const itemState = userState.itemStates[item.id];
  let score = 10;
  if (!itemState) score += 20;
  if (itemState && Date.parse(itemState.nextReviewAt) <= now.getTime()) score += 40;
  if (itemState) score += (1 - itemState.strength) * 20;
  if (itemState && itemState.strength >= 0.85 && Date.parse(itemState.nextReviewAt) > now.getTime()) score -= 50;
  score += item.tags.filter((tag) => userState.preferences.interests.includes(tag)).length * 5;
  score += recentEventScore(item.id, userState.recentEvents ?? []);
  return score;
}

function recentEventScore(itemID: string, events: LearningEvent[]): number {
  let score = 0;
  for (const event of events) {
    const targetItemIDs = event.parameters.target_item_ids ?? [];
    if (!targetItemIDs.includes(itemID)) continue;

    switch (event.name) {
      case "card_answered":
        score += event.parameters.is_correct === false ? 60 : -8;
        break;
      case "card_skipped":
        score += 18;
        break;
      case "card_too_easy":
        score -= 80;
        break;
      default:
        break;
    }
  }
  return score;
}

function templatesFor(
  item: LearningItem,
  userState: UserLearningState,
  existingCardIDs: Set<string>,
  allItems: LearningItem[],
): GeneratedCard[] {
  const context = `${item.level} / ${item.tags[0] ?? item.kind}`;
  const primaryMissionID = primaryGoal(userState);
  const explorationMissionID = explorationGoal(userState) ?? primaryMissionID;
  const situation = situationFor(item, primaryMissionID);
  const explorationSituation = situationFor(item, explorationMissionID);
  const explanation = item.explanation ?? explanationFallback(item);
  const difficulty = Math.max(
    1,
    Math.min(5, levelDifficulty(item.level) + Math.round((userState.itemStates[item.id]?.difficulty ?? 0.5) * 2)),
  );

  const candidates: Array<{ order: number; card: GeneratedCard }> = [
    {
      order: nextVariant(item.id, "translate", existingCardIDs),
      card: {
        id: cardID(item.languageCode, item.id, "translate", existingCardIDs),
        type: "translate",
        context,
        situation,
        prompt: translatePrompt(item),
        options: [],
        correctAnswer: item.value,
        explanation,
        chatMessages: [],
        targetItemIDs: [item.id],
        skillTags: item.tags,
        difficulty,
        missionID: primaryMissionID,
      },
    },
    {
      order: nextVariant(item.id, "choice", existingCardIDs),
      card: {
        id: cardID(item.languageCode, item.id, "choice", existingCardIDs),
        type: "multipleChoice",
        context,
        situation,
        prompt: multipleChoicePrompt(item),
        options: choiceOptions(item, allItems),
        correctAnswer: item.value,
        explanation,
        chatMessages: [],
        targetItemIDs: [item.id],
        skillTags: item.tags,
        difficulty,
        missionID: primaryMissionID,
      },
    },
  ];

  const chat = chatCardFor(item, {
    context,
    situation,
    explanation,
    options: choiceOptions(item, allItems),
    difficulty,
    missionID: primaryMissionID,
    existingCardIDs,
  });
  if (chat) {
    candidates.push({
      order: nextVariant(item.id, "chat", existingCardIDs),
      card: chat,
    });
  }

  const gap = gapPrompt(item.value, allItems);
  if (gap) {
    candidates.push({
      order: nextVariant(item.id, "fill", existingCardIDs),
      card: {
        id: cardID(item.languageCode, item.id, "fill", existingCardIDs),
        type: "fillGap",
        context,
        situation,
        prompt: gap.prompt,
        options: gap.options,
        correctAnswer: gap.answer,
        explanation,
        chatMessages: [],
        targetItemIDs: [item.id],
        skillTags: item.tags,
        difficulty,
        missionID: primaryMissionID,
      },
    });
  }

  const reorder = reorderOptions(item.value);
  if (reorder) {
    candidates.push({
      order: nextVariant(item.id, "reorder", existingCardIDs),
      card: {
        id: cardID(item.languageCode, item.id, "reorder", existingCardIDs),
        type: "reorder",
        context,
        situation: explorationSituation,
        prompt: `Build the sentence: ${item.translation ?? item.value}`,
        options: reorder,
        correctAnswer: item.value,
        explanation,
        chatMessages: [],
        targetItemIDs: [item.id],
        skillTags: item.tags,
        difficulty,
        missionID: explorationMissionID,
      },
    });
  }

  const mistake = mistakePrompt(item.value);
  if (mistake) {
    candidates.push({
      order: nextVariant(item.id, "fix", existingCardIDs),
      card: {
        id: cardID(item.languageCode, item.id, "fix", existingCardIDs),
        type: "fixMistake",
        context,
        situation,
        prompt: `Fix the sentence: ${mistake}`,
        options: [],
        correctAnswer: item.value,
        explanation,
        chatMessages: [],
        targetItemIDs: [item.id],
        skillTags: item.tags,
        difficulty,
        missionID: primaryMissionID,
      },
    });
  }

  return candidates
    .sort((left, right) => left.order - right.order)
    .map((candidate) => candidate.card)
    .filter((card) => !existingCardIDs.has(card.id));
}

function primaryGoal(userState: UserLearningState): string {
  const goals = userState.preferences.goals?.filter((goal) => goal.length > 0) ?? [];
  return goals[0] ?? userState.preferences.goal;
}

function explorationGoal(userState: UserLearningState): string | undefined {
  const selected = new Set(userState.preferences.goals?.filter((goal) => goal.length > 0) ?? [userState.preferences.goal]);
  return ["travel", "work", "dating", "relocation", "study", "everyday"].find((goal) => !selected.has(goal));
}

function cardID(languageCode: string, itemID: string, type: string, existingCardIDs: Set<string>): string {
  return `gen-${languageCode}-${itemID}-${type}-${nextVariant(itemID, type, existingCardIDs)}`;
}

function nextVariant(itemID: string, type: string, existingCardIDs: Set<string>): number {
  const variants = [...existingCardIDs]
    .filter((id) => id.startsWith("gen-") && id.includes(`-${itemID}-${type}-`))
    .map((id) => Number(id.split("-").at(-1)))
    .filter((variant) => Number.isFinite(variant));
  return (variants.length ? Math.max(...variants) : 0) + 1;
}

function translatePrompt(item: LearningItem): string {
  return item.translation ? item.translation : `Use: ${item.value}`;
}

function multipleChoicePrompt(item: LearningItem): string {
  return item.translation ? `Which phrase means: ${item.translation}?` : `Choose the phrase: ${item.value}`;
}

function choiceOptions(item: LearningItem, allItems: LearningItem[]): string[] {
  const distractors = allItems
    .filter((candidate) => candidate.id !== item.id && candidate.languageCode === item.languageCode)
    .map((candidate) => candidate.value)
    .filter((value) => value.length > 0);
  return unique([item.value, ...distractors]).slice(0, 4);
}

function chatCardFor(
  item: LearningItem,
  input: {
    context: string;
    situation: string;
    explanation: string;
    options: string[];
    difficulty: number;
    missionID: string;
    existingCardIDs: Set<string>;
  },
): GeneratedCard | undefined {
  if (item.kind === "lexeme") return undefined;
  if (!item.tags.includes("chat") && !item.tags.includes("small_talk")) return undefined;
  if (input.options.length < 2 || !input.options.includes(item.value)) return undefined;

  return {
    id: cardID(item.languageCode, item.id, "chat", input.existingCardIDs),
    type: "chat",
    context: input.context,
    situation: input.situation,
    prompt: "Choose the natural reply.",
    options: input.options,
    correctAnswer: item.value,
    explanation: input.explanation,
    chatMessages: [{ id: `${item.id}-chat-${nextVariant(item.id, "chat", input.existingCardIDs)}`, text: chatPrompt(item), isUser: false }],
    targetItemIDs: [item.id],
    skillTags: item.tags,
    difficulty: input.difficulty,
    missionID: input.missionID,
  };
}

function gapPrompt(value: string, allItems: LearningItem[]): { prompt: string; answer: string; options: string[] } | undefined {
  const parts = value.split(" ").filter(Boolean);
  if (parts.length < 2) return undefined;
  const answer = parts.at(-1) ?? "";
  const options = gapOptions(answer, allItems);
  if (options.length < 2) return undefined;
  return {
    prompt: `${parts.slice(0, -1).join(" ")} ____`,
    answer,
    options,
  };
}

function gapOptions(answer: string, allItems: LearningItem[]): string[] {
  const distractors = allItems
    .flatMap((item) => item.value.split(" ").filter(Boolean).slice(-1))
    .filter((value) => normalizeToken(value) && normalizeToken(value) !== normalizeToken(answer));
  return unique([answer, ...distractors]).slice(0, 4);
}

function reorderOptions(value: string): string[] | undefined {
  const parts = value.split(" ").filter(Boolean);
  if (parts.length < 2) return undefined;
  return [...parts].sort((left, right) => right.localeCompare(left));
}

function mistakePrompt(value: string): string | undefined {
  const replacements: Array<[RegExp, string]> = [
    [/\bsoy\b/i, "es"],
    [/\btengo\b/i, "tiene"],
    [/\bestoy\b/i, "es"],
    [/\bquiero\b/i, "quiere"],
  ];

  for (const [pattern, replacement] of replacements) {
    if (pattern.test(value)) return value.replace(pattern, replacement);
  }

  return undefined;
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}

function normalizeToken(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLocaleLowerCase("en-US")
    .replace(/[^\p{Letter}\p{Number}]+/gu, "")
    .trim();
}

function chatPrompt(item: LearningItem): string {
  if (item.tags.includes("coffee")) return "Para tomar aqui o para llevar?";
  if (item.tags.includes("small_talk")) return "Hola, como estas?";
  if (item.tags.includes("chat")) return "Nice to meet you.";
  return item.translation ?? item.value;
}

function situationFor(item: LearningItem, goal: string): string {
  if (item.tags.includes("coffee")) return "You are ordering coffee.";
  if (item.tags.includes("restaurant")) return "You are speaking with a waiter.";
  switch (goal) {
    case "work": return "You are speaking at work.";
    case "dating": return "You are keeping a conversation warm.";
    case "relocation": return "You are handling daily life.";
    case "study": return "You are practicing for class.";
    case "everyday": return "You are in a normal daily conversation.";
    default: return "You are traveling and need a quick phrase.";
  }
}

function explanationFallback(item: LearningItem): string {
  return item.translation ? `${item.value} means ${item.translation}.` : "Use this phrase as a natural answer in context.";
}

function levelDifficulty(level: string): number {
  switch (level) {
    case "A2": return 2;
    case "B1": return 3;
    case "B2": return 4;
    case "C1":
    case "C2": return 5;
    default: return 1;
  }
}

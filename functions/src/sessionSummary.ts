import type { ServerSkillState } from "./interaction.js";

export type BackendSessionStats = {
  answered: number;
  correct: number;
  skipped: number;
};

export type BackendProfile = {
  streak: number;
  totalLearned: number;
  weakTopics: string[];
};

export type BackendSessionSummary = {
  stats: BackendSessionStats;
  profile: BackendProfile;
  accuracy: number;
};

export function buildSessionSummary(input: {
  sessionStats: Partial<BackendSessionStats>;
  profile: BackendProfile;
  skillStates: ServerSkillState[];
}): BackendSessionSummary {
  const stats = {
    answered: numberOrZero(input.sessionStats.answered),
    correct: numberOrZero(input.sessionStats.correct),
    skipped: numberOrZero(input.sessionStats.skipped),
  };
  const weakTopics = input.skillStates
    .filter((state) => state.weakness >= 0.55 && state.attempts > 0)
    .sort((left, right) => right.weakness - left.weakness || left.skillTag.localeCompare(right.skillTag))
    .slice(0, 3)
    .map((state) => state.skillTag);

  return {
    stats,
    profile: {
      ...input.profile,
      weakTopics: weakTopics.length > 0 ? weakTopics : input.profile.weakTopics,
    },
    accuracy: stats.answered > 0 ? Math.round((stats.correct / stats.answered) * 100) / 100 : 0,
  };
}

function numberOrZero(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

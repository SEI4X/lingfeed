import assert from "node:assert/strict";
import test from "node:test";
import { buildSessionSummary } from "./sessionSummary.js";

test("builds backend session summary from stats and weak skills", () => {
  const summary = buildSessionSummary({
    sessionStats: {
      answered: 8,
      correct: 5,
      skipped: 1,
    },
    profile: {
      streak: 2,
      totalLearned: 7,
      weakTopics: ["grammar"],
    },
    skillStates: [
      { skillTag: "grammar", weakness: 0.8, attempts: 4, correct: 1 },
      { skillTag: "coffee", weakness: 0.2, attempts: 4, correct: 4 },
    ],
  });

  assert.deepEqual(summary.stats, { answered: 8, correct: 5, skipped: 1 });
  assert.deepEqual(summary.profile, { streak: 2, totalLearned: 7, weakTopics: ["grammar"] });
  assert.equal(summary.accuracy, 0.63);
});

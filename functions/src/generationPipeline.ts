import { generateExerciseCards, type GeneratedCard, type GenerateExerciseInput } from "./generator.js";
import { generateLLMExerciseCardsWithDiagnostics, type LLMClient, type LLMGenerationDiagnostics } from "./llmGenerator.js";

export type GenerationPipelineOptions = {
  llmClient?: LLMClient;
};

export type GenerationPipelineResult = {
  cards: GeneratedCard[];
  provider: string;
  requestedProvider?: string;
  fallbackUsed: boolean;
  fallbackReason?: string;
  diagnostics: LLMGenerationDiagnostics;
};

export async function generatePersonalizedExerciseCards(
  input: GenerateExerciseInput,
  options: GenerationPipelineOptions = {},
): Promise<GeneratedCard[]> {
  return (await generatePersonalizedExerciseCardsWithMetadata(input, options)).cards;
}

export async function generatePersonalizedExerciseCardsWithMetadata(
  input: GenerateExerciseInput,
  options: GenerationPipelineOptions = {},
): Promise<GenerationPipelineResult> {
  if (options.llmClient) {
    const llmResult = await generateLLMExerciseCardsWithDiagnostics(input, options.llmClient);
    if (llmResult.cards.length > 0) {
      return {
        cards: llmResult.cards,
        provider: options.llmClient.providerName ?? "llm",
        fallbackUsed: false,
        diagnostics: llmResult.diagnostics,
      };
    }
    const fallbackCards = generateExerciseCards(input);
    return {
      cards: fallbackCards,
      provider: "rules",
      requestedProvider: options.llmClient?.providerName,
      fallbackUsed: true,
      fallbackReason: "no_valid_llm_cards",
      diagnostics: llmResult.diagnostics,
    };
  }

  const cards = generateExerciseCards(input);
  return {
    cards,
    provider: "rules",
    fallbackUsed: false,
    diagnostics: {
      acceptedCardCount: cards.length,
      rejectedCardCount: 0,
      rejectReasons: {},
      lessonTypeDistribution: Object.fromEntries(
        Object.entries(cards.reduce<Record<string, number>>((distribution, card) => {
          distribution[card.type] = (distribution[card.type] ?? 0) + 1;
          return distribution;
        }, {})),
      ),
    },
  };
}

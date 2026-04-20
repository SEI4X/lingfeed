import type { GeneratedCard, GenerateExerciseInput, LearningItem } from "./generator.js";
import { buildGenerationContext } from "./personalizationContext.js";
import { validateCardQuality } from "./cardQuality.js";

export type LLMClient = {
  providerName?: string;
  createResponse(request: Record<string, unknown>): Promise<unknown>;
};

type LLMCard = Omit<GeneratedCard, "id">;

export type LLMGenerationDiagnostics = {
  acceptedCardCount: number;
  rejectedCardCount: number;
  rejectReasons: Record<string, number>;
  lessonTypeDistribution: Record<string, number>;
};

export type LLMGenerationResult = {
  cards: GeneratedCard[];
  diagnostics: LLMGenerationDiagnostics;
};

export async function generateLLMExerciseCards(input: GenerateExerciseInput, client: LLMClient): Promise<GeneratedCard[]> {
  return (await generateLLMExerciseCardsWithDiagnostics(input, client)).cards;
}

export async function generateLLMExerciseCardsWithDiagnostics(input: GenerateExerciseInput, client: LLMClient): Promise<LLMGenerationResult> {
  try {
    const response = await client.createResponse(buildRequest(input));
    const cards = parseCards(response);
    return validateCards(cards, input, client.providerName ?? "llm", input.limit);
  } catch {
    return { cards: [], diagnostics: emptyDiagnostics() };
  }
}

export class OpenAIResponsesClient implements LLMClient {
  readonly providerName = "openai";
  private readonly apiKey: string;
  private readonly model: string;

  constructor(apiKey: string, model = process.env.OPENAI_MODEL ?? "gpt-5") {
    this.apiKey = apiKey;
    this.model = model;
  }

  async createResponse(request: Record<string, unknown>): Promise<unknown> {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        authorization: `Bearer ${this.apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: this.model,
        ...request,
      }),
    });

    if (!response.ok) {
      throw new Error(`OpenAI response failed: ${response.status}`);
    }

    return response.json();
  }
}

type FetchFunction = typeof fetch;

type VertexAIGeminiClientOptions = {
  projectID?: string;
  location?: string;
  model?: string;
  accessTokenProvider?: () => Promise<string>;
  fetchFn?: FetchFunction;
};

export class VertexAIGeminiClient implements LLMClient {
  readonly providerName = "gemini";
  private readonly projectID: string;
  private readonly location: string;
  private readonly model: string;
  private readonly accessTokenProvider: () => Promise<string>;
  private readonly fetchFn: FetchFunction;

  constructor(options: VertexAIGeminiClientOptions = {}) {
    const projectID = options.projectID ?? process.env.GOOGLE_CLOUD_PROJECT ?? process.env.GCP_PROJECT ?? process.env.GCLOUD_PROJECT;
    if (!projectID) {
      throw new Error("Missing Google Cloud project id for Gemini.");
    }

    this.projectID = projectID;
    this.location = options.location ?? process.env.GEMINI_LOCATION ?? process.env.GOOGLE_CLOUD_LOCATION ?? "us-central1";
    this.model = options.model ?? process.env.GEMINI_MODEL ?? "gemini-2.5-flash";
    this.accessTokenProvider = options.accessTokenProvider ?? metadataAccessToken;
    this.fetchFn = options.fetchFn ?? fetch;
  }

  async createResponse(request: Record<string, unknown>): Promise<unknown> {
    const accessToken = await this.accessTokenProvider();
    const url = `https://${this.location}-aiplatform.googleapis.com/v1/projects/${this.projectID}/locations/${this.location}/publishers/google/models/${this.model}:generateContent`;
    const response = await this.fetchFn(url, {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(toGeminiRequest(request)),
    });

    if (!response.ok) {
      throw new Error(`Gemini response failed: ${response.status}`);
    }

    return response.json();
  }
}

function buildRequest(input: GenerateExerciseInput): Record<string, unknown> {
  const targetItems = rankItems(input).slice(0, 5);
  return {
    instructions: [
      "You generate short, high-quality language learning exercises for a mobile app.",
      "Return only valid JSON matching the schema.",
      "Use the target language naturally. Keep prompts concise. Avoid explanations longer than one sentence.",
      "Use preferences.nativeLanguageCode for user-facing instructions, situations, and explanations when they are not the target-language answer.",
      "Every card must train one or more provided learning item ids. Do not invent ids.",
      "Do not generate speaking, pronunciation, listening, audio, or read-aloud tasks.",
      "Translate cards ask for a written translation into the target language; the correctAnswer must be the target-language answer.",
      "Fill-gap cards must contain exactly one blank marker like ___, include 3-4 answer options, include the correctAnswer in options, and be answerable without guessing from context alone.",
      "The fill-gap correctAnswer must be only the missing word or short phrase, never comma-separated answers.",
      "Fix-mistake cards must require exactly one local correction; the incorrect sentence and correctAnswer must have the same token count.",
      "Multiple-choice cards must include the correctAnswer in options. Reorder cards must use words from the correctAnswer as options.",
      "Chat cards must be closed-choice: include one concrete previous chat message, include 3-4 options, include the correctAnswer in options, and never use generic prompts like 'Reply naturally'.",
      "Chat answers must be phrase-level natural replies, not single lexemes such as coffee, cafe, student, yesterday, blue, or tall.",
      "Avoid ambiguous prompts where several options could reasonably be correct. There must be exactly one best answer.",
      "Use generationContext to personalize selection: focus weakItemIDs and recentlyFailedPhrases, avoid bannedRepeats, and vary lesson types using lessonTypeBalance.",
    ].join(" "),
    input: JSON.stringify({
      languageCode: input.languageCode,
      preferences: input.userState.preferences,
      generationContext: buildGenerationContext(input),
      targetItems,
      limit: input.limit,
      allowedTypes: ["translate", "multipleChoice", "fillGap", "reorder", "fixMistake", "chat"],
    }),
    text: {
      format: {
        type: "json_schema",
        name: "lingfeed_generated_cards",
        strict: true,
        schema: responseSchema,
      },
    },
  };
}

function rankItems(input: GenerateExerciseInput): LearningItem[] {
  return input.items
    .filter((item) => item.languageCode === input.languageCode)
    .sort((left, right) => {
      const leftState = input.userState.itemStates[left.id];
      const rightState = input.userState.itemStates[right.id];
      const leftScore = (leftState ? 1 - leftState.strength : 1) + (leftState?.lapses ?? 0);
      const rightScore = (rightState ? 1 - rightState.strength : 1) + (rightState?.lapses ?? 0);
      if (leftScore === rightScore) return left.id.localeCompare(right.id);
      return rightScore - leftScore;
    });
}

function parseCards(response: unknown): Array<Partial<LLMCard>> {
  const text = outputText(response);
  const parsed = JSON.parse(text) as unknown;
  if (!isRecord(parsed) || !Array.isArray(parsed.cards)) return [];
  return parsed.cards.filter(isRecord) as Array<Partial<LLMCard>>;
}

function outputText(response: unknown): string {
  if (isRecord(response) && typeof response.output_text === "string") return response.output_text;

  if (isRecord(response) && Array.isArray(response.output)) {
    for (const item of response.output) {
      if (!isRecord(item) || !Array.isArray(item.content)) continue;
      for (const content of item.content) {
        if (isRecord(content) && typeof content.text === "string") return content.text;
      }
    }
  }

  if (isRecord(response) && Array.isArray(response.candidates)) {
    for (const candidate of response.candidates) {
      if (!isRecord(candidate) || !isRecord(candidate.content) || !Array.isArray(candidate.content.parts)) continue;
      for (const part of candidate.content.parts) {
        if (isRecord(part) && typeof part.text === "string") return part.text;
      }
    }
  }

  throw new Error("Missing LLM output text");
}

function validateCards(cards: Array<Partial<LLMCard>>, input: GenerateExerciseInput, idPrefix: string, limit: number): LLMGenerationResult {
  const itemsByID = new Map(input.items.filter((item) => item.languageCode === input.languageCode).map((item) => [item.id, item]));
  const generated: GeneratedCard[] = [];
  const rejectReasons: Record<string, number> = {};

  for (const card of cards) {
    const quality = validateCardQuality({ card, itemsByID });
    if (!quality.valid) {
      for (const reason of quality.reasons) {
        rejectReasons[reason] = (rejectReasons[reason] ?? 0) + 1;
      }
      continue;
    }

    const validCard = card as LLMCard;
    const id = cardID(idPrefix, input.languageCode, validCard, new Set([...input.existingCardIDs, ...generated.map((item) => item.id)]));
    generated.push({ ...validCard, id });
    if (generated.length === limit) break;
  }

  return {
    cards: generated,
    diagnostics: {
      acceptedCardCount: generated.length,
      rejectedCardCount: Object.values(rejectReasons).reduce((sum, count) => sum + count, 0),
      rejectReasons,
      lessonTypeDistribution: lessonTypeDistribution(generated),
    },
  };
}

function cardID(idPrefix: string, languageCode: string, card: LLMCard, existingCardIDs: Set<string>): string {
  const itemID = card.targetItemIDs[0] ?? "card";
  let variant = 1;
  let id = `${idPrefix}-${languageCode}-${itemID}-${card.type}-${variant}`;
  while (existingCardIDs.has(id)) {
    variant += 1;
    id = `${idPrefix}-${languageCode}-${itemID}-${card.type}-${variant}`;
  }
  return id;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function emptyDiagnostics(): LLMGenerationDiagnostics {
  return {
    acceptedCardCount: 0,
    rejectedCardCount: 0,
    rejectReasons: {},
    lessonTypeDistribution: {},
  };
}

function lessonTypeDistribution(cards: GeneratedCard[]): Record<string, number> {
  const distribution: Record<string, number> = {};
  for (const card of cards) {
    distribution[card.type] = (distribution[card.type] ?? 0) + 1;
  }
  return distribution;
}

async function metadataAccessToken(): Promise<string> {
  const response = await fetch("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token", {
    headers: {
      "metadata-flavor": "Google",
    },
  });

  if (!response.ok) {
    throw new Error(`Metadata token request failed: ${response.status}`);
  }

  const token = await response.json() as { access_token?: unknown };
  if (typeof token.access_token !== "string" || token.access_token.length === 0) {
    throw new Error("Metadata token response did not include an access token.");
  }

  return token.access_token;
}

function toGeminiRequest(request: Record<string, unknown>): Record<string, unknown> {
  const instructions = typeof request.instructions === "string" ? request.instructions : "";
  const input = typeof request.input === "string" ? request.input : JSON.stringify(request.input ?? {});
  const schema = geminiSchemaFromRequest(request);
  return {
    contents: [
      {
        role: "user",
        parts: [
          {
            text: `${instructions}\n\nInput JSON:\n${input}`,
          },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: schema,
    },
  };
}

function geminiSchemaFromRequest(request: Record<string, unknown>): unknown {
  const text = isRecord(request.text) ? request.text : {};
  const format = isRecord(text.format) ? text.format : {};
  return toGeminiSchema(format.schema ?? responseSchema);
}

function toGeminiSchema(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(toGeminiSchema);
  if (!isRecord(value)) return value;

  const converted: Record<string, unknown> = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === "additionalProperties" || key === "maxItems" || key === "minimum" || key === "maximum") continue;
    converted[key] = toGeminiSchema(child);
  }
  return converted;
}

const responseSchema = {
  type: "object",
  additionalProperties: false,
  required: ["cards"],
  properties: {
    cards: {
      type: "array",
      maxItems: 12,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "type",
          "context",
          "situation",
          "prompt",
          "options",
          "correctAnswer",
          "explanation",
          "chatMessages",
          "targetItemIDs",
          "skillTags",
          "difficulty",
          "missionID",
        ],
        properties: {
          type: { type: "string", enum: ["translate", "multipleChoice", "fillGap", "reorder", "fixMistake", "chat"] },
          context: { type: "string" },
          situation: { type: "string" },
          prompt: { type: "string" },
          options: { type: "array", items: { type: "string" } },
          correctAnswer: { type: "string" },
          explanation: { type: "string" },
          chatMessages: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["id", "text", "isUser"],
              properties: {
                id: { type: "string" },
                text: { type: "string" },
                isUser: { type: "boolean" },
              },
            },
          },
          targetItemIDs: { type: "array", items: { type: "string" } },
          skillTags: { type: "array", items: { type: "string" } },
          difficulty: { type: "integer", minimum: 1, maximum: 5 },
          missionID: { type: "string" },
        },
      },
    },
  },
} as const;

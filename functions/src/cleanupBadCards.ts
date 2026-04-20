import { readFileSync } from "node:fs";
import { validateCardQuality } from "./cardQuality.js";
import type { GeneratedCard, LearningItem } from "./generator.js";

export type CleanupInput = {
  cards: Array<Partial<GeneratedCard> & { id: string; languageCode?: string; status?: string }>;
  items: LearningItem[];
};

export type CleanupResult = {
  archive: Array<{ cardID: string; rejectReasons: string[] }>;
  keepCount: number;
};

export function evaluateCardsForCleanup(input: CleanupInput): CleanupResult {
  const itemsByID = new Map(input.items.map((item) => [item.id, item]));
  const archive: CleanupResult["archive"] = [];
  let keepCount = 0;

  for (const card of input.cards) {
    if (card.status && card.status !== "active") continue;
    const languageMismatchReasons = targetLanguageMismatchReasons(card, itemsByID);
    if (languageMismatchReasons.length > 0) {
      archive.push({ cardID: card.id, rejectReasons: languageMismatchReasons });
      continue;
    }

    const quality = validateCardQuality({ card, itemsByID });
    if (quality.valid) {
      keepCount += 1;
    } else {
      archive.push({ cardID: card.id, rejectReasons: quality.reasons });
    }
  }

  return { archive, keepCount };
}

function targetLanguageMismatchReasons(
  card: Partial<GeneratedCard> & { id: string; languageCode?: string },
  itemsByID: Map<string, LearningItem>,
): string[] {
  if (!card.languageCode || card.languageCode === "es") return [];
  const values = [
    card.context,
    card.situation,
    card.prompt,
    card.correctAnswer,
    card.explanation,
    ...(card.options ?? []),
    ...(card.chatMessages ?? []).map((message) => message.text),
    ...(card.targetItemIDs ?? []).map((itemID) => itemsByID.get(itemID)?.value),
  ];
  const combined = values.filter((value): value is string => typeof value === "string").join(" ");

  return containsSpanishSeedText(combined) ? ["target_language_content_mismatch"] : [];
}

function containsSpanishSeedText(value: string): boolean {
  const normalized = value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLocaleLowerCase("en-US");

  return [
    /\bquiero\b/,
    /\bgracias\b/,
    /\bpara llevar\b/,
    /\bbuenas noches\b/,
    /\btengo dos\b/,
    /\bhasta ayer\b/,
    /\baqui tienes\b/,
    /\bun cafe\b/,
    /\byo es\b/,
    /\byo soy\b/,
  ].some((pattern) => pattern.test(normalized));
}

async function main() {
  const token = firebaseAccessToken();
  const [cards, items] = await Promise.all([listActiveCards(token), listLearningItems(token)]);
  const result = evaluateCardsForCleanup({ cards, items });

  for (const chunk of chunks(result.archive, 450)) {
    await Promise.all(chunk.map((entry) => patchDocument(token, `cards/${entry.cardID}`, {
        status: "archived",
        archivedReason: "quality_validation_failed",
        rejectReasons: entry.rejectReasons,
        archivedAt: new Date().toISOString(),
      })));
  }
  console.log(JSON.stringify({ archived: result.archive.length, kept: result.keepCount, archive: result.archive }, null, 2));
}

const projectID = process.env.FIREBASE_PROJECT_ID ?? process.env.GOOGLE_CLOUD_PROJECT ?? "ling-feed";

async function listActiveCards(token: string): Promise<Array<Partial<GeneratedCard> & { id: string; languageCode?: string; status?: string }>> {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectID}/databases/(default)/documents:runQuery`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: "cards" }],
          where: {
            fieldFilter: {
              field: { fieldPath: "status" },
              op: "EQUAL",
              value: { stringValue: "active" },
            },
          },
        },
      }),
    },
  );
  if (!response.ok) throw new Error(`Failed to list active cards: ${response.status} ${await response.text()}`);

  const rows = await response.json() as Array<{ document?: FirestoreDocument }>;
  return rows
    .map((row) => row.document)
    .filter((document): document is FirestoreDocument => Boolean(document))
    .map((document) => ({ id: documentID(document.name), ...decodeFields(document.fields ?? {}) }));
}

async function listLearningItems(token: string): Promise<LearningItem[]> {
  const items: LearningItem[] = [];
  let pageToken = "";
  do {
    const url = new URL(`https://firestore.googleapis.com/v1/projects/${projectID}/databases/(default)/documents/learning_items`);
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);

    const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!response.ok) throw new Error(`Failed to list learning items: ${response.status} ${await response.text()}`);

    const body = await response.json() as { documents?: FirestoreDocument[]; nextPageToken?: string };
    items.push(...(body.documents ?? []).map((document) => ({ id: documentID(document.name), ...decodeFields(document.fields ?? {}) } as LearningItem)));
    pageToken = body.nextPageToken ?? "";
  } while (pageToken);

  return items;
}

async function patchDocument(token: string, documentPath: string, value: Record<string, unknown>): Promise<void> {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectID}/databases/(default)/documents/${documentPath}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields: encodeFields(value) }),
    },
  );

  if (!response.ok) throw new Error(`Failed to patch ${documentPath}: ${response.status} ${await response.text()}`);
}

function firebaseAccessToken(): string {
  const configPath = `${process.env.HOME}/.config/configstore/firebase-tools.json`;
  const config = JSON.parse(readFileSync(configPath, "utf8")) as { tokens?: { access_token?: string } };
  const token = config.tokens?.access_token;
  if (!token) {
    throw new Error("Firebase CLI access token not found. Run firebase login first.");
  }
  return token;
}

type FirestoreDocument = {
  name: string;
  fields?: Record<string, FirestoreValue>;
};

type FirestoreValue = {
  stringValue?: string;
  integerValue?: string;
  doubleValue?: number;
  booleanValue?: boolean;
  timestampValue?: string;
  arrayValue?: { values?: FirestoreValue[] };
  mapValue?: { fields?: Record<string, FirestoreValue> };
  nullValue?: null;
};

function documentID(name: string): string {
  return name.split("/").at(-1) ?? name;
}

function decodeFields(fields: Record<string, FirestoreValue>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

function decodeValue(value: FirestoreValue): unknown {
  if (value.stringValue !== undefined) return value.stringValue;
  if (value.integerValue !== undefined) return Number(value.integerValue);
  if (value.doubleValue !== undefined) return value.doubleValue;
  if (value.booleanValue !== undefined) return value.booleanValue;
  if (value.timestampValue !== undefined) return value.timestampValue;
  if (value.arrayValue !== undefined) return (value.arrayValue.values ?? []).map(decodeValue);
  if (value.mapValue !== undefined) return decodeFields(value.mapValue.fields ?? {});
  return null;
}

function encodeFields(value: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(value).map(([key, fieldValue]) => [key, encodeValue(fieldValue)]));
}

function encodeValue(value: unknown): Record<string, unknown> {
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "number" && Number.isInteger(value)) return { integerValue: value };
  if (typeof value === "number") return { doubleValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (value && typeof value === "object") return { mapValue: { fields: encodeFields(value as Record<string, unknown>) } };
  return { nullValue: null };
}

function chunks<T>(items: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

if (process.argv[1]?.endsWith("cleanupBadCards.js")) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

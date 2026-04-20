import { readFileSync } from "node:fs";
import { seedLearningContent } from "./seedContent.js";

const projectID = process.env.FIREBASE_PROJECT_ID ?? "ling-feed";
const languageCodes = (process.env.SEED_LANGUAGES ?? "es")
  .split(",")
  .map((language) => language.trim())
  .filter(Boolean);

async function main(): Promise<void> {
  const token = firebaseAccessToken();

  for (const languageCode of languageCodes) {
    const seed = seedLearningContent(languageCode);

    for (const item of seed.items) {
      await patchDocument(token, `learning_items/${item.id}`, {
        ...item,
        seeded: true,
        updatedAt: new Date().toISOString(),
      });
    }

    for (const card of seed.cards) {
      await patchDocument(token, `cards/${card.id}`, {
        ...card,
        languageCode,
        status: "active",
        seeded: true,
        updatedAt: new Date().toISOString(),
      });
    }

    console.log(`Seeded ${seed.items.length} items and ${seed.cards.length} cards for ${languageCode}.`);
  }
}

async function patchDocument(token: string, documentPath: string, value: Record<string, unknown>): Promise<void> {
  const fields = encodeFields(value);
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectID}/databases/(default)/documents/${documentPath}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
    },
  );

  if (!response.ok) {
    throw new Error(`Failed to seed ${documentPath}: ${response.status} ${await response.text()}`);
  }
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

function encodeFields(value: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(value).map(([key, fieldValue]) => [key, encodeValue(fieldValue)]));
}

function encodeValue(value: unknown): Record<string, unknown> {
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "number" && Number.isInteger(value)) return { integerValue: value };
  if (typeof value === "number") return { doubleValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (value && typeof value === "object") return { mapValue: { fields: encodeFields(value as Record<string, unknown>) } };
  return { nullValue: null };
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

# Lingfeed Functions

## Exercise generation

`generateExercises` always works with the local rule-based generator. By default it first tries Gemini through Vertex AI from Cloud Functions and falls back to rule-based cards when the provider fails or returns invalid data.

Optional environment variables:

- `GEMINI_MODEL`: overrides the default model, currently `gemini-2.5-flash`.
- `GEMINI_LOCATION`: overrides the Vertex AI location, currently `us-central1`.
- `LLM_PROVIDER=rules`: disables Gemini and uses only the local rule-based generator.

The LLM path uses structured JSON output, validates every card, assigns server-side IDs, rejects unknown `targetItemIDs`, and persists generated cards with `generatedWith` set to `gemini` or `rules`.

Each callable run writes an observability record to `users/{uid}/generation_runs/{runId}` with provider, requested provider, model, generated card IDs, fallback status, input item IDs, and latency.

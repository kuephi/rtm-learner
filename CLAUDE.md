# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the pipeline

```bash
python main.py                  # process all new 中级 episodes
python main.py --force 265      # reprocess a specific episode by number
```

## Environment setup

All secrets live in `.env` (loaded via `python-dotenv`). Required vars:

```
LLM_PROVIDER=claude             # claude | gemini | openai
ANTHROPIC_API_KEY=...           # required when LLM_PROVIDER=claude
GEMINI_API_KEY=...              # required when LLM_PROVIDER=gemini
OPENAI_API_KEY=...              # required when LLM_PROVIDER=openai
LLM_MODEL=...                   # optional — overrides the provider default
SUBSTACK_EMAIL=...
SUBSTACK_PASSWORD=...
```

Install dependencies: `pip install -r requirements.txt`

## Architecture

The pipeline runs sequentially in four steps (`main.py → process_entry`):

1. **`fetcher.py`** — Parses the RTM RSS feed, filters for `中级` episodes not yet in `data/state.json`, downloads the Substack page using an authenticated session, and strips HTML to plain text.

2. **`parser.py`** — Sends the plain text to an LLM (provider selected by `LLM_PROVIDER`) and extracts a structured JSON episode: article text (simplified + traditional), vocabulary words, idioms, dialogue, grammar patterns, and exercises.

3. **`translator.py`** — Takes the extracted words/idioms and makes a second LLM call to add `german` and `example_de` fields (the user is a German speaker).

4. **`exporters/pleco.py`** — Writes a Pleco-compatible `.txt` flashcard file (`Chinese[pinyin]\tdefinition`) which is copied to iCloud Drive for iPhone sync.

Structured episode data is saved to `data/episodes/<number>.json`. Processed URLs are tracked in `data/state.json` to avoid reprocessing.

## Substack authentication

Substack blocks automated logins via their API. Authentication uses browser-extracted session cookies stored manually in `data/session.json`:

```json
{
  "cookies": { "substack.sid": "<value from browser DevTools>" },
  "expires_at": 9999999999
}
```

The session is cached for 29 days. On HTTP 401/403 the code auto-retries with a forced re-login — but since the API login is blocked, a stale cookie must be refreshed manually from the browser.

## Known issue

`translator.py` still uses the old Gemini-only implementation (`google.generativeai`) and does not respect `LLM_PROVIDER`. It should be refactored to use the same provider-dispatch pattern as `parser.py`.

# RTM Learner — Python Pipeline

Fetches RTM Mandarin 中级 lessons, extracts vocabulary via LLM, translates to German, and exports Pleco flashcard files.

## Setup

```bash
cd python
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your credentials and API key
```

## Usage

```bash
# Process all new 中级 episodes
python main.py

# Process only the most recent new episode
python main.py --last

# Reprocess a specific episode by number
python main.py --force 265
```

Output is written to:
- `data/episodes/<number>.json` — full structured lesson data
- `data/pleco/<number>_pleco.txt` — Pleco flashcard import file

## Tests

```bash
pytest
```

## Environment variables

See `.env.example` for all available configuration options.

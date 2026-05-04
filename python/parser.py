"""Extract structured lesson data from raw page text via a configurable LLM provider."""
import json

from json_repair import repair_json

from domain.models import DialogueLine, Episode, Exercise, GrammarPattern, VocabEntry
from llm import call_llm, clean_json

_PROMPT = """
You are a structured data extractor for RTM Mandarin Chinese lessons.
Extract ALL content from the lesson text below into the exact JSON structure shown.
Return ONLY valid JSON — no markdown fences, no commentary.

JSON schema:
{
  "text_simplified": "the main simplified Chinese article text",
  "text_traditional": "the traditional Chinese version of the same text",
  "words": [
    {
      "type": "priority",
      "number": 1,
      "chinese": "内测",
      "pinyin": "nèi cè",
      "english": "internal testing, beta test",
      "example_zh": "Chinese example sentence",
      "example_en": "English translation of the example"
    }
  ],
  "idioms": [
    {
      "type": "idiom",
      "number": 1,
      "chinese": "无懈可击",
      "pinyin": "wú xiè kě jī",
      "english": "flawless, unassailable",
      "example_zh": "Chinese example sentence",
      "example_en": "English translation of the example"
    }
  ],
  "dialogue": [
    {"speaker": "老李", "line": "Chinese line"}
  ],
  "grammar": [
    {
      "pattern": "立马 + verb",
      "pinyin": "lì mǎ",
      "meaning_en": "at once / immediately",
      "examples_zh": ["example sentence 1", "example sentence 2"]
    }
  ],
  "exercises": [
    {
      "question": "question text with ___ for the blank",
      "options": ["option a", "option b", "option c", "option d"],
      "answer_index": 1,
      "answer_text": "the correct word/phrase"
    }
  ]
}

Lesson text:
"""


def _vocab_from_dict(d: dict) -> VocabEntry:
    return VocabEntry(
        type=d.get("type", "priority"),
        number=d.get("number", 0),
        chinese=d.get("chinese", ""),
        pinyin=d.get("pinyin", ""),
        english=d.get("english", ""),
        example_zh=d.get("example_zh", ""),
        example_en=d.get("example_en", ""),
    )


def extract_episode(text: str, meta: dict) -> Episode:
    """Send page text to the configured LLM and return a fully structured Episode."""
    raw = call_llm(_PROMPT + text)
    cleaned = clean_json(raw)
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        data = json.loads(repair_json(cleaned))

    return Episode(
        episode=meta.get("episode", 0),
        title=meta.get("title", ""),
        url=meta.get("url", ""),
        pub_date=meta.get("pub_date", ""),
        text_simplified=data.get("text_simplified", ""),
        text_traditional=data.get("text_traditional", ""),
        words=[_vocab_from_dict(w) for w in data.get("words", [])],
        idioms=[_vocab_from_dict(w) for w in data.get("idioms", [])],
        dialogue=[
            DialogueLine(speaker=d.get("speaker", ""), line=d.get("line", ""))
            for d in data.get("dialogue", [])
        ],
        grammar=[
            GrammarPattern(
                pattern=g.get("pattern", ""),
                pinyin=g.get("pinyin", ""),
                meaning_en=g.get("meaning_en", ""),
                examples_zh=g.get("examples_zh", []),
            )
            for g in data.get("grammar", [])
        ],
        exercises=[
            Exercise(
                question=e.get("question", ""),
                options=e.get("options", []),
                answer_index=e.get("answer_index", 0),
                answer_text=e.get("answer_text", ""),
            )
            for e in data.get("exercises", [])
        ],
    )

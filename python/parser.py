"""Extract structured lesson data from raw page text via a configurable LLM provider."""
import json

from json_repair import repair_json

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


def extract_episode(text: str, meta: dict) -> dict:
    """
    Send page text to the configured LLM and return a fully structured episode dict.
    `meta` fields (episode, title, url, pub_date) are merged into the result.
    """
    raw = call_llm(_PROMPT + text)
    cleaned = clean_json(raw)
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        data = json.loads(repair_json(cleaned))
    data.update(meta)
    return data

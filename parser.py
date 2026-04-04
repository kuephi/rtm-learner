"""Extract structured lesson data from raw page text via a configurable LLM provider."""
import json
import re

from json_repair import repair_json

from config import LLM_PROVIDER, ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENAI_API_KEY, get_model

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


def _clean_json(raw: str) -> str:
    """Strip markdown code fences if the model wrapped the output."""
    raw = raw.strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)
    return raw.strip()


def _call_claude(prompt: str) -> str:
    import anthropic
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    message = client.messages.create(
        model=get_model(),
        max_tokens=8192,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def _call_gemini(prompt: str) -> str:
    import google.generativeai as genai
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel(get_model())
    response = model.generate_content(prompt)
    return response.text


def _call_openai(prompt: str) -> str:
    from openai import OpenAI
    client = OpenAI(api_key=OPENAI_API_KEY)
    response = client.chat.completions.create(
        model=get_model(),
        messages=[{"role": "user", "content": prompt}],
    )
    return response.choices[0].message.content


_PROVIDERS = {
    "claude": _call_claude,
    "gemini": _call_gemini,
    "openai": _call_openai,
}


def extract_episode(text: str, meta: dict) -> dict:
    """
    Send page text to the configured LLM and return a fully structured episode dict.
    `meta` fields (episode, title, url, pub_date) are merged into the result.
    """
    if LLM_PROVIDER not in _PROVIDERS:
        raise ValueError(f"Unknown LLM_PROVIDER '{LLM_PROVIDER}'. Choose: {list(_PROVIDERS)}")

    prompt = _PROMPT + text
    raw = _PROVIDERS[LLM_PROVIDER](prompt)
    cleaned = _clean_json(raw)
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        data = json.loads(repair_json(cleaned))
    data.update(meta)
    return data

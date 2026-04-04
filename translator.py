"""Translate word lists from Chinese/English to German using the configured LLM provider."""
import json
import re

from json_repair import repair_json

from config import LLM_PROVIDER, ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENAI_API_KEY, get_model

_PROMPT = """
You are a Chinese-to-German language expert helping a German speaker learn Mandarin.

For each word/idiom in the JSON array below, add two fields:
- "german": a concise, natural German definition (not just a literal translation of the English)
- "example_de": a natural German translation of the provided Chinese example sentence

The words appear in a text about: {topic}
Use this context to choose the most fitting German meaning where the Chinese word is ambiguous.

Input JSON array:
{words}

Return ONLY a JSON array (same length, same order) with the added "german" and "example_de" fields.
No markdown, no explanation.
"""


def _clean_json(raw: str) -> str:
    raw = raw.strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)
    return raw.strip()


def _call_claude(prompt: str) -> str:
    import anthropic
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    message = client.messages.create(
        model=get_model(),
        max_tokens=4096,
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


def translate_words(
    words: list[dict],
    idioms: list[dict],
    topic: str,
) -> tuple[list[dict], list[dict]]:
    """
    Add 'german' and 'example_de' fields to every word and idiom in-place.
    Returns (words, idioms) with the new fields added.
    """
    all_items = words + idioms
    if not all_items:
        return words, idioms

    if LLM_PROVIDER not in _PROVIDERS:
        raise ValueError(f"Unknown LLM_PROVIDER '{LLM_PROVIDER}'. Choose: {list(_PROVIDERS)}")

    payload = [
        {
            "chinese": w["chinese"],
            "pinyin": w.get("pinyin", ""),
            "english": w.get("english", ""),
            "example_zh": w.get("example_zh", ""),
            "example_en": w.get("example_en", ""),
        }
        for w in all_items
    ]

    prompt = _PROMPT.format(topic=topic, words=json.dumps(payload, ensure_ascii=False, indent=2))
    raw = _PROVIDERS[LLM_PROVIDER](prompt)
    cleaned = _clean_json(raw)
    try:
        translated = json.loads(cleaned)
    except json.JSONDecodeError:
        translated = json.loads(repair_json(cleaned))

    for original, result in zip(all_items, translated):
        original["german"] = result.get("german", "")
        original["example_de"] = result.get("example_de", "")

    n = len(words)
    return all_items[:n], all_items[n:]

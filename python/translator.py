"""Translate word lists from Chinese/English to German using the configured LLM provider."""
import json

from json_repair import repair_json

from llm import call_llm, clean_json

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
    raw = call_llm(prompt, max_tokens=4096)
    cleaned = clean_json(raw)
    try:
        translated = json.loads(cleaned)
    except json.JSONDecodeError:
        translated = json.loads(repair_json(cleaned))

    for original, result in zip(all_items, translated):
        original["german"] = result.get("german", "")
        original["example_de"] = result.get("example_de", "")

    n = len(words)
    return all_items[:n], all_items[n:]

"""Generate a Pleco-compatible flashcard import file (.txt, UTF-8).

Pleco text import format (one card per line, 3 tab-separated fields):
    characters<TAB>pinyin<TAB>definition

Lines starting with // are category headers in Pleco.
"""
import re
from pathlib import Path


def _clean(s: str) -> str:
    """Remove JSON escape artifacts and normalize quotes."""
    s = s.replace('\\"', '"')
    s = s.replace('\u201e', '"').replace('\u201c', '"').replace('\u201d', '"')
    s = s.replace('\u2018', "'").replace('\u2019', "'")
    return s


def _card_line(w: dict) -> str:
    chinese = w.get("chinese", "")
    pinyin = w.get("pinyin", "")
    german = _clean(w.get("german") or w.get("english", ""))
    example_zh = _clean(w.get("example_zh", ""))
    example_de = _clean(w.get("example_de", ""))

    definition = german
    if example_zh:
        definition += f" | {example_zh}"
        if example_de:
            definition += f" {example_de}"

    return f"{chinese}\t{pinyin}\t{definition}"


def generate_pleco_file(episode: dict, output_path: Path) -> Path:
    """Write a .txt file that can be imported directly into Pleco as flashcards."""
    lines: list[str] = []

    ep_num = episode.get("episode", "?")
    title = episode.get("title", "")
    short_title = re.sub(r"^#\d+\[.*?\]:\s*", "", title)
    lines.append(f"// RTM #{ep_num}: {short_title}")
    lines.append("")

    all_words = episode.get("words", []) + episode.get("idioms", [])
    if all_words:
        for w in all_words:
            lines.append(_card_line(w))
        lines.append("")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path

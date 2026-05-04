"""Generate a Pleco-compatible flashcard import file (.txt, UTF-8).

Pleco text import format (one card per line, 3 tab-separated fields):
    characters<TAB>pinyin<TAB>definition

Lines starting with // are category headers in Pleco.
"""
import re
from pathlib import Path

from domain.models import Episode, VocabEntry


def _clean(s: str) -> str:
    """Remove JSON escape artifacts and normalize quotes."""
    s = s.replace('\\"', '"')
    s = s.replace('„', '"').replace('“', '"').replace('”', '"')
    s = s.replace('‘', "'").replace('’', "'")
    return s


def _card_line(w: VocabEntry) -> str:
    german = _clean(w.german or w.english)
    example_zh = _clean(w.example_zh)
    example_de = _clean(w.example_de)

    definition = german
    if example_zh:
        definition += f" | {example_zh}"
        if example_de:
            definition += f" {example_de}"

    return f"{w.chinese}\t{w.pinyin}\t{definition}"


def generate_pleco_file(episode: Episode, output_path: Path) -> Path:
    """Write a .txt file that can be imported directly into Pleco as flashcards."""
    lines: list[str] = []

    short_title = re.sub(r"^#\d+\[.*?\]:\s*", "", episode.title)
    lines.append(f"// RTM #{episode.episode}: {short_title}")
    lines.append("")

    all_words = episode.words + episode.idioms
    if all_words:
        for w in all_words:
            lines.append(_card_line(w))
        lines.append("")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path

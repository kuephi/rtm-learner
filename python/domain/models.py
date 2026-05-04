"""Core domain types for RTM Learner."""
from dataclasses import dataclass, field


@dataclass
class VocabEntry:
    type: str
    number: int
    chinese: str
    pinyin: str
    english: str
    german: str = ""
    example_zh: str = ""
    example_en: str = ""
    example_de: str = ""


@dataclass
class DialogueLine:
    speaker: str
    line: str


@dataclass
class GrammarPattern:
    pattern: str
    pinyin: str
    meaning_en: str
    examples_zh: list[str] = field(default_factory=list)


@dataclass
class Exercise:
    question: str
    options: list[str]
    answer_index: int
    answer_text: str


@dataclass
class Episode:
    episode: int
    title: str
    url: str
    pub_date: str
    text_simplified: str = ""
    text_traditional: str = ""
    words: list[VocabEntry] = field(default_factory=list)
    idioms: list[VocabEntry] = field(default_factory=list)
    dialogue: list[DialogueLine] = field(default_factory=list)
    grammar: list[GrammarPattern] = field(default_factory=list)
    exercises: list[Exercise] = field(default_factory=list)

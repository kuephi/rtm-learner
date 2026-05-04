"""Tests for translator.py — German translation via LLM provider dispatch."""
import json
from unittest.mock import patch

import pytest

from domain.models import VocabEntry
from translator import translate_words


def _make_entry(chinese: str, english: str = "test") -> VocabEntry:
    return VocabEntry(
        type="priority",
        number=1,
        chinese=chinese,
        pinyin="pīn yīn",
        english=english,
        example_zh="example",
        example_en="example",
    )


class TestTranslateWords:
    def test_returns_empty_lists_when_both_inputs_empty(self):
        words, idioms = translate_words([], [], topic="test")
        assert words == []
        assert idioms == []

    def test_does_not_call_llm_when_inputs_empty(self):
        with patch("translator.call_llm") as mock_llm:
            translate_words([], [], topic="test")
        mock_llm.assert_not_called()

    def test_adds_german_and_example_de_to_words(self):
        words = [_make_entry("测试")]
        response = [{"german": "Test", "example_de": "Das ist ein Test"}]
        with patch("translator.call_llm", return_value=json.dumps(response)):
            result_words, _ = translate_words(words, [], topic="testing")
        assert result_words[0].german == "Test"
        assert result_words[0].example_de == "Das ist ein Test"

    def test_does_not_mutate_input(self):
        words = [_make_entry("测试")]
        response = [{"german": "Test", "example_de": "Das ist ein Test"}]
        with patch("translator.call_llm", return_value=json.dumps(response)):
            translate_words(words, [], topic="testing")
        assert words[0].german == ""
        assert words[0].example_de == ""

    def test_separates_words_and_idioms_correctly(self):
        words = [_make_entry("测试", "test")]
        idioms = [_make_entry("无懈可击", "flawless")]
        response = [
            {"german": "Test", "example_de": ""},
            {"german": "einwandfrei", "example_de": ""},
        ]
        with patch("translator.call_llm", return_value=json.dumps(response)):
            result_words, result_idioms = translate_words(words, idioms, topic="test")
        assert result_words[0].german == "Test"
        assert result_idioms[0].german == "einwandfrei"

    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "unknown")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            translate_words([_make_entry("x")], [], topic="test")

    def test_sends_topic_in_prompt(self):
        words = [_make_entry("测试")]
        response = [{"german": "Test", "example_de": ""}]
        with patch("translator.call_llm", return_value=json.dumps(response)) as mock_llm:
            translate_words(words, [], topic="AI and Technology")
        assert "AI and Technology" in mock_llm.call_args[0][0]

    def test_missing_german_field_defaults_to_empty_string(self):
        words = [_make_entry("测试")]
        with patch("translator.call_llm", return_value=json.dumps([{}])):
            result_words, _ = translate_words(words, [], topic="test")
        assert result_words[0].german == ""
        assert result_words[0].example_de == ""

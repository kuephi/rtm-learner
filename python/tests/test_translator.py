"""Tests for translator.py — German translation via LLM provider dispatch."""
import json
from unittest.mock import MagicMock, patch

import pytest

from translator import _clean_json, translate_words


def _make_word(chinese: str, english: str = "test") -> dict:
    return {
        "chinese": chinese,
        "pinyin": "pīn yīn",
        "english": english,
        "example_zh": "example",
        "example_en": "example",
    }


def _mock_providers(provider: str, response: str):
    """Return a patch context that replaces _PROVIDERS with a single tracked mock."""
    mock_fn = MagicMock(return_value=response)
    providers = {provider: mock_fn}
    return patch("translator._PROVIDERS", providers), mock_fn


class TestCleanJson:
    def test_strips_json_code_fence(self):
        assert _clean_json("```json\n[]\n```") == "[]"

    def test_strips_plain_code_fence(self):
        assert _clean_json("```\n[]\n```") == "[]"

    def test_leaves_clean_json_unchanged(self):
        assert _clean_json("[1, 2]") == "[1, 2]"


class TestTranslateWords:
    def test_returns_empty_lists_when_both_inputs_empty(self):
        words, idioms = translate_words([], [], topic="test")
        assert words == []
        assert idioms == []

    def test_does_not_call_llm_when_inputs_empty(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "claude")
        ctx, mock_fn = _mock_providers("claude", "[]")
        with ctx:
            translate_words([], [], topic="test")
        mock_fn.assert_not_called()

    def test_adds_german_and_example_de_to_words(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "claude")
        words = [_make_word("测试")]
        response = [{"german": "Test", "example_de": "Das ist ein Test"}]
        ctx, _ = _mock_providers("claude", json.dumps(response))
        with ctx:
            result_words, _ = translate_words(words, [], topic="testing")
        assert result_words[0]["german"] == "Test"
        assert result_words[0]["example_de"] == "Das ist ein Test"

    def test_separates_words_and_idioms_correctly(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "claude")
        words = [_make_word("测试", "test")]
        idioms = [_make_word("无懈可击", "flawless")]
        response = [
            {"german": "Test", "example_de": ""},
            {"german": "einwandfrei", "example_de": ""},
        ]
        ctx, _ = _mock_providers("claude", json.dumps(response))
        with ctx:
            result_words, result_idioms = translate_words(words, idioms, topic="test")
        assert result_words[0]["german"] == "Test"
        assert result_idioms[0]["german"] == "einwandfrei"

    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "unknown")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            translate_words([_make_word("x")], [], topic="test")

    def test_sends_topic_in_prompt(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "claude")
        words = [_make_word("测试")]
        response = [{"german": "Test", "example_de": ""}]
        ctx, mock_fn = _mock_providers("claude", json.dumps(response))
        with ctx:
            translate_words(words, [], topic="AI and Technology")
        assert "AI and Technology" in mock_fn.call_args[0][0]

    def test_uses_gemini_provider(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "gemini")
        words = [_make_word("测试")]
        ctx, mock_fn = _mock_providers("gemini", json.dumps([{"german": "Test", "example_de": ""}]))
        with ctx:
            translate_words(words, [], topic="test")
        mock_fn.assert_called_once()

    def test_uses_openai_provider(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "openai")
        words = [_make_word("测试")]
        ctx, mock_fn = _mock_providers("openai", json.dumps([{"german": "Test", "example_de": ""}]))
        with ctx:
            translate_words(words, [], topic="test")
        mock_fn.assert_called_once()

    def test_missing_german_field_defaults_to_empty_string(self, monkeypatch):
        monkeypatch.setattr("translator.LLM_PROVIDER", "claude")
        words = [_make_word("测试")]
        ctx, _ = _mock_providers("claude", json.dumps([{}]))  # LLM returned item without german/example_de
        with ctx:
            result_words, _ = translate_words(words, [], topic="test")
        assert result_words[0]["german"] == ""
        assert result_words[0]["example_de"] == ""

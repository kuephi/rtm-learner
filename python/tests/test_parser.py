"""Tests for parser.py — JSON cleaning, LLM dispatch, episode extraction."""
import json
from unittest.mock import MagicMock, patch

import pytest

from parser import _clean_json, extract_episode


_SAMPLE_EPISODE = {
    "text_simplified": "文章内容",
    "text_traditional": "文章內容",
    "words": [
        {
            "type": "priority",
            "number": 1,
            "chinese": "测试",
            "pinyin": "cè shì",
            "english": "test",
            "example_zh": "这是一个测试",
            "example_en": "This is a test",
        }
    ],
    "idioms": [],
    "dialogue": [],
    "grammar": [],
    "exercises": [],
}


def _mock_providers(provider: str, response: str):
    """Return a patch context that replaces _PROVIDERS with a single tracked mock."""
    mock_fn = MagicMock(return_value=response)
    providers = {provider: mock_fn}
    return patch("parser._PROVIDERS", providers), mock_fn


class TestCleanJson:
    def test_strips_json_code_fence(self):
        assert _clean_json("```json\n{}\n```") == "{}"

    def test_strips_plain_code_fence(self):
        assert _clean_json("```\n{}\n```") == "{}"

    def test_leaves_clean_json_unchanged(self):
        assert _clean_json('{"key": "value"}') == '{"key": "value"}'

    def test_strips_leading_trailing_whitespace(self):
        assert _clean_json("  {}  ") == "{}"


class TestExtractEpisode:
    _META = {"episode": 265, "title": "Test", "url": "http://example.com", "pub_date": "2024-01-01"}

    def test_calls_configured_provider(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "claude")
        ctx, mock_fn = _mock_providers("claude", json.dumps(_SAMPLE_EPISODE))
        with ctx:
            extract_episode("lesson text", self._META)
        mock_fn.assert_called_once()
        assert "lesson text" in mock_fn.call_args[0][0]

    def test_merges_meta_into_result(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "claude")
        ctx, _ = _mock_providers("claude", json.dumps(_SAMPLE_EPISODE))
        with ctx:
            result = extract_episode("text", self._META)
        assert result["episode"] == 265
        assert result["title"] == "Test"
        assert result["url"] == "http://example.com"

    def test_returns_parsed_words(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "claude")
        ctx, _ = _mock_providers("claude", json.dumps(_SAMPLE_EPISODE))
        with ctx:
            result = extract_episode("text", self._META)
        assert result["words"][0]["chinese"] == "测试"

    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "unknown")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            extract_episode("text", {})

    def test_repairs_malformed_json(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "claude")
        malformed = json.dumps(_SAMPLE_EPISODE)[:-1]  # truncate closing brace
        ctx, _ = _mock_providers("claude", malformed)
        with ctx:
            result = extract_episode("text", {"episode": 1})
        assert "words" in result

    def test_strips_code_fence_from_llm_response(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "claude")
        wrapped = f"```json\n{json.dumps(_SAMPLE_EPISODE)}\n```"
        ctx, _ = _mock_providers("claude", wrapped)
        with ctx:
            result = extract_episode("text", self._META)
        assert result["episode"] == 265

    def test_uses_gemini_provider(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "gemini")
        ctx, mock_fn = _mock_providers("gemini", json.dumps(_SAMPLE_EPISODE))
        with ctx:
            extract_episode("text", self._META)
        mock_fn.assert_called_once()

    def test_uses_openai_provider(self, monkeypatch):
        monkeypatch.setattr("parser.LLM_PROVIDER", "openai")
        ctx, mock_fn = _mock_providers("openai", json.dumps(_SAMPLE_EPISODE))
        with ctx:
            extract_episode("text", self._META)
        mock_fn.assert_called_once()

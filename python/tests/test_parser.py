"""Tests for parser.py — JSON cleaning, LLM dispatch, episode extraction."""
import json
from unittest.mock import patch

import pytest

from parser import extract_episode

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

_META = {"episode": 265, "title": "Test", "url": "http://example.com", "pub_date": "2024-01-01"}


class TestExtractEpisode:
    def test_calls_llm_with_lesson_text(self):
        with patch("parser.call_llm", return_value=json.dumps(_SAMPLE_EPISODE)) as mock_llm:
            extract_episode("lesson text", _META)
        mock_llm.assert_called_once()
        assert "lesson text" in mock_llm.call_args[0][0]

    def test_merges_meta_into_result(self):
        with patch("parser.call_llm", return_value=json.dumps(_SAMPLE_EPISODE)):
            result = extract_episode("text", _META)
        assert result.episode == 265
        assert result.title == "Test"
        assert result.url == "http://example.com"

    def test_returns_parsed_words(self):
        with patch("parser.call_llm", return_value=json.dumps(_SAMPLE_EPISODE)):
            result = extract_episode("text", _META)
        assert result.words[0].chinese == "测试"

    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "unknown")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            extract_episode("text", {})

    def test_repairs_malformed_json(self):
        malformed = json.dumps(_SAMPLE_EPISODE)[:-1]  # truncate closing brace
        with patch("parser.call_llm", return_value=malformed):
            result = extract_episode("text", {"episode": 1})
        assert result.words is not None

    def test_strips_code_fence_from_llm_response(self):
        wrapped = f"```json\n{json.dumps(_SAMPLE_EPISODE)}\n```"
        with patch("parser.call_llm", return_value=wrapped):
            result = extract_episode("text", _META)
        assert result.episode == 265

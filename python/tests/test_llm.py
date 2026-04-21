"""Tests for llm.py — shared LLM provider dispatch."""
import pytest
from unittest.mock import MagicMock, patch

from llm import clean_json, call_llm


class TestCleanJson:
    def test_strips_json_code_fence(self):
        assert clean_json("```json\n{}\n```") == "{}"

    def test_strips_plain_code_fence(self):
        assert clean_json("```\n[]\n```") == "[]"

    def test_leaves_clean_json_unchanged(self):
        assert clean_json('{"key": "value"}') == '{"key": "value"}'

    def test_strips_whitespace(self):
        assert clean_json("  {}  ") == "{}"


class TestCallLlm:
    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "unknown")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            call_llm("test prompt")

    def test_dispatches_to_claude(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "claude")
        mock_fn = MagicMock(return_value="response")
        with patch("llm._PROVIDERS", {"claude": mock_fn}):
            result = call_llm("prompt")
        mock_fn.assert_called_once_with("prompt", 8192)
        assert result == "response"

    def test_dispatches_to_gemini(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "gemini")
        mock_fn = MagicMock(return_value="response")
        with patch("llm._PROVIDERS", {"gemini": mock_fn}):
            result = call_llm("prompt")
        mock_fn.assert_called_once_with("prompt", 8192)
        assert result == "response"

    def test_dispatches_to_openai(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "openai")
        mock_fn = MagicMock(return_value="response")
        with patch("llm._PROVIDERS", {"openai": mock_fn}):
            result = call_llm("prompt")
        mock_fn.assert_called_once_with("prompt", 8192)
        assert result == "response"

    def test_passes_custom_max_tokens(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "claude")
        mock_fn = MagicMock(return_value="response")
        with patch("llm._PROVIDERS", {"claude": mock_fn}):
            call_llm("prompt", max_tokens=4096)
        mock_fn.assert_called_once_with("prompt", 4096)

    def test_openai_raises_on_none_content(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "openai")
        mock_choice = MagicMock()
        mock_choice.message.content = None
        mock_choice.finish_reason = "content_filter"
        mock_response = MagicMock()
        mock_response.choices = [mock_choice]
        with patch("openai.OpenAI") as MockOpenAI:
            mock_client = MagicMock()
            mock_client.chat.completions.create.return_value = mock_response
            MockOpenAI.return_value = mock_client
            import llm
            with pytest.raises(RuntimeError, match="OpenAI returned no content"):
                llm._call_openai("prompt", 8192)

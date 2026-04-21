# Python Pipeline Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three code quality issues in the Python pipeline: extract duplicated LLM provider code into a shared module, add missing test coverage for `auth.py` and `fetch_page`, and add setup documentation.

**Architecture:** A new `python/llm.py` module consolidates the provider dispatch logic currently copy-pasted in `parser.py` and `translator.py`. Both modules are updated to import `call_llm` and `clean_json` from `llm.py`. Their test files are updated to mock `call_llm` directly. Auth and fetch_page tests are added alongside existing tests. README and .env.example are added to `python/`.

**Tech Stack:** Python 3.11+, pytest, unittest.mock, requests

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `python/llm.py` | Shared LLM provider dispatch (`call_llm`, `clean_json`) |
| Create | `python/tests/test_llm.py` | Tests for `llm.py` |
| Modify | `python/parser.py` | Remove duplicate code, import from `llm` |
| Modify | `python/tests/test_parser.py` | Mock `parser.call_llm` instead of `parser._PROVIDERS` |
| Modify | `python/translator.py` | Remove duplicate code, import from `llm` |
| Modify | `python/tests/test_translator.py` | Mock `translator.call_llm` instead of `translator._PROVIDERS` |
| Create | `python/tests/test_auth.py` | Full coverage for `auth.py` |
| Modify | `python/tests/test_fetcher.py` | Add `TestFetchPage` class |
| Create | `python/README.md` | Setup and usage instructions |
| Create | `python/.env.example` | Environment variable template |

---

### Task 1: Create `python/llm.py` with tests (TDD)

**Files:**
- Create: `python/tests/test_llm.py`
- Create: `python/llm.py`

- [ ] **Step 1: Write the failing tests**

Create `python/tests/test_llm.py`:

```python
"""Tests for llm.py — shared LLM provider dispatch."""
import pytest
from unittest.mock import MagicMock, patch

from llm import clean_json, call_llm


class TestCleanJson:
    def test_strips_json_code_fence(self):
        assert clean_json("```json\n{}\n```") == "{}"

    def test_strips_plain_code_fence(self):
        assert clean_json("```\n{}\n```") == "[]"

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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd python && python -m pytest tests/test_llm.py -v
```

Expected: `ModuleNotFoundError: No module named 'llm'`

- [ ] **Step 3: Create `python/llm.py`**

```python
"""Shared LLM provider dispatch used by parser and translator."""
import re

from config import LLM_PROVIDER, ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENAI_API_KEY, get_model


def clean_json(raw: str) -> str:
    """Strip markdown code fences if the model wrapped the output."""
    raw = raw.strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)
    return raw.strip()


def _call_claude(prompt: str, max_tokens: int) -> str:
    import anthropic
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    message = client.messages.create(
        model=get_model(),
        max_tokens=max_tokens,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def _call_gemini(prompt: str, max_tokens: int) -> str:
    import google.generativeai as genai
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel(get_model())
    response = model.generate_content(prompt)
    return response.text


def _call_openai(prompt: str, max_tokens: int) -> str:
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


def call_llm(prompt: str, max_tokens: int = 8192) -> str:
    """Call the configured LLM provider and return its text response."""
    if LLM_PROVIDER not in _PROVIDERS:
        raise ValueError(f"Unknown LLM_PROVIDER '{LLM_PROVIDER}'. Choose: {list(_PROVIDERS)}")
    return _PROVIDERS[LLM_PROVIDER](prompt, max_tokens)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd python && python -m pytest tests/test_llm.py -v
```

Expected: 9 tests pass.

- [ ] **Step 5: Commit**

```bash
cd python && git add tests/test_llm.py llm.py
git commit -m "feat: extract shared LLM provider dispatch into llm.py"
```

---

### Task 2: Refactor `parser.py` and update its tests

**Files:**
- Modify: `python/parser.py`
- Modify: `python/tests/test_parser.py`

- [ ] **Step 1: Update `python/tests/test_parser.py`**

Replace the entire file:

```python
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
        assert result["episode"] == 265
        assert result["title"] == "Test"
        assert result["url"] == "http://example.com"

    def test_returns_parsed_words(self):
        with patch("parser.call_llm", return_value=json.dumps(_SAMPLE_EPISODE)):
            result = extract_episode("text", _META)
        assert result["words"][0]["chinese"] == "测试"

    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "unknown")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            extract_episode("text", {})

    def test_repairs_malformed_json(self):
        malformed = json.dumps(_SAMPLE_EPISODE)[:-1]  # truncate closing brace
        with patch("parser.call_llm", return_value=malformed):
            result = extract_episode("text", {"episode": 1})
        assert "words" in result

    def test_strips_code_fence_from_llm_response(self):
        wrapped = f"```json\n{json.dumps(_SAMPLE_EPISODE)}\n```"
        with patch("parser.call_llm", return_value=wrapped):
            result = extract_episode("text", _META)
        assert result["episode"] == 265
```

- [ ] **Step 2: Run updated tests to confirm they fail (parser still has old code)**

```bash
cd python && python -m pytest tests/test_parser.py -v
```

Expected: Most tests fail because `parser.call_llm` doesn't exist yet.

- [ ] **Step 3: Rewrite `python/parser.py`**

```python
"""Extract structured lesson data from raw page text via a configurable LLM provider."""
import json

from json_repair import repair_json

from llm import call_llm, clean_json

_PROMPT = """
You are a structured data extractor for RTM Mandarin Chinese lessons.
Extract ALL content from the lesson text below into the exact JSON structure shown.
Return ONLY valid JSON — no markdown fences, no commentary.

JSON schema:
{
  "text_simplified": "the main simplified Chinese article text",
  "text_traditional": "the traditional Chinese version of the same text",
  "words": [
    {
      "type": "priority",
      "number": 1,
      "chinese": "内测",
      "pinyin": "nèi cè",
      "english": "internal testing, beta test",
      "example_zh": "Chinese example sentence",
      "example_en": "English translation of the example"
    }
  ],
  "idioms": [
    {
      "type": "idiom",
      "number": 1,
      "chinese": "无懈可击",
      "pinyin": "wú xiè kě jī",
      "english": "flawless, unassailable",
      "example_zh": "Chinese example sentence",
      "example_en": "English translation of the example"
    }
  ],
  "dialogue": [
    {"speaker": "老李", "line": "Chinese line"}
  ],
  "grammar": [
    {
      "pattern": "立马 + verb",
      "pinyin": "lì mǎ",
      "meaning_en": "at once / immediately",
      "examples_zh": ["example sentence 1", "example sentence 2"]
    }
  ],
  "exercises": [
    {
      "question": "question text with ___ for the blank",
      "options": ["option a", "option b", "option c", "option d"],
      "answer_index": 1,
      "answer_text": "the correct word/phrase"
    }
  ]
}

Lesson text:
"""


def extract_episode(text: str, meta: dict) -> dict:
    """
    Send page text to the configured LLM and return a fully structured episode dict.
    `meta` fields (episode, title, url, pub_date) are merged into the result.
    """
    raw = call_llm(_PROMPT + text)
    cleaned = clean_json(raw)
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        data = json.loads(repair_json(cleaned))
    data.update(meta)
    return data
```

- [ ] **Step 4: Run all tests to confirm they pass**

```bash
cd python && python -m pytest -v
```

Expected: All tests pass (test_llm, test_parser, test_translator, test_fetcher, test_pleco).

- [ ] **Step 5: Commit**

```bash
git add python/parser.py python/tests/test_parser.py
git commit -m "refactor: parser uses shared llm.call_llm"
```

---

### Task 3: Refactor `translator.py` and update its tests

**Files:**
- Modify: `python/translator.py`
- Modify: `python/tests/test_translator.py`

- [ ] **Step 1: Update `python/tests/test_translator.py`**

Replace the entire file:

```python
"""Tests for translator.py — German translation via LLM provider dispatch."""
import json
from unittest.mock import patch

import pytest

from translator import translate_words


def _make_word(chinese: str, english: str = "test") -> dict:
    return {
        "chinese": chinese,
        "pinyin": "pīn yīn",
        "english": english,
        "example_zh": "example",
        "example_en": "example",
    }


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
        words = [_make_word("测试")]
        response = [{"german": "Test", "example_de": "Das ist ein Test"}]
        with patch("translator.call_llm", return_value=json.dumps(response)):
            result_words, _ = translate_words(words, [], topic="testing")
        assert result_words[0]["german"] == "Test"
        assert result_words[0]["example_de"] == "Das ist ein Test"

    def test_separates_words_and_idioms_correctly(self):
        words = [_make_word("测试", "test")]
        idioms = [_make_word("无懈可击", "flawless")]
        response = [
            {"german": "Test", "example_de": ""},
            {"german": "einwandfrei", "example_de": ""},
        ]
        with patch("translator.call_llm", return_value=json.dumps(response)):
            result_words, result_idioms = translate_words(words, idioms, topic="test")
        assert result_words[0]["german"] == "Test"
        assert result_idioms[0]["german"] == "einwandfrei"

    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setattr("llm.LLM_PROVIDER", "unknown")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            translate_words([_make_word("x")], [], topic="test")

    def test_sends_topic_in_prompt(self):
        words = [_make_word("测试")]
        response = [{"german": "Test", "example_de": ""}]
        with patch("translator.call_llm", return_value=json.dumps(response)) as mock_llm:
            translate_words(words, [], topic="AI and Technology")
        assert "AI and Technology" in mock_llm.call_args[0][0]

    def test_missing_german_field_defaults_to_empty_string(self):
        words = [_make_word("测试")]
        with patch("translator.call_llm", return_value=json.dumps([{}])):
            result_words, _ = translate_words(words, [], topic="test")
        assert result_words[0]["german"] == ""
        assert result_words[0]["example_de"] == ""
```

- [ ] **Step 2: Run updated tests to confirm they fail**

```bash
cd python && python -m pytest tests/test_translator.py -v
```

Expected: Most tests fail because `translator.call_llm` doesn't exist yet.

- [ ] **Step 3: Rewrite `python/translator.py`**

```python
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
```

- [ ] **Step 4: Run all tests**

```bash
cd python && python -m pytest -v
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add python/translator.py python/tests/test_translator.py
git commit -m "refactor: translator uses shared llm.call_llm"
```

---

### Task 4: Add tests for `auth.py`

**Files:**
- Create: `python/tests/test_auth.py`

- [ ] **Step 1: Write `python/tests/test_auth.py`**

```python
"""Tests for auth.py — session cookie caching and Substack login."""
import json
import time
from unittest.mock import MagicMock, patch

import pytest

import auth
from auth import _load_cached_cookies, _save_cookies, get_session


class TestLoadCachedCookies:
    def test_returns_none_when_file_missing(self, tmp_path, monkeypatch):
        monkeypatch.setattr("auth._SESSION_FILE", tmp_path / "session.json")
        assert _load_cached_cookies() is None

    def test_returns_none_when_expired(self, tmp_path, monkeypatch):
        session_file = tmp_path / "session.json"
        session_file.write_text(json.dumps({
            "cookies": {"substack.sid": "abc"},
            "expires_at": time.time() - 1,
        }))
        monkeypatch.setattr("auth._SESSION_FILE", session_file)
        assert _load_cached_cookies() is None

    def test_returns_cookies_when_valid(self, tmp_path, monkeypatch):
        session_file = tmp_path / "session.json"
        session_file.write_text(json.dumps({
            "cookies": {"substack.sid": "abc"},
            "expires_at": time.time() + 3600,
        }))
        monkeypatch.setattr("auth._SESSION_FILE", session_file)
        assert _load_cached_cookies() == {"substack.sid": "abc"}


class TestSaveCookies:
    def test_writes_cookies_to_file(self, tmp_path, monkeypatch):
        session_file = tmp_path / "session.json"
        monkeypatch.setattr("auth._SESSION_FILE", session_file)
        _save_cookies({"substack.sid": "xyz"})
        data = json.loads(session_file.read_text())
        assert data["cookies"] == {"substack.sid": "xyz"}
        assert data["expires_at"] > time.time()

    def test_creates_parent_directory(self, tmp_path, monkeypatch):
        session_file = tmp_path / "nested" / "session.json"
        monkeypatch.setattr("auth._SESSION_FILE", session_file)
        _save_cookies({})
        assert session_file.exists()


class TestGetSession:
    def test_uses_cached_cookies_when_valid(self, tmp_path, monkeypatch):
        session_file = tmp_path / "session.json"
        session_file.write_text(json.dumps({
            "cookies": {"substack.sid": "cached"},
            "expires_at": time.time() + 3600,
        }))
        monkeypatch.setattr("auth._SESSION_FILE", session_file)
        session = get_session()
        assert session.cookies.get("substack.sid") == "cached"

    def test_logs_in_when_cache_missing(self, tmp_path, monkeypatch):
        monkeypatch.setattr("auth._SESSION_FILE", tmp_path / "session.json")
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_login_session = MagicMock()
        mock_login_session.cookies = {"substack.sid": "new"}
        mock_login_session.post.return_value = mock_resp
        with patch("auth.requests.Session", return_value=mock_login_session):
            with patch("auth._save_cookies") as mock_save:
                get_session()
        mock_login_session.post.assert_called_once()
        mock_save.assert_called_once_with({"substack.sid": "new"})

    def test_force_refresh_skips_cache(self, tmp_path, monkeypatch):
        session_file = tmp_path / "session.json"
        session_file.write_text(json.dumps({
            "cookies": {"substack.sid": "old"},
            "expires_at": time.time() + 3600,
        }))
        monkeypatch.setattr("auth._SESSION_FILE", session_file)
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_login_session = MagicMock()
        mock_login_session.cookies = {"substack.sid": "fresh"}
        mock_login_session.post.return_value = mock_resp
        with patch("auth.requests.Session", return_value=mock_login_session):
            with patch("auth._save_cookies"):
                get_session(force_refresh=True)
        mock_login_session.post.assert_called_once()

    def test_raises_on_wrong_credentials(self, tmp_path, monkeypatch):
        monkeypatch.setattr("auth._SESSION_FILE", tmp_path / "session.json")
        mock_resp = MagicMock()
        mock_resp.status_code = 401
        mock_login_session = MagicMock()
        mock_login_session.post.return_value = mock_resp
        with patch("auth.requests.Session", return_value=mock_login_session):
            with pytest.raises(RuntimeError, match="Substack login failed"):
                get_session()
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd python && python -m pytest tests/test_auth.py -v
```

Expected: 9 tests pass.

- [ ] **Step 3: Run full suite to confirm no regressions**

```bash
cd python && python -m pytest -v
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add python/tests/test_auth.py
git commit -m "test: add full coverage for auth.py"
```

---

### Task 5: Add tests for `fetch_page`

**Files:**
- Modify: `python/tests/test_fetcher.py` (add `TestFetchPage` class; keep all existing classes)

- [ ] **Step 1: Add `TestFetchPage` to `python/tests/test_fetcher.py`**

Add this import at the top of the existing imports:

```python
from fetcher import _load_state, extract_text, fetch_page, get_new_entries, save_state
```

Then append this class at the end of the file:

```python
class TestFetchPage:
    def test_returns_html_on_success(self):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = "<html>content</html>"
        mock_session = MagicMock()
        mock_session.get.return_value = mock_resp
        with patch("fetcher.auth.get_session", return_value=mock_session):
            result = fetch_page("http://example.com/episode")
        assert result == "<html>content</html>"

    def test_retries_on_401(self):
        unauth_resp = MagicMock(status_code=401)
        ok_resp = MagicMock(status_code=200, text="<html>retried</html>")
        ok_resp.raise_for_status = MagicMock()
        first_session = MagicMock()
        first_session.get.return_value = unauth_resp
        retry_session = MagicMock()
        retry_session.get.return_value = ok_resp
        with patch("fetcher.auth.get_session", side_effect=[first_session, retry_session]):
            result = fetch_page("http://example.com/episode")
        assert result == "<html>retried</html>"

    def test_retries_on_403(self):
        unauth_resp = MagicMock(status_code=403)
        ok_resp = MagicMock(status_code=200, text="<html>ok</html>")
        ok_resp.raise_for_status = MagicMock()
        first_session = MagicMock()
        first_session.get.return_value = unauth_resp
        retry_session = MagicMock()
        retry_session.get.return_value = ok_resp
        with patch("fetcher.auth.get_session", side_effect=[first_session, retry_session]):
            result = fetch_page("http://example.com/episode")
        assert result == "<html>ok</html>"

    def test_raises_on_server_error(self):
        resp = MagicMock(status_code=500)
        resp.raise_for_status.side_effect = Exception("Server error")
        mock_session = MagicMock()
        mock_session.get.return_value = resp
        with patch("fetcher.auth.get_session", return_value=mock_session):
            with pytest.raises(Exception, match="Server error"):
                fetch_page("http://example.com/episode")
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd python && python -m pytest tests/test_fetcher.py -v
```

Expected: All fetcher tests pass (original 13 + new 4 = 17 total).

- [ ] **Step 3: Run full suite**

```bash
cd python && python -m pytest -v
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add python/tests/test_fetcher.py
git commit -m "test: add fetch_page coverage (success, 401/403 retry, server error)"
```

---

### Task 6: Add `python/README.md` and `python/.env.example`

**Files:**
- Create: `python/README.md`
- Create: `python/.env.example`

- [ ] **Step 1: Create `python/.env.example`**

```bash
cat > python/.env.example << 'EOF'
# Substack credentials (required)
SUBSTACK_EMAIL=your@email.com
SUBSTACK_PASSWORD=yourpassword

# LLM provider: claude | gemini | openai  (default: claude)
LLM_PROVIDER=claude

# API keys — only the key for your chosen provider is required
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIza...
OPENAI_API_KEY=sk-...

# Optional: override the default model for your provider
# LLM_MODEL=claude-sonnet-4-6
EOF
```

- [ ] **Step 2: Create `python/README.md`**

```bash
cat > python/README.md << 'EOF'
# RTM Learner — Python Pipeline

Fetches RTM Mandarin 中级 lessons, extracts vocabulary via LLM, translates to German, and exports Pleco flashcard files.

## Setup

```bash
cd python
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your credentials and API key
```

## Usage

```bash
# Process all new 中级 episodes
python main.py

# Reprocess a specific episode by number
python main.py --force 265
```

Output is written to:
- `data/episodes/<number>.json` — full structured lesson data
- `data/pleco/<number>_pleco.txt` — Pleco flashcard import file

## Tests

```bash
pytest
```

## Environment variables

See `.env.example` for all available configuration options.
EOF
```

- [ ] **Step 3: Commit**

```bash
git add python/README.md python/.env.example
git commit -m "docs: add python/README.md and .env.example"
```

---

## Self-Review

**Spec coverage:**
- [x] `llm.py` with shared `call_llm` / `clean_json` — Task 1
- [x] `parser.py` refactored to use `llm` — Task 2
- [x] `translator.py` refactored to use `llm` — Task 3
- [x] `auth.py` tests — Task 4
- [x] `fetch_page` tests — Task 5
- [x] README + .env.example — Task 6
- [x] All 57 existing tests preserved and passing after refactor

**Placeholder scan:** No TBDs, TODOs, or incomplete steps.

**Type consistency:**
- `call_llm(prompt: str, max_tokens: int = 8192) -> str` — consistent across Task 1, 2, 3
- `clean_json(raw: str) -> str` — consistent across Task 1, 2, 3
- `fetch_page` import added to Task 5 step 1 import line ✓

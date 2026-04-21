"""Tests for fetcher.py — HTML extraction, state management, RSS feed filtering."""
import json
from unittest.mock import MagicMock, patch

import pytest

from fetcher import _load_state, extract_text, get_new_entries, save_state


class TestExtractText:
    def test_extracts_from_available_content_div(self):
        html = """
        <html><body>
          <div class="available-content"><p>Lesson content</p></div>
          <script>remove me</script>
        </body></html>
        """
        result = extract_text(html)
        assert "Lesson content" in result
        assert "remove me" not in result

    def test_extracts_from_post_content_div(self):
        html = "<html><body><div class='post-content'><p>Post body</p></div></body></html>"
        assert "Post body" in extract_text(html)

    def test_falls_back_to_article(self):
        html = "<html><body><article><p>Article text</p></article></body></html>"
        assert "Article text" in extract_text(html)

    def test_falls_back_to_main(self):
        html = "<html><body><main><p>Main content</p></main></body></html>"
        assert "Main content" in extract_text(html)

    def test_strips_script_tags(self):
        html = "<html><body><main><p>Keep</p><script>drop</script></main></body></html>"
        result = extract_text(html)
        assert "Keep" in result
        assert "drop" not in result

    def test_strips_nav_footer_header(self):
        html = """
        <html><body>
          <nav>Navigation</nav>
          <main><p>Content</p></main>
          <footer>Footer</footer>
        </body></html>
        """
        result = extract_text(html)
        assert "Content" in result
        assert "Navigation" not in result
        assert "Footer" not in result

    def test_prefers_available_content_over_article(self):
        html = """
        <html><body>
          <div class="available-content"><p>Primary</p></div>
          <article><p>Fallback</p></article>
        </body></html>
        """
        result = extract_text(html)
        assert "Primary" in result


class TestLoadState:
    def test_returns_default_when_file_missing(self, tmp_path, monkeypatch):
        monkeypatch.setattr("fetcher.STATE_FILE", tmp_path / "state.json")
        assert _load_state() == {"processed_urls": []}

    def test_reads_existing_state(self, tmp_path, monkeypatch):
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"processed_urls": ["http://example.com"]}))
        monkeypatch.setattr("fetcher.STATE_FILE", state_file)
        assert _load_state() == {"processed_urls": ["http://example.com"]}


class TestSaveState:
    def test_writes_json(self, tmp_path, monkeypatch):
        state_file = tmp_path / "state.json"
        monkeypatch.setattr("fetcher.STATE_FILE", state_file)
        save_state({"processed_urls": ["http://example.com"]})
        assert json.loads(state_file.read_text()) == {"processed_urls": ["http://example.com"]}

    def test_creates_parent_dirs(self, tmp_path, monkeypatch):
        state_file = tmp_path / "nested" / "state.json"
        monkeypatch.setattr("fetcher.STATE_FILE", state_file)
        save_state({"processed_urls": []})
        assert state_file.exists()


class TestGetNewEntries:
    def _mock_feed(self, entries):
        mock = MagicMock()
        mock.entries = [
            {"title": t, "link": u, "published": "2024-01-01"}
            for t, u in entries
        ]
        return mock

    def test_filters_by_level(self, tmp_path, monkeypatch):
        monkeypatch.setattr("fetcher.STATE_FILE", tmp_path / "state.json")
        feed = self._mock_feed([
            ("#265[中级]: Topic", "http://rtm.com/265"),
            ("#100[初级]: Topic", "http://rtm.com/100"),
        ])
        with patch("fetcher.feedparser.parse", return_value=feed):
            entries, _ = get_new_entries()
        assert len(entries) == 1
        assert entries[0]["episode"] == 265

    def test_skips_processed_urls(self, tmp_path, monkeypatch):
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"processed_urls": ["http://rtm.com/265"]}))
        monkeypatch.setattr("fetcher.STATE_FILE", state_file)
        feed = self._mock_feed([("#265[中级]: Topic", "http://rtm.com/265")])
        with patch("fetcher.feedparser.parse", return_value=feed):
            entries, _ = get_new_entries()
        assert entries == []

    def test_returns_entries_sorted_oldest_first(self, tmp_path, monkeypatch):
        monkeypatch.setattr("fetcher.STATE_FILE", tmp_path / "state.json")
        feed = self._mock_feed([
            ("#270[中级]: C", "http://rtm.com/270"),
            ("#265[中级]: A", "http://rtm.com/265"),
            ("#268[中级]: B", "http://rtm.com/268"),
        ])
        with patch("fetcher.feedparser.parse", return_value=feed):
            entries, _ = get_new_entries()
        assert [e["episode"] for e in entries] == [265, 268, 270]

    def test_returns_state_alongside_entries(self, tmp_path, monkeypatch):
        monkeypatch.setattr("fetcher.STATE_FILE", tmp_path / "state.json")
        with patch("fetcher.feedparser.parse", return_value=self._mock_feed([])):
            entries, state = get_new_entries()
        assert "processed_urls" in state

    def test_entry_has_required_fields(self, tmp_path, monkeypatch):
        monkeypatch.setattr("fetcher.STATE_FILE", tmp_path / "state.json")
        feed = self._mock_feed([("#265[中级]: My Topic", "http://rtm.com/265")])
        with patch("fetcher.feedparser.parse", return_value=feed):
            entries, _ = get_new_entries()
        entry = entries[0]
        assert entry["episode"] == 265
        assert entry["title"] == "#265[中级]: My Topic"
        assert entry["url"] == "http://rtm.com/265"
        assert "pub_date" in entry

    def test_episode_number_defaults_to_zero_when_missing(self, tmp_path, monkeypatch):
        monkeypatch.setattr("fetcher.STATE_FILE", tmp_path / "state.json")
        feed = self._mock_feed([("[中级]: No number", "http://rtm.com/x")])
        with patch("fetcher.feedparser.parse", return_value=feed):
            entries, _ = get_new_entries()
        assert entries[0]["episode"] == 0

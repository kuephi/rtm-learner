"""Tests for auth.py — session cookie caching and Substack login."""
import json
import time
from unittest.mock import MagicMock, patch

import pytest

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
        # Second call to requests.Session() builds the returned session
        mock_return_session = MagicMock()
        mock_return_session.cookies = MagicMock()
        with patch("auth.requests.Session", side_effect=[mock_login_session, mock_return_session]):
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
        mock_return_session = MagicMock()
        mock_return_session.cookies = MagicMock()
        with patch("auth.requests.Session", side_effect=[mock_login_session, mock_return_session]):
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

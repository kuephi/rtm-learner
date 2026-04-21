"""Substack authentication — auto-login and session cookie caching.

The session is cached in data/session.json and reused for ~29 days.
Re-login is triggered automatically when the cache expires or on HTTP 401/403.
"""
import json
import time

import requests

from config import SUBSTACK_EMAIL, SUBSTACK_PASSWORD, DATA_DIR

_SESSION_FILE = DATA_DIR / "session.json"
_SESSION_TTL = 29 * 24 * 3600  # 29 days in seconds
_LOGIN_URL = "https://substack.com/api/v1/login"
_LOGIN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
    "Content-Type": "application/json",
    "Origin": "https://substack.com",
}


def _load_cached_cookies() -> dict | None:
    """Return cached cookies if they exist and haven't expired."""
    if not _SESSION_FILE.exists():
        return None
    data = json.loads(_SESSION_FILE.read_text(encoding="utf-8"))
    if data.get("expires_at", 0) > time.time():
        return data["cookies"]
    return None


def _save_cookies(cookies: dict) -> None:
    _SESSION_FILE.parent.mkdir(parents=True, exist_ok=True)
    _SESSION_FILE.write_text(
        json.dumps({"cookies": cookies, "expires_at": time.time() + _SESSION_TTL}, indent=2),
        encoding="utf-8",
    )


def _login() -> dict:
    """Perform a fresh login and return the resulting cookies."""
    print("  Logging into Substack...")
    session = requests.Session()
    resp = session.post(
        _LOGIN_URL,
        json={"email": SUBSTACK_EMAIL, "password": SUBSTACK_PASSWORD, "captcha_response": None},
        headers=_LOGIN_HEADERS,
        timeout=30,
    )
    if resp.status_code == 401:
        raise RuntimeError("Substack login failed: wrong email or password.")
    resp.raise_for_status()
    cookies = dict(session.cookies)
    _save_cookies(cookies)
    print("  Login successful — session cached.")
    return cookies


def get_session(force_refresh: bool = False) -> requests.Session:
    """
    Return an authenticated requests.Session.
    Uses cached cookies if still valid; otherwise logs in again.
    """
    if not force_refresh:
        cookies = _load_cached_cookies()
    else:
        cookies = None

    if cookies is None:
        cookies = _login()

    session = requests.Session()
    session.cookies.update(cookies)
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "en-US,en;q=0.9",
    })
    return session

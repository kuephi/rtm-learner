"""Fetch new 中级 episodes from the RTM RSS feed and download page content."""
import json
import re
from pathlib import Path

import feedparser
from bs4 import BeautifulSoup

import auth
from config import RTM_FEED_URL, LEVEL_FILTER, STATE_FILE


# ---------------------------------------------------------------------------
# State helpers (tracks which episodes have already been processed)
# ---------------------------------------------------------------------------

def _load_state() -> dict:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    return {"processed_urls": []}


def save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


# ---------------------------------------------------------------------------
# RSS feed
# ---------------------------------------------------------------------------

def get_new_entries() -> tuple[list[dict], dict]:
    """Return (new_entries, state). new_entries are sorted oldest-first."""
    state = _load_state()
    feed = feedparser.parse(RTM_FEED_URL)

    entries = []
    for item in feed.entries:
        title = item.get("title", "")
        url = item.get("link", "")
        if LEVEL_FILTER not in title:
            continue
        if url in state["processed_urls"]:
            continue

        match = re.search(r"#(\d+)", title)
        episode_num = int(match.group(1)) if match else 0

        entries.append({
            "episode": episode_num,
            "title": title,
            "url": url,
            "pub_date": item.get("published", ""),
        })

    entries.sort(key=lambda e: e["episode"])
    return entries, state


# ---------------------------------------------------------------------------
# Page download
# ---------------------------------------------------------------------------

def fetch_page(url: str) -> str:
    """Download a Substack page, auto-refreshing the session if it has expired."""
    session = auth.get_session()
    resp = session.get(url, timeout=30)

    if resp.status_code in (401, 403):
        # Session expired — force a fresh login and retry once
        session = auth.get_session(force_refresh=True)
        resp = session.get(url, timeout=30)

    resp.raise_for_status()
    return resp.text


def extract_text(html: str) -> str:
    """Strip HTML, keep readable plain text for LLM parsing."""
    soup = BeautifulSoup(html, "lxml")

    # Remove noise elements
    for tag in soup.select("script, style, nav, footer, header, .subscribe-widget"):
        tag.decompose()

    # Substack post content lives in one of these containers
    content = (
        soup.find("div", class_="available-content")
        or soup.find("div", class_="post-content")
        or soup.find("article")
        or soup.find("main")
        or soup
    )

    return content.get_text(separator="\n", strip=True)

#!/usr/bin/env python3
"""RTM Learner — fetch, parse, translate, export.

Usage:
    python main.py              # process all new 中级 episodes
    python main.py --force 265  # reprocess a specific episode by number
"""
import argparse
import json
import shutil
import sys

from config import EPISODES_DIR, ICLOUD_DIR, PLECO_DIR
from exporters.pleco import generate_pleco_file
from fetcher import fetch_page, extract_text, get_new_entries, save_state
from parser import extract_episode
from translator import translate_words


def process_entry(entry: dict) -> None:
    print(f"\n→ Episode #{entry['episode']}: {entry['title']}")

    print("  [1/4] Downloading page...")
    html = fetch_page(entry["url"])
    text = extract_text(html)

    print("  [2/4] Extracting structure (Gemini)...")
    episode = extract_episode(text, entry)

    print("  [3/4] Translating to German (Gemini)...")
    episode["words"], episode["idioms"] = translate_words(
        episode.get("words", []),
        episode.get("idioms", []),
        topic=episode.get("title", ""),
    )

    print("  [4/4] Saving outputs...")

    # JSON — full structured data for future app use
    EPISODES_DIR.mkdir(parents=True, exist_ok=True)
    ep_file = EPISODES_DIR / f"{entry['episode']}.json"
    ep_file.write_text(json.dumps(episode, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"         JSON  → {ep_file}")

    # Pleco import file
    PLECO_DIR.mkdir(parents=True, exist_ok=True)
    pleco_file = PLECO_DIR / f"{entry['episode']}_pleco.txt"
    generate_pleco_file(episode, pleco_file)
    print(f"         Pleco → {pleco_file}")

    # iCloud Drive — auto-syncs to iPhone
    try:
        ICLOUD_DIR.mkdir(parents=True, exist_ok=True)
        dest = ICLOUD_DIR / pleco_file.name
        shutil.copy2(pleco_file, dest)
        print(f"         iCloud→ {dest}")
    except Exception as exc:
        print(f"         iCloud copy skipped: {exc}")


def main() -> None:
    parser = argparse.ArgumentParser(description="RTM Mandarin lesson fetcher & translator")
    parser.add_argument(
        "--force",
        metavar="EPISODE",
        type=int,
        help="Reprocess a specific episode number even if already seen",
    )
    args = parser.parse_args()

    if args.force:
        # Reprocess a specific episode from its saved JSON URL
        ep_file = EPISODES_DIR / f"{args.force}.json"
        if not ep_file.exists():
            print(f"No saved data for episode {args.force}. Run without --force first.")
            sys.exit(1)
        saved = json.loads(ep_file.read_text(encoding="utf-8"))
        entry = {k: saved[k] for k in ("episode", "title", "url", "pub_date") if k in saved}
        process_entry(entry)
        return

    # Normal run: process all new episodes
    print("RTM Learner — checking feed...")
    new_entries, state = get_new_entries()

    if not new_entries:
        print("No new 中级 episodes found.")
        return

    print(f"Found {len(new_entries)} new episode(s).")

    for entry in new_entries:
        try:
            process_entry(entry)
            state["processed_urls"].append(entry["url"])
            save_state(state)
            print(f"  ✓ Episode #{entry['episode']} complete")
        except Exception as exc:
            print(f"  ✗ Episode #{entry['episode']} failed: {exc}")
            raise


if __name__ == "__main__":
    main()

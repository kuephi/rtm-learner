"""Central configuration — all paths and env vars live here."""
import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

# --- API / Auth ---
SUBSTACK_EMAIL: str = os.environ["SUBSTACK_EMAIL"]
SUBSTACK_PASSWORD: str = os.environ["SUBSTACK_PASSWORD"]

# --- LLM provider selection ---
# Set LLM_PROVIDER to one of: claude, gemini, openai
LLM_PROVIDER: str = os.environ.get("LLM_PROVIDER", "claude")
LLM_MODEL: str | None = os.environ.get("LLM_MODEL")  # optional override

ANTHROPIC_API_KEY: str | None = os.environ.get("ANTHROPIC_API_KEY")
GEMINI_API_KEY: str | None = os.environ.get("GEMINI_API_KEY")
OPENAI_API_KEY: str | None = os.environ.get("OPENAI_API_KEY")

# Default models per provider
_DEFAULT_MODELS = {
    "claude": "claude-sonnet-4-6",
    "gemini": "gemini-2.0-flash",
    "openai": "gpt-4o",
}

def get_model() -> str:
    return LLM_MODEL or _DEFAULT_MODELS[LLM_PROVIDER]

# --- Feed ---
RTM_FEED_URL = "https://www.realtimemandarin.com/feed"
LEVEL_FILTER = "中级"

# --- Local paths ---
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
EPISODES_DIR = DATA_DIR / "episodes"
PLECO_DIR = DATA_DIR / "pleco"
STATE_FILE = DATA_DIR / "state.json"

# --- iCloud Drive (auto-syncs to iPhone) ---
ICLOUD_DIR = Path.home() / "Library" / "Mobile Documents" / "com~apple~CloudDocs" / "RTM"

"""
Set required environment variables before any project module is imported.
config.py reads env vars at import time, so this must run first.
"""
import os

os.environ.setdefault("SUBSTACK_EMAIL", "test@example.com")
os.environ.setdefault("SUBSTACK_PASSWORD", "testpass")
os.environ.setdefault("LLM_PROVIDER", "claude")
os.environ.setdefault("ANTHROPIC_API_KEY", "test-key")
os.environ.setdefault("GEMINI_API_KEY", "test-key")
os.environ.setdefault("OPENAI_API_KEY", "test-key")

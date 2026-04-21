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

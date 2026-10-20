import asyncio
import json
import os

from fastapi import Request
from litellm.proxy._types import ProxyException, UserAPIKeyAuth

import usage_tracking

KEYS_FILE = "/etc/litellm/keys.json"
MASTER_KEY_FILE = "/etc/litellm/master_key"

_cache = {"mtime": None, "keys": {}}


def _keys():
    try:
        mtime = os.path.getmtime(KEYS_FILE)
    except OSError:
        return {}
    if mtime != _cache["mtime"]:
        with open(KEYS_FILE) as f:
            _cache["keys"] = json.load(f)
        _cache["mtime"] = mtime
    return _cache["keys"]


def _master_key():
    try:
        with open(MASTER_KEY_FILE) as f:
            return f.read().strip()
    except OSError:
        return None


def _usd(amount):
    return f"${amount:,.2f}" if amount >= 1 else f"${amount:.4f}"


async def _check_budget(consumer):
    budget = usage_tracking.budget_usd(consumer)
    if not budget or not usage_tracking.settings().get("table"):
        return
    try:
        spent = await asyncio.to_thread(usage_tracking.spent_usd, consumer)
    except Exception:
        # A spend lookup that fails must not take every consumer offline.
        return
    if spent >= budget:
        raise ProxyException(
            message=(
                f"Monthly AI budget reached for {consumer}: {_usd(spent)} of {_usd(budget)}. "
                "It resets on the 1st (UTC); an operator can raise it on the LLM gateway."
            ),
            type="budget_exceeded",
            param=None,
            code=429,
        )


async def user_api_key_auth(request: Request, api_key: str) -> UserAPIKeyAuth:
    key = (api_key or "").removeprefix("Bearer ").strip()
    if key and key == _master_key():
        return UserAPIKeyAuth(api_key=key, user_id="admin")
    consumer = _keys().get(key)
    if not consumer:
        raise Exception("Unknown API key")
    await _check_budget(consumer)
    return UserAPIKeyAuth(api_key=key, user_id=consumer)

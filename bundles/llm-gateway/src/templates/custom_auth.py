import json
import os

from fastapi import Request
from litellm.proxy._types import UserAPIKeyAuth

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


async def user_api_key_auth(request: Request, api_key: str) -> UserAPIKeyAuth:
    key = (api_key or "").removeprefix("Bearer ").strip()
    if key and key == _master_key():
        return UserAPIKeyAuth(api_key=key, user_id="admin")
    consumer = _keys().get(key)
    if consumer:
        return UserAPIKeyAuth(api_key=key, user_id=consumer)
    raise Exception("Unknown API key")

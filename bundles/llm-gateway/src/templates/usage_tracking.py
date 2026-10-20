import asyncio
import json
import time
from datetime import datetime, timezone

import boto3
from litellm.integrations.custom_logger import CustomLogger

USAGE_FILE = "/etc/litellm/usage.json"

_settings = {"loaded_at": 0.0, "value": {}}
_client = {}


def settings():
    if time.time() - _settings["loaded_at"] > 30:
        try:
            with open(USAGE_FILE) as f:
                _settings["value"] = json.load(f)
        except (OSError, ValueError):
            pass
        _settings["loaded_at"] = time.time()
    return _settings["value"]


def dynamodb():
    region = settings().get("region")
    if region not in _client:
        _client[region] = boto3.client("dynamodb", region_name=region)
    return _client[region]


def month():
    return datetime.now(timezone.utc).strftime("%Y-%m")


def cost_usd(model, input_tokens, output_tokens):
    price = settings().get("prices", {}).get(model, {})
    return (input_tokens * price.get("input", 0) + output_tokens * price.get("output", 0)) / 1_000_000


def budget_usd(consumer):
    s = settings()
    return s.get("overrides", {}).get(consumer, s.get("default_budget_usd", 0))


_spend_cache = {}


def spent_usd(consumer):
    key = (consumer, month())
    cached = _spend_cache.get(key)
    if cached and time.time() - cached[0] < 15:
        return cached[1]
    item = dynamodb().get_item(
        TableName=settings()["table"],
        Key={"consumer": {"S": consumer}, "month": {"S": key[1]}},
        ProjectionExpression="cost_usd",
    ).get("Item", {})
    spent = float(item.get("cost_usd", {}).get("N", "0"))
    _spend_cache[key] = (time.time(), spent)
    return spent


def record(consumer, model, input_tokens, output_tokens, cost):
    dynamodb().update_item(
        TableName=settings()["table"],
        Key={"consumer": {"S": consumer}, "month": {"S": month()}},
        UpdateExpression="ADD cost_usd :c, input_tokens :i, output_tokens :o, requests :r",
        ExpressionAttributeValues={
            ":c": {"N": f"{cost:.8f}"},
            ":i": {"N": str(input_tokens)},
            ":o": {"N": str(output_tokens)},
            ":r": {"N": "1"},
        },
    )
    _spend_cache.pop((consumer, month()), None)


class UsageTracker(CustomLogger):
    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        log = kwargs.get("standard_logging_object") or {}
        consumer = (log.get("metadata") or {}).get("user_api_key_user_id") or "unknown"
        model = log.get("model_group") or kwargs.get("model") or "unknown"
        input_tokens = int(log.get("prompt_tokens") or 0)
        output_tokens = int(log.get("completion_tokens") or 0)
        cost = cost_usd(model, input_tokens, output_tokens)
        # One JSON line per request; the operator's Logs Insights queries parse these fields.
        print(json.dumps({
            "event": "usage",
            "consumer": consumer,
            "model": model,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cost_usd": round(cost, 8),
        }), flush=True)
        if settings().get("table"):
            try:
                await asyncio.to_thread(record, consumer, model, input_tokens, output_tokens, cost)
            except Exception as e:
                print(json.dumps({"event": "usage_write_failed", "consumer": consumer, "error": str(e)}), flush=True)


usage_tracker = UsageTracker()

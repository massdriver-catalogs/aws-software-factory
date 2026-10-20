import json
import os
import urllib.request

import boto3

TABLE_NAME = os.environ.get("TABLE_NAME")
AI_BASE_URL = os.environ.get("OPENAI_BASE_URL")


def handler(event, context):
    body = {
        "message": "Placeholder function. Set a container image to replace it.",
        "route": event.get("routeKey"),
        "path": event.get("rawPath"),
    }
    if TABLE_NAME:
        try:
            table = boto3.client("dynamodb").describe_table(TableName=TABLE_NAME)["Table"]
            body["table"] = {"name": TABLE_NAME, "status": table["TableStatus"]}
        except Exception as e:
            body["table"] = {"name": TABLE_NAME, "error": str(e)}
    if AI_BASE_URL:
        try:
            req = urllib.request.Request(
                AI_BASE_URL.rstrip("/") + "/models",
                headers={"Authorization": "Bearer " + os.environ["OPENAI_API_KEY"]},
            )
            with urllib.request.urlopen(req, timeout=5) as r:
                models = [m["id"] for m in json.load(r).get("data", [])]
            body["ai_platform"] = {"models": models, "default": os.environ.get("OPENAI_MODEL")}
        except Exception as e:
            body["ai_platform"] = {"error": str(e)}
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }

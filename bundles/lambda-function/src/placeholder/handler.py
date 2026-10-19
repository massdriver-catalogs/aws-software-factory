import json
import os

import boto3

TABLE_NAME = os.environ.get("TABLE_NAME")


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
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }

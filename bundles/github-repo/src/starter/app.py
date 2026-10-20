import json
import os


def handler(event, context):
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(
            {
                "message": "Hello from your app.",
                "path": event.get("rawPath"),
                "table": os.environ.get("TABLE_NAME"),
            }
        ),
    }

import json

from app import handler


def test_handler_answers_with_the_path():
    response = handler({"rawPath": "/todos"}, None)
    assert response["statusCode"] == 200
    assert json.loads(response["body"])["path"] == "/todos"

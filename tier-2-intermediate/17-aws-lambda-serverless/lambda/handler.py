"""Items API Lambda handler — CRUD operations backed by DynamoDB."""
import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

TABLE_NAME = os.environ["TABLE_NAME"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def handler(event: dict, context) -> dict:
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path   = event.get("rawPath", "")
    params = event.get("pathParameters") or {}

    try:
        if method == "GET" and path == "/items":
            return list_items()
        if method == "POST" and path == "/items":
            return create_item(json.loads(event.get("body") or "{}"))
        if method == "GET" and "/items/" in path:
            return get_item(params["id"])
        if method == "DELETE" and "/items/" in path:
            return delete_item(params["id"])
        return response(404, {"error": "Not found"})
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}")
        return response(500, {"error": "Internal server error"})


def list_items() -> dict:
    result = table.scan(Limit=100)
    return response(200, {"items": result.get("Items", [])})


def create_item(body: dict) -> dict:
    item = {
        "id":         str(uuid.uuid4()),
        "name":       body.get("name", ""),
        "owner_id":   body.get("owner_id", "anonymous"),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    table.put_item(Item=item)
    return response(201, {"item": item})


def get_item(item_id: str) -> dict:
    result = table.get_item(Key={"id": item_id})
    item = result.get("Item")
    if not item:
        return response(404, {"error": "Item not found"})
    return response(200, {"item": item})


def delete_item(item_id: str) -> dict:
    table.delete_item(Key={"id": item_id})
    return response(204, {})


def response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps(body),
    }

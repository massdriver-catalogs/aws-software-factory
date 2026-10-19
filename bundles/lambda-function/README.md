# Lambda Function

A function on arm64 that answers routes on a connected HTTP API, with an optional DynamoDB table.

## Code

Leave **Container image** empty and a built-in placeholder answers every route with the request it received and the status of its table. That proves the API, the function and the table are wired before any real code exists.

To run real code, push an **arm64** image to ECR and set its URI. The image must implement the Lambda runtime API: start from an AWS base image (`public.ecr.aws/lambda/python`, `nodejs`, …), or add the [Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter) to an ordinary web server image. Pin by digest or an immutable tag; a moving tag like `latest` isn't picked up until the next deploy anyway.

## Routes

Each entry is `METHOD /path`. `ANY /{proxy+}` plus `ANY /` sends everything to this function. To split an API across functions, give each one specific routes such as `GET /items` and `POST /items/{id}`.

The function receives API Gateway's version 2.0 event and returns `statusCode`, `headers` and `body`.

## Table

With a DynamoDB table connected, the function gets the table's read-write policy, or read with **Table access**, plus `TABLE_NAME` and `TABLE_PARTITION_KEY` environment variables.

# Todo App

The example app the factory builds: a Python function behind the HTTP API that keeps its todos in one table. Its code lives in the `todoapp` repository the GitHub Repository bundle creates, and every merge ships a new image to dev.

Todo App is an application on the `lambda-function` runtime. The runtime runs it behind the HTTP API and owns its image, routes, memory and sign-in.

## Tables

| Dependency | Holds | Environment variables |
|---|---|---|
| `todos` | The todos | `TABLE_NAME`, `TABLE_PARTITION_KEY` |

The function gets read-write access to it.

## Project

Todo App is its own project with a `dev` environment: a User Pool for sign-in, an HTTP API that checks it, the Todos Table, this application linked to the API and the table, a Static Site linked to the API, and Alarm to Issue. Its GitHub and ECR repositories are in the Codebases environment `todoapp`.

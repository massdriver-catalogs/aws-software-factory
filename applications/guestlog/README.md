# Guestlog

An event guestbook. Guests sign an event's page with a name and a message, and the host watches a live wall of them.

Guestlog is an application on the `lambda-function` runtime. The runtime runs it behind the HTTP API and owns its image, routes, memory and sign-in.

## Tables

| Dependency | Holds | Environment variable |
|---|---|---|
| `events` | Each event and its page | `EVENTS_TABLE` |
| `messages` | Every guest's name and message | `MESSAGES_TABLE` |

The function gets read-write access to both.

## Project

Guestlog is its own project with a `dev` environment: a Static Site for the landing page, an HTTP API, an optional User Pool, and Guestlog linked to the API and both tables. Its GitHub and ECR repositories are in the Codebases environment `guestlog`.

# Pollbox

Live polls. Create a poll with options and share its link. Everyone votes once, and the results update as votes come in.

Pollbox is an application on the `lambda-function` runtime. The runtime runs it behind the HTTP API and owns its image, routes, memory and sign-in.

## Tables

| Dependency | Holds | Environment variable |
|---|---|---|
| `polls` | Each poll and its options | `POLLS_TABLE` |
| `votes` | Every vote cast | `VOTES_TABLE` |

The function gets read-write access to both.

## Project

Pollbox is its own project with a `dev` environment: a Static Site for the landing page, an HTTP API, an optional User Pool, and Pollbox linked to the API and both tables. Its GitHub and ECR repositories are in the Codebases environment `pollbox`.

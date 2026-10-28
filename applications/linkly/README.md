# Linkly

A link shortener. Paste a long URL and get a short code. The short link redirects and counts every click, and each link has a stats page.

Linkly is an application on the `lambda-function` runtime. The runtime runs it behind the HTTP API and owns its image, routes, memory and sign-in.

## Tables

| Dependency | Holds | Environment variable |
|---|---|---|
| `links` | Each short code and the URL it points to | `LINKS_TABLE` |
| `clicks` | Every click on a short link | `CLICKS_TABLE` |

The function gets read-write access to both.

## Project

Linkly is its own project with a `dev` environment: a Static Site for the landing page, an HTTP API, an optional User Pool, and Linkly linked to the API and both tables. Its GitHub and ECR repositories are in the Codebases environment `linkly`.

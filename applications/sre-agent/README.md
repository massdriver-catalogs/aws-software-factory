# SRE Agent

An agent that runs every 15 minutes on its own VM. It reads Massdriver and CloudWatch alarms, finds the cause, and proposes the fix:

- **Config:** a proposed deployment of the instance with new params. A person approves it in Massdriver.
- **Code:** a draft pull request against the bundle's source repository, planned with the Massdriver architect skill.

It never deploys or merges on its own. Its notes are in `/workspace/sre/journal.md`, and each run's output is in `/workspace/.goal/runs`.

## What it can reach

Each kind of access is a setting on the instance, and each defaults to nothing:

| Setting | Give it | So it can |
|---|---|---|
| **AWS access for agents** | Alarms, metrics, logs and resource lists | Read CloudWatch alarms, metrics and logs |
| **Massdriver access for agents** | A group with `project:view` and `instance:propose` | Read instances and deployments, and propose deployments |
| GitHub App credential | Installed on the organizations that hold your bundle repositories | Clone them and open draft pull requests |

Leave out `instance:deploy` so every change waits for a person.

## Changing what it does

Its goal is part of this application. To try another goal without publishing, type it into **Goal** on the instance; that goal and its **Work on the goal** schedule replace the built-in ones. Clear it to go back.

Run it now, from a shell on the VM:

```bash
sandbox-goal --now
```

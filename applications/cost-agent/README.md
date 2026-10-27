# Cost Agent

An agent that checks every instance's cost against its **Monthly budget** once a day, on its own VM. For each instance over budget it:

1. finds the smallest param change that brings it under, such as a smaller size or shorter retention,
2. runs a plan of that change, with a 💸 message saying what it expects,
3. proposes the change, with a 💸 message giving the cost, the budget and the estimate.

A person approves or rejects the proposal in Massdriver. It never deploys on its own. Its notes are in `/workspace/cost/journal.md`.

## What it needs

- **Cost data in Massdriver.** Deploy the Cost Reports bundle once per AWS account and connect the integration. Costs appear within a day.
- **A monthly budget on each instance.** Every bundle in this catalog asks for one.
- **Massdriver access for agents:** a group with `project:view`, `instance:plan` and `instance:propose`. Leave out `instance:deploy` so every change waits for a person.

It needs no AWS access: costs, params and plans all come through Massdriver.

## Try it

Cost data takes a day to arrive. The test goal pretends one instance costs 3 times its budget and does everything else for real: a real plan and a real proposal, both marked `💸 [test]`. From a shell on the VM:

```bash
sandbox-goal --test
```

Reject the proposal afterwards.

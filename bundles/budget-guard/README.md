# Budget Guard

A monthly spending limit for the whole AWS account. It alerts; it never stops anything.

```mermaid
flowchart LR
  B[AWS Budget<br/>monthly limit] -->|actual spend crosses a threshold<br/>or the month is forecast to go over| T[SNS topic]
  T --> E[Email, if any]
  T --> O[Anything else you subscribe]
```

AWS updates spend a few times a day, so alerts lag real usage by hours. The forecast alert is the early warning; the percentage alerts confirm.

Deploy once per account. Two budgets per account are free; each one after that is about $0.62 a month.

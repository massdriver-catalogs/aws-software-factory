---
templating: mustache
---
# Alarm to Issue

## An alarm fired but no issue appeared

Check the function ran and what it said:

```bash
aws logs tail /aws/lambda/{{id}} --region {{params.region}} --since 1h
```

- **No log lines:** the event never matched. The rule only catches alarms whose names start with this environment's `<project>-<environment>-`. Compare:

  ```bash
  aws events describe-rule --region {{params.region}} --name {{id}} --query EventPattern --output text
  aws cloudwatch describe-alarms --region {{params.region}} --state-value ALARM --query 'MetricAlarms[].AlarmName'
  ```
- **`401` or `404` from GitHub:** the GitHub App isn't installed on {{#dependencies.repository}}`{{dependencies.repository.full_name}}`{{/dependencies.repository}}, or lost its issues permission. Check the App's installation in the organization's settings.
- **`422` on labels:** harmless; the `alarm` label already exists.

## Test the wiring

Turn on **Send a test alarm on this deploy** and deploy. An issue titled `Alarm: {{id}}-test` appears within a minute. Turn the setting off again and close the issue.

## Too many issues

Each alarm gets one open issue at a time; repeats become comments. If an alarm flaps, fix its threshold in the bundle that owns it rather than here.

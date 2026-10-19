# DynamoDB Table

{{#resources.table}}
## Look at the data

```bash
aws dynamodb describe-table --region {{params.region}} --table-name {{resources.table.name}} \
  --query 'Table.[TableStatus,ItemCount,TableSizeBytes]'
aws dynamodb scan --region {{params.region}} --table-name {{resources.table.name}} --max-items 10
```

`ItemCount` and size are refreshed by DynamoDB about every six hours.

## A function gets AccessDeniedException

The function's role doesn't have one of this table's policies, or has **read** and is writing. Check what's attached:

```bash
{{#resources.table.policies}}
aws iam list-entities-for-policy --policy-arn {{arn}} --query 'PolicyRoles[].RoleName'   # {{name}}
{{/resources.table.policies}}
```

Fix it on the function: set **Table access** to read-write and redeploy it.

## Requests are throttled

On-demand tables absorb sudden traffic up to about double the previous peak; beyond that, writes to a single partition key value are the usual cause. Spread writes across more key values.

## Restore deleted data

{{#params.point_in_time_recovery}}
```bash
aws dynamodb restore-table-to-point-in-time --region {{params.region}} \
  --source-table-name {{resources.table.name}} --target-table-name {{resources.table.name}}-restored \
  --restore-date-time <YYYY-MM-DDTHH:MM:SSZ>
```

The restore lands in a new table. Copy what you need back, or repoint the app.
{{/params.point_in_time_recovery}}
{{^params.point_in_time_recovery}}
Point-in-time recovery is off, so there is nothing to restore from. Turn it on to protect data from here on.
{{/params.point_in_time_recovery}}

## Decommission fails

**Deletion protection** is on. Turn it off, deploy, then decommission.
{{/resources.table}}

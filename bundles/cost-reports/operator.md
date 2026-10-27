---
templating: mustache
---
# Cost Reports

## Connect the integration

Read the values:

```bash
aws secretsmanager get-secret-value --region us-east-1 --secret-id {{id}}/integration \
  --query SecretString --output text | jq .
```

In Massdriver, open **Settings → Integrations → AWS Cost and Usage Reports** and paste:

| Field | Value |
|---|---|
| Access Key ID | `access_key_id` |
| Secret Access Key | `secret_access_key` |
| S3 Bucket Name | `bucket_name` |
| AWS Region | `bucket_region` |

## No costs after a day

- **No report yet:** `aws s3 ls s3://<bucket_name>/reports/ --recursive | tail`. AWS writes the first one within 24 hours.
- **"access_denied" or "bucket_not_found" when enabling:** the values were pasted into the wrong fields, or the key was rotated. Read them again.
- **Some instances have no cost:** their resources lack the `md-package` tag, or they cost nothing yet.


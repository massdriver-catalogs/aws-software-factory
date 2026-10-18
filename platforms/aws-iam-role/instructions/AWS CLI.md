# Connect your AWS account with the AWS CLI

Massdriver deploys into your account by assuming a role you create. The role trusts Massdriver's account only when the external ID below is presented.

## 1. Create the role

```bash
aws iam create-role \
  --role-name {{ROLE_NAME}} \
  --description "Massdriver provisioning" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "AWS": "308878630280" },
      "Action": "sts:AssumeRole",
      "Condition": { "StringEquals": { "sts:ExternalId": "{{EXTERNAL_ID}}" } }
    }]
  }'
```

## 2. Give it permission to build

The catalog creates networks, IAM roles, GPU instances and model endpoints, so the role needs administrator access.

```bash
aws iam attach-role-policy \
  --role-name {{ROLE_NAME}} \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

## 3. Copy the ARN

```bash
aws iam get-role --role-name {{ROLE_NAME}} --query Role.Arn --output text
```

Paste it into **Role ARN**, and paste `{{EXTERNAL_ID}}` into **External ID**.

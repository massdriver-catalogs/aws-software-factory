# Connect your AWS account with the AWS CLI

Massdriver deploys into your account by assuming a role you create. The role trusts Massdriver's account only when it presents an External ID: a secret value you choose.

## 1. Choose an External ID

```bash
EXTERNAL_ID=$(uuidgen)
echo "$EXTERNAL_ID"
```

Keep the value; it goes into the Massdriver form at the end.

## 2. Create the role

```bash
aws iam create-role \
  --role-name massdriver \
  --description "Massdriver provisioning" \
  --assume-role-policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": { \"AWS\": \"308878630280\" },
      \"Action\": \"sts:AssumeRole\",
      \"Condition\": { \"StringEquals\": { \"sts:ExternalId\": \"$EXTERNAL_ID\" } }
    }]
  }"
```

## 3. Give it permission to build

The catalog creates networks, IAM roles, GPU instances and model endpoints, so the role needs administrator access.

```bash
aws iam attach-role-policy \
  --role-name massdriver \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

## 4. Copy the ARN

```bash
aws iam get-role --role-name massdriver --query Role.Arn --output text
```

Paste it into **Role ARN**, and your External ID into **External ID**.

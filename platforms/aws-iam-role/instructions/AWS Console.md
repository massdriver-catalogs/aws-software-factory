# Connect your AWS account in the AWS Console

Massdriver deploys into your account by assuming a role you create. The role trusts Massdriver's account only when the external ID below is presented.

1. Open **IAM → Roles → Create role**.
2. Choose **AWS account**, then **Another AWS account**, and enter `308878630280`.
3. Tick **Require external ID** and enter `{{EXTERNAL_ID}}`. Click **Next**.
4. Search for and tick **AdministratorAccess**. The catalog creates networks, IAM roles, GPU instances and model endpoints, so it needs it. Click **Next**.
5. Name the role `{{ROLE_NAME}}` and click **Create role**.
6. Open the new role and copy the **ARN** at the top of the page.

Paste the ARN into **Role ARN**, and paste `{{EXTERNAL_ID}}` into **External ID**.

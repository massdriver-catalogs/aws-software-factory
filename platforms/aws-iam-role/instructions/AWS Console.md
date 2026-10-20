# Connect your AWS account in the AWS Console

Massdriver deploys into your account by assuming a role you create. The role trusts Massdriver's account only when it presents an External ID: a secret value you choose.

1. Make up an External ID: any long, hard-to-guess value, such as the output of `uuidgen` or a password generator. You'll paste it twice.
2. Open **IAM → Roles → Create role**.
3. Choose **AWS account**, then **Another AWS account**, and enter `308878630280`.
4. Tick **Require external ID**, paste your External ID, and click **Next**.
5. Search for and tick **AdministratorAccess**. The catalog creates networks, IAM roles, GPU instances and model endpoints, so it needs it. Click **Next**.
6. Name the role `massdriver` and click **Create role**.
7. Open the new role and copy the **ARN** at the top of the page.

Paste the ARN into **Role ARN**, and your External ID into **External ID**.

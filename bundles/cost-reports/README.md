# Cost Reports

Turns on per-instance costs in Massdriver for one AWS account. Deploy it once per account.

It creates:

- a daily AWS Cost and Usage Report, with resource-level detail, written to an S3 bucket,
- an IAM user that can only read that bucket and resource tags, and its access key,
- a Secrets Manager secret holding the four values Massdriver's integration needs.

Massdriver reads the report every 24 hours and attributes each line to an instance by its `md-instance` tag. Costs then show on every instance, environment and project, and in the API.

## After the first deploy

Massdriver's cost integration is configured once for the organization, in **Settings → Integrations → AWS Cost and Usage Reports**. The instance's operator guide prints the values to paste.

AWS writes the first report within 24 hours. Until then, instances show no cost.

## Cost allocation tag

In the AWS management (payer) account, turn on **Activate the md-instance cost allocation tag**. AWS then puts the tag on every report line, so deleted resources and Savings Plans are attributed too. Member accounts can't activate it; leave it off there.

## Cost

S3 storage for a few small reports a day: cents a month.

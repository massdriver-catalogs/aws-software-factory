# Landing Zone

## Deploy fails with InvalidSubnet.Conflict

Another landing zone holds **{{params.range}}**. Decommission this instance, pick another range, and deploy again. The range can't be changed in place.

{{#dependencies.network}}
Ranges already in use:

```bash
aws ec2 describe-subnets --region {{dependencies.network.region}} \
  --filters Name=vpc-id,Values={{dependencies.network.id}} \
  --query 'Subnets[].[CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table
```
{{/dependencies.network}}

## A workload can't reach another team's service

{{#params.isolated}}
That's the isolation working. If the two teams are meant to talk, turn off **Block traffic from other landing zones** on both landing zones and redeploy them; security groups then decide.
{{/params.isolated}}
{{^params.isolated}}
Isolation is off here, so check the other landing zone's setting, then security groups on both sides.
{{/params.isolated}}

## A workload can't reach the internet

{{#resources.landing_zone}}
{{^resources.landing_zone.internet_egress}}
The VPC has no egress. Private subnets reach only the VPC and its endpoints; change egress on the shared VPC.
{{/resources.landing_zone.internet_egress}}
{{/resources.landing_zone}}

Check the workload is in a **private** or **public** subnet — **internal** subnets have no route out by design. Then follow "Private subnets lost internet access" on the shared VPC.

Inbound from the internet is limited to 80, 443 and ports 1024 and up. A public service on another port below 1024 is blocked by the network ACL before its security group sees it.

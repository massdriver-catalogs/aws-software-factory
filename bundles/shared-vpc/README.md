# Shared VPC

One VPC per region, shared by every project. It is the only bundle that deals with address ranges: everything else drops into one of its subnets and is kept apart by its own security group.

## Subnets

Every availability zone gets three subnets.

| Tier | Size on a /16 | Routes to | For |
|---|---|---|---|
| Private | /19 | The VPC's egress | Most workloads: sandboxes, model serving, functions that reach private services |
| Internal | /21 | Nowhere outside the VPC | Databases and anything that must never reach the internet |
| Public | /22 | Internet gateway | Load balancers, NAT, and anything with a public IP |

Space is always laid out for three zones, so going from two zones to three later doesn't move any subnet.

S3 and DynamoDB gateway endpoints are attached to every subnet, so that traffic never goes through egress.

## Egress

| Option | Cost | Trade-off |
|---|---|---|
| None | — | Private subnets reach only the VPC and its endpoints |
| NAT instance | ~$7/month | A t4g.nano. EC2 auto-recovery restarts it if the host fails; egress pauses until it's back |
| NAT gateway | ~$33/month + $0.045/GB | Managed, but one zone |
| NAT gateway per zone | ~$33/month each + $0.045/GB | Survives a zone outage |

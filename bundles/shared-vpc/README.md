# Shared VPC

One VPC per region, shared by every team. It owns everything that has to exist once: the internet gateway, egress, VPC endpoints, flow logs and the route tables. Teams never connect to it directly; they get a landing zone carved out of it.

## Address layout

The CIDR is cut into /20s.

- **The first /20** holds the VPC's own subnets: a public /24 per zone for egress, and a private /24 per zone for interface endpoints and shared services such as the model gateway.
- **Every other /20** can be claimed by one landing zone.

Space is always laid out for three zones, so going from two zones to three later doesn't move any subnet.

## Route tables

Landing zones attach their subnets to the VPC's route tables instead of creating their own, so egress and gateway endpoints stay managed in one place.

| Route table | Default route |
|---|---|
| Public | Internet gateway |
| Private (one per zone) | The zone's NAT gateway, the single NAT gateway, or the NAT instance |
| Internal | None |

The S3 and DynamoDB gateway endpoints are attached to all of them.

## Egress

| Option | Cost | Trade-off |
|---|---|---|
| None | — | Private subnets reach only the VPC and its endpoints |
| NAT instance | ~$7/month | A t4g.nano. EC2 auto-recovery restarts it if the host fails; egress pauses until it's back |
| NAT gateway | ~$33/month + $0.045/GB | Managed, but one zone |
| NAT gateway per zone | ~$33/month each + $0.045/GB | Survives a zone outage |

# Landing Zone

A team's own /20 of the shared VPC. Everything a team runs — sandboxes, models, apps — connects to its landing zone, never to the VPC directly.

## Subnets

Every availability zone in the VPC gets three subnets.

| Tier | Size | Routes to | For |
|---|---|---|---|
| Private | /22 | The VPC's egress | Most workloads |
| Public | /25 | Internet gateway | Load balancers and anything with a public IP |
| Internal | /25 | Nowhere outside the VPC | Databases and anything that must never reach the internet |

Route tables belong to the VPC, so a change to egress applies to every landing zone at once.

## Isolation

With **Block traffic from other landing zones** on, a network ACL on every subnet:

- allows anything within the landing zone and to or from the VPC's shared range,
- denies the rest of the VPC,
- allows the internet only on return-traffic ports and 80/443 inbound, and anything outbound.

Security groups still decide what each workload accepts.

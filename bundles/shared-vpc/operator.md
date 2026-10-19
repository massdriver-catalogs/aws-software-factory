---
templating: mustache
---
# Shared VPC

## Private subnets lost internet access

Check which egress is in use, then follow that section.

```bash
aws ec2 describe-route-tables --region {{params.region}} \
  --filters Name=tag:Name,Values='{{id}}-private-*' \
  --query 'RouteTables[].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'
```

No `0.0.0.0/0` route means egress is set to **None**.

### NAT instance

```bash
aws ec2 describe-instance-status --region {{params.region}} --include-all-instances \
  --filters Name=tag:Name,Values='{{id}}-nat' \
  --query 'InstanceStatuses[].[InstanceId,InstanceState.Name,SystemStatus.Status,InstanceStatus.Status]'
```

- **stopped:** start it. The routes point at its network interface and come back on their own.
- **impaired system status:** auto-recovery should move it to new hardware within minutes. If it doesn't, stop and start it.
- **running and healthy:** connect and check forwarding.

```bash
aws ssm start-session --region {{params.region}} --target <instance-id>
sudo sysctl net.ipv4.ip_forward     # must be 1
sudo iptables -t nat -L POSTROUTING  # must show MASQUERADE
```

If either is missing, re-run the setup by replacing the instance: redeploy after tainting `aws_instance.nat[0]`.

### NAT gateway out of ports

The "out of ports" alarm means a single destination is getting more than ~55,000 simultaneous connections through one gateway. Find who is opening them:

```bash
aws logs start-query --region {{params.region}} \
  --log-group-name /vpc/{{id}}/flow-logs \
  --start-time $(( $(date +%s) - 3600 )) --end-time $(date +%s) \
  --query-string 'stats count(*) as flows by srcAddr, dstAddr | sort flows desc | limit 20'
```

The usual cause is a client that doesn't reuse connections. Fix the client; switching to **NAT gateway per zone** spreads the load but doesn't remove the cause.

## A subnet is running out of addresses

{{#resources.network}}
```bash
aws ec2 describe-subnets --region {{params.region}} \
  --filters Name=vpc-id,Values={{resources.network.id}} \
  --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],CidrBlock,AvailableIpAddressCount]' --output table
```
{{/resources.network}}

Workloads that pick a zone themselves tend to pile into the first one. Spread them across zones before anything else. If every zone is short, the VPC needs a second address range — that's a rebuild of this bundle's layout, so plan it rather than doing it at 2am.

## Traffic is being dropped

Flow logs record every rejected connection. Filter by the address that can't connect:

```bash
aws logs start-query --region {{params.region}} \
  --log-group-name /vpc/{{id}}/flow-logs \
  --start-time $(( $(date +%s) - 3600 )) --end-time $(date +%s) \
  --query-string 'filter action="REJECT" and (srcAddr="<ip>" or dstAddr="<ip>") | fields @timestamp, srcAddr, dstAddr, dstPort, protocol | sort @timestamp desc | limit 50'
```

Every reject comes from a security group: the receiving workload's group doesn't name the sender. Fix it in the receiving workload's bundle, not here.

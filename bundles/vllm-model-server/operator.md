---
templating: mustache
---
# vLLM Model Server

Find the instance:

```bash
ID=$(aws ec2 describe-instances --region {{dependencies.network.region}} \
  --filters Name=tag:Name,Values={{id}}-vllm Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[0].Instances[0].[InstanceId]' --output text)
aws ec2 describe-instances --region {{dependencies.network.region}} --instance-ids $ID \
  --query 'Reservations[0].Instances[0].State.Name' --output text
```

## The gateway can't reach the model

Usually the server is stopped by idle or nightly stop. Start it:

```bash
aws ec2 start-instances --region {{dependencies.network.region}} --instance-ids $ID
```

The model is ready a few minutes after the instance is running. Watch it load:

```bash
aws logs tail /{{id}}/vllm --region {{dependencies.network.region}} --follow
```

`Application startup complete` means it's serving.

## vLLM keeps restarting

```bash
aws ssm start-session --region {{dependencies.network.region}} --target $ID
sudo journalctl -u vllm -n 100
nvidia-smi
```

- **CUDA out of memory:** the model doesn't fit the GPU. Pick the larger GPU, or a model that fits.
- **nvidia-smi fails:** the GPU driver didn't load. Stop and start the instance to land on a new host.
- **Download errors from Hugging Face:** check the VPC has internet egress.

## A new server still takes 10 minutes to start

It downloaded instead of loading from the cache bucket. On the host:

```bash
sudo grep -h "restored from" /var/log/cloud-init-output.log
sudo systemctl status vllm-cache-save
sudo journalctl -u vllm-cache-save -n 50
```

- **No "restored from" lines and the save job failed:** the first server never filled the cache. Run `sudo systemctl start vllm-cache-save` on a healthy server; the next build uses it.
- **The save job is still running:** it uploads about 30 GB once the server is healthy. Builds started before it finishes still download.
- **The model or vLLM version changed:** each one gets its own cache entry, so the first server on a new one downloads again.

## Deploy fails on GPU quota

The account's "Running On-Demand G and VT instances" quota in {{dependencies.network.region}} is below 4 vCPUs.

```bash
aws service-quotas get-service-quota --region {{dependencies.network.region}} --service-code ec2 --quota-code L-DB2E81BA --query Quota.Value
aws service-quotas request-service-quota-increase --region {{dependencies.network.region}} --service-code ec2 --quota-code L-DB2E81BA --desired-value 4
```

## Deploy fails with InsufficientInstanceCapacity

AWS has no free GPUs of that type in the zone right now. Retry later, or pick a different GPU.

# LLM Gateway

The one address every consumer uses to reach a model. It speaks the OpenAI API, so opencode, Claude Code, LangChain and plain `curl` work against it unchanged.

## Who can reach what

- **Consumers** (sandboxes, runners, apps) reach the gateway on port 4000 from anywhere in the VPC, and must present a key.
- **Bedrock** is reachable only through the gateway: its IAM role is the only one granted `bedrock:InvokeModel`.
- **A self-hosted model server** accepts connections only from the gateway's security group.

## Keys

There is no key database. Each consumer writes its own key as a SecureString under the gateway's key prefix (`/<gateway>/keys/<consumer-name>`), and the gateway picks up every key under that path within a minute. Deleting the parameter revokes the key. Requests are attributed to the consumer name.

An admin key lives in Secrets Manager at `<gateway>/master-key`.

## Models

Bedrock models are billed per token. A connected model server shows up as `self-hosted-<model>`. The first Bedrock model is the default; with no Bedrock models, the model server is.

## Instance

A t4g.small running LiteLLM in Docker. Configuration and keys are read from Parameter Store every minute, so model changes apply without replacing the instance.

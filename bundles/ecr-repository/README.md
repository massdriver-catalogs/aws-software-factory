# ECR Repository

One container image repository for one app. A pipeline pushes images to it, and functions in the same account and region run them.

## Access

The repository publishes two IAM policies, **push** and **pull**. A pipeline or function attaches one to its own role, so permissions to the repository are defined in one place. Both include `ecr:GetAuthorizationToken`, which every `docker login` needs.

Lambda functions in this account can pull without either policy: the repository's own policy allows Lambda to fetch images for functions here.

## Tags

With **Immutable** tags, pushing an existing tag fails. Push a new tag per build, such as the commit SHA, and deploy that. A deployed image then never changes underneath a running function.

## Cleanup

Two lifecycle rules run daily:

- Untagged images, left behind by failed or replaced pushes, are deleted after **Delete untagged images after**.
- Beyond the newest **Keep the newest images**, older images are deleted. Rolling back to a deleted image means rebuilding it.

## Decommissioning

Decommissioning deletes the repository and every image in it. Rebuild images from the source repository if you need them again.

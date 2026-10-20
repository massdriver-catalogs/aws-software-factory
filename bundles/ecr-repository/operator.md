---
templating: mustache
---
# ECR Repository

{{#resources.repository}}
## List what's there

```bash
aws ecr describe-images --region {{params.region}} --repository-name {{resources.repository.name}} \
  --query 'sort_by(imageDetails,&imagePushedAt)[-10:].[imageTags[0],imagePushedAt,imageSizeInBytes]' --output table
```

## Push denied

- **`no basic auth credentials` or `401`:** log in first; tokens last 12 hours.

  ```bash
  aws ecr get-login-password --region {{params.region}} | docker login --username AWS --password-stdin {{resources.repository.registry_id}}.dkr.ecr.{{params.region}}.amazonaws.com
  ```

- **`AccessDeniedException`:** the pusher's role doesn't have this repository's **push** policy. Check who has it:

  ```bash
{{#resources.repository.policies}}
  aws iam list-entities-for-policy --policy-arn {{arn}} --query 'PolicyRoles[].RoleName'   # {{name}}
{{/resources.repository.policies}}
  ```

- **`tag invalid: The image tag '…' already exists`:** tags are immutable here. Push a new tag, such as the commit SHA, rather than reusing one.

## Image not found

A function or pull fails with `image not found` or `manifest unknown`:

```bash
aws ecr describe-images --region {{params.region}} --repository-name {{resources.repository.name}} --image-ids imageTag=<tag>
```

- **No such image:** it was never pushed (check the pipeline run), or the lifecycle rules deleted it (next section).
- **It exists:** the image isn't arm64, or the function is in another region. Rebuild with `--platform linux/arm64`.

## Scan findings

```bash
aws ecr describe-image-scan-findings --region {{params.region}} --repository-name {{resources.repository.name}} \
  --image-id imageTag=<tag> --query 'imageScanFindings.findingSeverityCounts'
```

Critical or high findings are almost always in the base image. Rebuild on a newer base image and push a new tag.

## The lifecycle rules deleted an image someone needed

ECR doesn't keep deleted images. Rebuild the image from its commit and push it again under the same tag. With immutable tags this works, because the tag no longer exists.

To keep more history, raise **Keep the newest images** and redeploy. That only protects images from here on.
{{/resources.repository}}

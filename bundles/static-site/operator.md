---
templating: mustache
---
# Static Site

{{#resources.site}}
## Publish by hand

```bash
aws s3 sync ./dist s3://{{resources.site.bucket}} --delete
aws cloudfront create-invalidation --distribution-id {{resources.site.distribution_id}} --paths '/*'
```

## Visitors still see the old version

The cache wasn't invalidated, or the invalidation hasn't finished (usually under a minute):

```bash
aws cloudfront list-invalidations --distribution-id {{resources.site.distribution_id}} --query 'InvalidationList.Items[:3]'
```

Browsers may also cache. A hard refresh rules that out.

## 403 Access Denied

- **Every path:** the bucket policy no longer names this distribution. Redeploy this bundle to restore it.
- **One path, with Single-page app off:** the file doesn't exist; S3 reports missing files as 403. Check `aws s3 ls s3://{{resources.site.bucket}}/<path>`.

## Roll back a bad publish

Replaced files are kept for 7 days as old versions:

```bash
aws s3api list-object-versions --bucket {{resources.site.bucket}} --prefix index.html --max-items 5
aws s3api copy-object --bucket {{resources.site.bucket}} --key index.html \
  --copy-source "{{resources.site.bucket}}/index.html?versionId=<version-id>"
```

Then invalidate the cache.
{{/resources.site}}

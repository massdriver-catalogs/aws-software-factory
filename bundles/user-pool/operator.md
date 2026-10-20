---
templating: mustache
---
# User Pool

{{#resources.user_pool}}
## Create a user by hand

```bash
aws cognito-idp admin-create-user --region {{params.region}} --user-pool-id {{resources.user_pool.id}} \
  --username someone@example.com --user-attributes Name=email,Value=someone@example.com Name=email_verified,Value=true
```

They get an email with a temporary password and set a new one on first sign-in.

## "redirect_mismatch" on the sign-in page

The app sent users back to a URL that isn't in **Where to return after sign-in**. It must match exactly, including scheme, port and trailing slash. Add it and redeploy.

## API answers 401 for a signed-in user

- The app sent the **ID** token where the API expects the **access** token, or the other way around. Either works if it comes from this pool's app client; check the token's `iss` is `{{resources.user_pool.issuer}}` and its `client_id` or `aud` is `{{resources.user_pool.client_id}}`.
- The token expired (they last an hour). The app should refresh it.

## Verification emails don't arrive

Cognito's built-in sender is limited to a few dozen emails a day per account. Check spam first. For real traffic, the pool needs Amazon SES configured as its sender.

## Find or disable a user

```bash
aws cognito-idp list-users --region {{params.region}} --user-pool-id {{resources.user_pool.id}} --filter 'email = "someone@example.com"'
aws cognito-idp admin-disable-user --region {{params.region}} --user-pool-id {{resources.user_pool.id}} --username someone@example.com
```
{{/resources.user_pool}}

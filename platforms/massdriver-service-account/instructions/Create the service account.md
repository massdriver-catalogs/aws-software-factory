# Create the service account

Bundles use this service account to make their own service accounts, each scoped by the group you pick for it.

## 1. Create a group that can manage service accounts

1. Open **Settings → Groups → Create group** and name it `Service Account Managers`.
2. Add a policy: **Allow** `organization:manageServiceAccounts` and `organization:manageGroups`, conditions `*`.

`organization:manageGroups` can add members to any group and write any policy, so this group is as powerful as an organization admin.

## 2. Create the service account

1. Open **Settings → Service Accounts → Create service account** and name it e.g. `Service Account Creator`, with a token that lasts **1 year**.
2. Copy the token. Massdriver shows it only once.
3. Add the service account to **Service Account Managers**.

## 3. Create the groups the new service accounts join

Make one group per job, each with only the policies that job needs. For example, a group that can deploy to dev:

- **Allow** `project:view`, conditions `*`
- **Allow** `instance:deploy`, conditions `{"md-environment": ["dev"]}`

Bundles show these groups in a list when you configure them.

Paste your organization ID into **Organization ID** and the token into **Token**.

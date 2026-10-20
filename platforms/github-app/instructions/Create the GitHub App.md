# Create the GitHub App

Massdriver acts on GitHub through an app installed on your organization, so access is scoped to the repositories you choose and tokens expire within an hour.

## 1. Create the app

Go to **github.com/organizations/&lt;your-org&gt;/settings/apps/new**.

- **GitHub App name:** anything unique, for example `<your-org>-massdriver`.
- **Homepage URL:** your organization's GitHub URL.
- **Webhook:** untick **Active**.

**Repository permissions**

| Permission | Access |
|---|---|
| Actions | Read and write |
| Administration | Read and write |
| Contents | Read and write |
| Issues | Read and write |
| Metadata | Read-only |
| Pull requests | Read and write |
| Secrets | Read and write |
| Variables | Read and write |
| Workflows | Read and write |

**Organization permissions**

| Permission | Access |
|---|---|
| Self-hosted runners | Read and write |

Under **Where can this GitHub App be installed?** choose **Only on this account**, then **Create GitHub App**.

## 2. Copy the App ID

It's on the app's settings page. Paste it into **App ID**.

## 3. Generate a private key

In the app's sidebar, open **Credentials**, then **Key pairs**, and click **New key**. Open the downloaded `.pem` file and paste all of it into **Private Key**.

## 4. Install it

Click **Install App** in the sidebar and install it on your organization, on **All repositories**. Bundles create new repositories, which a "selected repositories" install can't reach.

The browser lands on `.../settings/installations/<number>`. Paste that number into **Installation ID**, and your organization's login into **Organization**.

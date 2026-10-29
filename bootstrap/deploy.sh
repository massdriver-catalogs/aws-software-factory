#!/usr/bin/env bash
# Configures and deploys everything bootstrap.tf put on the canvas, with the
# walkthrough's presets, in dependency order. Safe to re-run: provisioned
# instances are skipped unless --redeploy is given.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./deploy.sh [options]

  --email ADDRESS        Budget Guard alert address (repeatable)
  --timezone ZONE        Nightly-stop time zone for the model server, e.g. America/New_York
  --aws-role ID          The AWS IAM Role credential, when the org has more than one
  --github-app ID        The GitHub App credential, when the org has more than one
  --oidc-exists          The AWS account already has GitHub's OIDC provider
  --management-account   Cost Reports runs in the payer account, not a member account
  --image URI            The example app's first image, instead of waiting for its first build
  --gpu                  Deploy the vLLM model server too (~$0.80 an hour while it runs)
  --redeploy             Deploy instances that are already provisioned, too
EOF
}

DIR=$(cd "$(dirname "$0")" && pwd)
EMAILS='[]'
TIMEZONE=""
AWS_ROLE=""
GITHUB_APP=""
OIDC_PRESET="New account"
COSTS_PRESET="Member account"
IMAGE=""
REDEPLOY=false
GPU=false

while [ $# -gt 0 ]; do
  case "$1" in
    --email) EMAILS=$(jq -c --arg e "$2" '. + [$e]' <<<"$EMAILS"); shift 2 ;;
    --timezone) TIMEZONE=$2; shift 2 ;;
    --aws-role) AWS_ROLE=$2; shift 2 ;;
    --github-app) GITHUB_APP=$2; shift 2 ;;
    --oidc-exists) OIDC_PRESET="Provider already exists"; shift ;;
    --management-account) COSTS_PRESET="Management account"; shift ;;
    --image) IMAGE=$2; shift 2 ;;
    --gpu) GPU=true; shift ;;
    --redeploy) REDEPLOY=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nStopped: %s\n' "$*" >&2; exit 1; }

for tool in mass jq terraform; do
  command -v "$tool" >/dev/null || die "$tool is not installed."
done
mass whoami >/dev/null 2>&1 || die "the mass CLI isn't logged in. Set MASSDRIVER_API_KEY and MASSDRIVER_ORGANIZATION_ID."

OUT=$(terraform -chdir="$DIR" output -json deploy 2>/dev/null) ||
  die "no Terraform output. Run 'terraform apply' in $DIR first."

inst() { jq -r --arg k "$1" '.instances[$k] // empty' <<<"$OUT"; }
envof() { jq -r --arg k "$1" '.environments[$k]' <<<"$OUT"; }
has() { [ -n "$(inst "$1")" ]; }

# One credential of each type is the common case; with more, the person picks.
credential() {
  local type=$1 given=$2 flag=$3 ids
  if [ -n "$given" ]; then echo "$given"; return; fi
  ids=$(mass resource list -t "$type" --origin imported -o json | jq -r '.[].id')
  case $(grep -c . <<<"$ids" || true) in
    0) die "no $type credential. Add it in Massdriver first (walkthrough steps 3 and 4)." ;;
    1) echo "$ids" ;;
    *) die "more than one $type credential. Pick one with $flag:
$(mass resource list -t "$type" --origin imported)" ;;
  esac
}

AWS_ROLE=$(credential aws-iam-role "$AWS_ROLE" --aws-role)
GITHUB_APP=$(credential github-app "$GITHUB_APP" --github-app)
OWNER=$(mass resource get "$GITHUB_APP" -o json | jq -r '.payload.owner // empty')

status() { mass instance get "$1" -o json | jq -r '.status'; }

# Shares with every environment, unless the resource is already shared.
share() {
  if [ "$(mass resource grant list "$1" -o json | jq 'length')" = 0 ]; then
    mass resource grant create "$1" --all-environments >/dev/null
  fi
}

defaults() {
  local env=$1; shift
  for resource in "$@"; do
    mass environment default "$env" "$resource" >/dev/null
  done
}

# deploy INSTANCE PRESET [JQ]: the preset's params, adjusted by JQ, then deployed.
deploy() {
  local id=$1 preset=$2 patch=${3:-.} params
  if [ "$(status "$id")" = PROVISIONED ] && [ "$REDEPLOY" = false ]; then
    echo "$id is already provisioned."
    return
  fi
  params=$(mktemp).json
  mass instance get "$id" -o json |
    jq --arg p "$preset" '.paramsSchema.examples[] | select(.__name == $p) | del(.__name)' |
    jq "$patch" >"$params"
  [ -s "$params" ] || die "$id has no '$preset' preset."
  echo "Deploying $id ($preset)..."
  # The CLI stops waiting before the slowest deploys finish, so the instance's status decides.
  mass instance deploy "$id" -p "$params" -m "Bootstrap: $preset preset" >/dev/null || true
  rm -f "$params"
  for _ in $(seq 1 120); do
    case $(status "$id") in
      PROVISIONED) return ;;
      FAILED) break ;;
    esac
    sleep 15
  done
  die "$id isn't provisioned. Read its deployment log in Massdriver, fix it, and run this again."
}

# allow INSTANCE FIELD VALUE: adds VALUE to the instance's list param FIELD and
# redeploys, unless it's already there.
allow() {
  local id=$1 field=$2 value=$3
  mass instance get "$id" -o json | jq -e --arg f "$field" --arg v "$value" '.params[$f] // [] | index($v)' >/dev/null && return
  echo "Adding $value to $id's $field..."
  mass instance deploy "$id" --patch ".$field += [\"$value\"]" -m "Bootstrap: allow $value" >/dev/null || true
  for _ in $(seq 1 120); do
    sleep 15
    case $(status "$id") in
      PROVISIONED) return ;;
      FAILED) break ;;
    esac
  done
  die "$id isn't provisioned. Read its deployment log in Massdriver, fix it, and run this again."
}

resource_payload() {
  mass instance get "$1" -o json | jq -r --arg f "$2" --arg k "$3" '.resources[] | select(.field == $f) | .payload[$k]'
}

say "Sharing the AWS IAM Role and GitHub App with every environment"
share "$AWS_ROLE"
share "$GITHUB_APP"

ACCOUNT=$(envof account)
NETWORKING=$(envof networking)
AI=$(envof ai)
CI=$(envof ci)
MASSDRIVER=$(jq -r '.massdriver_credential' <<<"$OUT")

say "AWS Account ($ACCOUNT)"
defaults "$ACCOUNT" "$AWS_ROLE"
deploy "$(inst budget)" "Free Tier" ".alert_emails = $EMAILS"
deploy "$(inst costs)" "$COSTS_PRESET"

say "Networking ($NETWORKING)"
defaults "$NETWORKING" "$AWS_ROLE"
deploy "$(inst vpc)" Development
NETWORK="$(inst vpc).network"
share "$NETWORK"

say "AI Platform ($AI)"
defaults "$AI" "$AWS_ROLE" "$NETWORK"
if has gpu && [ "$GPU" = true ]; then
  deploy "$(inst gpu)" Development "if \"$TIMEZONE\" == \"\" then . else .timezone = \"$TIMEZONE\" end"
fi
deploy "$(inst gateway)" Development
LLM="$(inst gateway).endpoint"
share "$LLM"

say "CI Platform ($CI)"
defaults "$CI" "$AWS_ROLE" "$NETWORK" "$GITHUB_APP" "$LLM"
deploy "$(inst oidc)" "$OIDC_PRESET"
deploy "$(inst runners)" Development
OIDC="$(inst oidc).oidc"
share "$OIDC"

if has sre; then
  AGENTS=$(envof agents)
  AGENT_GROUP=$(jq -r '.agent_group' <<<"$OUT")

  say "Agents ($AGENTS)"
  defaults "$AGENTS" "$AWS_ROLE" "$NETWORK" "$LLM" "$GITHUB_APP" "$MASSDRIVER"
  deploy "$(inst sre)" "SRE Agent" ".massdriver_groups = [\"$AGENT_GROUP\"]"
  deploy "$(inst cost)" "Cost Agent" ".massdriver_groups = [\"$AGENT_GROUP\"]"
fi

if has repo; then
  CODEBASES=$(envof codebases)
  APP=$(envof app)
  REPO_NAME=$(jq -r '.repository_name' <<<"$OUT")
  REPO="$(inst repo).repository"

  say "Codebases ($CODEBASES)"
  defaults "$CODEBASES" "$AWS_ROLE" "$GITHUB_APP" "$OIDC" "$MASSDRIVER"
  deploy "$(inst ecr)" Development
  # A repository that already exists is adopted rather than recreated.
  ADOPT=false
  gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1 && ADOPT=true
  deploy "$(inst repo)" "Private app" ".repository_name = \"$REPO_NAME\" | .adopt_existing_repository = $ADOPT"
  share "$REPO"

  say "Example app ($APP)"
  defaults "$APP" "$AWS_ROLE" "$NETWORK" "$LLM" "$GITHUB_APP"
  deploy "$(inst table)" Development
  # The website reads the API's URL from its link, so it comes after the API,
  # and sign-in and CORS learn the website's URL once it exists.
  deploy "$(inst users)" "Free Tier" '.callback_urls = ["http://localhost:5173/"]'
  deploy "$(inst api)" Development
  deploy "$(inst web)" "Single-page app"
  SITE=$(resource_payload "$(inst web)" site url)
  allow "$(inst users)" callback_urls "${SITE%/}/"
  allow "$(inst api)" cors_allowed_origins "${SITE%/}"

  if [ -z "$IMAGE" ] && { [ "$(status "$(inst app)")" != PROVISIONED ] || [ "$REDEPLOY" = true ]; }; then
    REGISTRY=$(resource_payload "$(inst ecr)" repository url)
    command -v gh >/dev/null ||
      die "waiting for the first build needs the GitHub CLI (gh). Install it, or pass --image $REGISTRY:<commit>."
    echo "Waiting for the first build of $OWNER/$REPO_NAME to push an image..."
    for _ in $(seq 1 60); do
      SHA=$(gh run list -R "$OWNER/$REPO_NAME" -w build -b main -s success -L 1 --json headSha -q '.[0].headSha' 2>/dev/null || true)
      [ -n "$SHA" ] && break
      sleep 15
    done
    [ -n "${SHA:-}" ] || die "no successful build on main after 15 minutes. Check the repository's Actions tab, then pass --image $REGISTRY:<commit>."
    IMAGE="$REGISTRY:$SHA"
  fi
  deploy "$(inst app)" "Free Tier" ".image_uri = \"$IMAGE\""

  mass instance remote-reference set "$(inst alarms)" repository "$REPO" >/dev/null
  deploy "$(inst alarms)" "Issues only"

  if [ "$(mass instance get "$(inst repo)" -o json | jq -r '.params.release_instance // ""')" != "$(inst app)" ]; then
    say "Turning on release to dev"
    mass instance deploy "$(inst repo)" \
      --patch ".release_instance = \"$(inst app)\" | .release_groups = [\"$(jq -r '.release_group' <<<"$OUT")\"]" \
      -m "Bootstrap: release merged builds to $(inst app)" >/dev/null ||
      die "turning on release didn't deploy. Read the repository's deployment log in Massdriver."
  fi

  API=$(resource_payload "$(inst api)" api endpoint)
  say "Done. App: $SITE  API: $API  Repository: https://github.com/$OWNER/$REPO_NAME"
else
  say "Done."
fi
echo "Cost Reports still needs its four values pasted into Settings → Integrations; its operator guide shows the command."

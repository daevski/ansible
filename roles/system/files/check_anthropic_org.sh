#!/bin/bash
# Watchdog: verify every Hermes instance on this box (all /home/*/.hermes/.env)
# is using the expected PERSONAL Anthropic org, not a work/enterprise org.
# Silent (no stdout) when everything checks out. Prints an alert when any
# instance's ANTHROPIC_TOKEN resolves to an unexpected org, or is missing/bad.
#
# Deployed by ansible role `system` / task `anthropic-org-watchdog.yml`.
# Expected org id lives at /etc/anthropic-org-watchdog.conf as
# PERSONAL_ORG_ID=<uuid> (ansible-managed, templated from
# anthropic_personal_org_id in group_vars/all.yml).
#
# To update the expected org id (new personal account, migration, etc)
# WITHOUT re-running ansible: edit /etc/anthropic-org-watchdog.conf directly
# as root. Note a future ansible run will overwrite it back to whatever
# anthropic_personal_org_id is set to in group_vars/all.yml -- update that
# too if the change should be permanent.
set -uo pipefail

CONF_FILE="/etc/anthropic-org-watchdog.conf"

if [ -f "$CONF_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONF_FILE"
fi

if [ -z "${PERSONAL_ORG_ID:-}" ]; then
    echo "⚠️ ANTHROPIC WATCHDOG: $CONF_FILE is missing or has no PERSONAL_ORG_ID set -- can't verify anything. Re-run the anthropic-org-watchdog ansible playbook, or set it manually:
  sudo tee $CONF_FILE <<< 'PERSONAL_ORG_ID=<your-personal-org-uuid>'"
    exit 0
fi

HOW_TO_FIX="If your personal org id changed (new account, migration, etc), update it with:
  sudo tee /etc/anthropic-org-watchdog.conf <<< 'PERSONAL_ORG_ID=<new-org-uuid>'
then this watchdog picks it up on its next run automatically -- no restart needed.
(This file is ansible-managed -- also update anthropic_personal_org_id in
group_vars/all.yml in the ansible repo so a future playbook run doesn't
revert it.)"

ALERTS=""

check_env_file() {
    local user="$1"
    local env_file="$2"
    local reader_cmd="$3"

    local key
    key=$($reader_cmd "$env_file" 2>/dev/null | grep '^ANTHROPIC_TOKEN=' | head -1 | cut -d= -f2-)

    if [ -z "${key:-}" ]; then
        return
    fi

    local headers
    headers=$(mktemp)
    local http_code
    http_code=$(curl -s -o /dev/null -D "$headers" -w "%{http_code}" \
      https://api.anthropic.com/v1/messages \
      -H "Authorization: Bearer $key" \
      -H "anthropic-version: 2023-06-01" \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "content-type: application/json" \
      -d '{"model":"org-id-probe-invalid-model","max_tokens":1,"messages":[{"role":"user","content":"x"}]}' \
      --max-time 15) || true

    local org_id
    org_id=$(grep -i '^anthropic-organization-id:' "$headers" 2>/dev/null | awk '{print $2}' | tr -d '\r')
    rm -f "$headers"

    if [ "$http_code" = "401" ]; then
        ALERTS="${ALERTS}⚠️ [$user] ANTHROPIC_TOKEN in $env_file is invalid/expired (401). That instance's LLM calls may be failing.
"
        return
    fi

    if [ -z "$org_id" ]; then
        ALERTS="${ALERTS}⚠️ [$user] could not determine org id for $env_file (HTTP $http_code, no org header). Check manually.
"
        return
    fi

    if [ "$org_id" != "$PERSONAL_ORG_ID" ]; then
        ALERTS="${ALERTS}🚨 [$user] $env_file is NOT on the expected personal org! Active org_id=$org_id (expected $PERSONAL_ORG_ID). Looks like an enterprise/work account is wired in -- fix ANTHROPIC_TOKEN in that file and /restart that instance's gateway.
"
    fi
}

if [ -f "$HOME/.hermes/.env" ]; then
    check_env_file "$(whoami)" "$HOME/.hermes/.env" "cat"
fi

for d in /home/*/; do
    u=$(basename "$d")
    [ "$u" = "$(whoami)" ] && continue
    env_file="${d}.hermes/.env"

    if [ -r "$env_file" ]; then
        check_env_file "$u" "$env_file" "cat"
    elif sudo -n -u "$u" test -f "$env_file" 2>/dev/null; then
        check_env_file "$u" "$env_file" "sudo -n -u $u cat"
    fi
done

if [ -n "$ALERTS" ]; then
    printf '%s\n%s\n' "$ALERTS" "$HOW_TO_FIX"
fi

exit 0

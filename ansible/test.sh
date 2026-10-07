#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "▶ Vérification migration..."
ansible-playbook playbooks/03-verify.yml | grep -E "HTTP (prod|staging)"

echo "▶ Test local via /etc/hosts..."
curl -s -o /dev/null -w "tahiry-cloud.com        → %{http_code}\n" http://tahiry-cloud.com/
curl -s -o /dev/null -w "staging.tahiry-cloud.com → %{http_code}\n" http://staging.tahiry-cloud.com/

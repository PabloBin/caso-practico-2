#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"
OUT_DIR="${REPO_ROOT}/ansible/group_vars/all"
OUT_FILE="${OUT_DIR}/acr.yml"

mkdir -p "$OUT_DIR"

ACR_LOGIN_SERVER="$(cd "$TF_DIR" && terraform output -raw acr_login_server)"
# En ACR, el username suele ser el nombre del registry (acr_name)
ACR_USERNAME="$(cd "$TF_DIR" && terraform output -raw acr_name)"

if [[ -z "$ACR_LOGIN_SERVER" || "$ACR_LOGIN_SERVER" == "null" ]]; then
  echo "No se pudo obtener acr_login_server desde Terraform."
  exit 1
fi

if [[ -z "$ACR_USERNAME" || "$ACR_USERNAME" == "null" ]]; then
  echo "No se pudo obtener acr_name desde Terraform."
  exit 1
fi

cat > "$OUT_FILE" <<EOF
acr_login_server: "${ACR_LOGIN_SERVER}"
acr_username: "${ACR_USERNAME}"
EOF

echo "   Variables ACR generadas en: $OUT_FILE"
echo "   acr_login_server: $ACR_LOGIN_SERVER"
echo "   acr_username: $ACR_USERNAME"
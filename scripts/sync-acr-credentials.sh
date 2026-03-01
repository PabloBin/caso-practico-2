#!/usr/bin/env bash
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../terraform" && pwd)"
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VAULT_FILE="$ANSIBLE_DIR/group_vars/vault.yml"
TMP_JSON="$(mktemp)"

echo "[1/3] Leyendo outputs de Terraform..."
ACR_NAME="$(terraform -chdir="$TF_DIR" output -raw acr_name)"

echo "[2/3] Obteniendo credenciales admin del ACR via az..."
# Requiere: az login
az acr credential show -n "$ACR_NAME" -o json > "$TMP_JSON"

ACR_PASSWORD="$(python3 -c "import json; d=json.load(open('$TMP_JSON')); print(d['passwords'][0]['value'])")"
rm -f "$TMP_JSON"

echo "[3/3] Actualizando vault.yml (solo acr_password)..."
if [[ ! -f "$VAULT_FILE" ]]; then
  echo "ERROR: No existe $VAULT_FILE"
  exit 1
fi

python3 - <<PY
import re
from pathlib import Path

p = Path("$VAULT_FILE")
txt = p.read_text(encoding="utf-8")

key = "acr_password"
value = "$ACR_PASSWORD"

if re.search(rf"(?m)^{re.escape(key)}\s*:", txt):
    txt = re.sub(rf"(?m)^{re.escape(key)}\s*:\s*.*$", f"{key}: {value}", txt)
else:
    txt = txt.rstrip() + f"\n{key}: {value}\n"

p.write_text(txt, encoding="utf-8")
print("OK: vault.yml actualizado (acr_password).")
PY

echo "Listo."
echo "Si vault.yml está cifrado con ansible-vault, NO lo ejecutes así aún (te digo el flujo en el paso 2)."
#!/usr/bin/env bash
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../terraform" && pwd)"
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VAULT_FILE="$ANSIBLE_DIR/group_vars/vault.yml"

if [[ ! -f "$VAULT_FILE" ]]; then
  echo "ERROR: No existe $VAULT_FILE"
  exit 1
fi

# 1) Leer ACR name desde Terraform
ACR_NAME="$(terraform -chdir="$TF_DIR" output -raw acr_name)"
echo "[1/4] ACR_NAME=$ACR_NAME"

# 2) Sacar password admin del ACR (requiere: az login)
echo "[2/4] Obteniendo password desde Azure..."
ACR_PASSWORD="$(az acr credential show -n "$ACR_NAME" --query "passwords[0].value" -o tsv)"

if [[ -z "${ACR_PASSWORD}" ]]; then
  echo "ERROR: No he podido obtener ACR_PASSWORD (¿az login? ¿acr admin enabled?)"
  exit 1
fi
echo "OK: password obtenido (no lo muestro)."

# 3) Desencriptar a un temporal, editar acr_password, reencriptar
TMP="$(mktemp)"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

echo "[3/4] Desencriptando vault a temporal (te pedirá Vault password)..."
ansible-vault decrypt "$VAULT_FILE" --output "$TMP"

echo "[4/4] Actualizando solo 'acr_password' y reencriptando..."
python3 - <<PY
import re
from pathlib import Path

p = Path("$TMP")
txt = p.read_text(encoding="utf-8")

key = "acr_password"
value = "$ACR_PASSWORD"

if re.search(rf"(?m)^{re.escape(key)}\s*:", txt):
    txt = re.sub(rf"(?m)^{re.escape(key)}\s*:\s*.*$", f"{key}: {value}", txt)
else:
    txt = txt.rstrip() + f"\n{key}: {value}\n"

p.write_text(txt, encoding="utf-8")
PY

ansible-vault encrypt "$TMP"
# Sustituimos el vault original por el temporal re-encriptado
cp "$TMP" "$VAULT_FILE"

echo "OK: vault.yml actualizado (acr_password) y sigue cifrado."
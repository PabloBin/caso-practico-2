#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (parent of this scripts/ folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TF_DIR="$REPO_ROOT/terraform"
ANSIBLE_DIR="$REPO_ROOT/ansible"
VAULT_FILE="$ANSIBLE_DIR/group_vars/vault.yml"

if [[ ! -d "$TF_DIR" ]]; then
  echo "ERROR: No existe terraform/ en: $TF_DIR"
  echo "Estructura esperada: <repo>/terraform y <repo>/ansible y <repo>/scripts"
  exit 1
fi

if [[ ! -d "$ANSIBLE_DIR" ]]; then
  echo "ERROR: No existe ansible/ en: $ANSIBLE_DIR"
  exit 1
fi

if [[ ! -f "$VAULT_FILE" ]]; then
  echo "ERROR: No existe vault.yml en: $VAULT_FILE"
  exit 1
fi

# Ensure logged in (soft check)
if ! az account show >/dev/null 2>&1; then
  echo "ERROR: No estás logueado en Azure CLI. Ejecuta: az login"
  exit 1
fi

# Read ACR name from Terraform outputs (state must exist)
ACR_NAME="$(terraform -chdir="$TF_DIR" output -raw acr_name 2>/dev/null || true)"
if [[ -z "$ACR_NAME" ]]; then
  echo "ERROR: No puedo leer 'acr_name' desde Terraform outputs."
  echo "Ejecuta en $TF_DIR: terraform output"
  exit 1
fi

echo "ACR detectado: $ACR_NAME"

# Get current ACR admin password (passwords[0].value)
ACR_PASSWORD="$(
  az acr credential show -n "$ACR_NAME" \
    --query "passwords[0].value" -o tsv
)"

if [[ -z "$ACR_PASSWORD" ]]; then
  echo "ERROR: No se ha podido obtener la contraseña del ACR (admin)."
  echo "¿Tienes habilitado el 'Admin user' en el ACR y permisos para leer credenciales?"
  exit 1
fi

TMP_CLEAR="$(mktemp)"
TMP_VAULT="$(mktemp)"
trap 'rm -f "$TMP_CLEAR" "$TMP_VAULT"' EXIT

# Decrypt vault to temp
ansible-vault decrypt "$VAULT_FILE" --output "$TMP_CLEAR"

# Update (or add) acr_password key
# Keep simple YAML: acr_password: "..."
if grep -qE '^\s*acr_password\s*:' "$TMP_CLEAR"; then
  # Replace existing line
  sed -i -E 's#^\s*acr_password\s*:.*#acr_password: "'"$ACR_PASSWORD"'"#' "$TMP_CLEAR"
else
  # Append
  printf '\nacr_password: "%s"\n' "$ACR_PASSWORD" >> "$TMP_CLEAR"
fi

# Re-encrypt back to vault file
ansible-vault encrypt "$TMP_CLEAR" --output "$TMP_VAULT"
mv "$TMP_VAULT" "$VAULT_FILE"

echo "OK: vault actualizado -> ansible/group_vars/vault.yml (acr_password)"
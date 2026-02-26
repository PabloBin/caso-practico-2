#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"
ANSIBLE_INV="${REPO_ROOT}/ansible/inventory.ini"
KEY_PATH="${REPO_ROOT}/.keys/vm_ubuntu_key"

VM_IP="$(cd "$TF_DIR" && terraform output -raw vm_public_ip)"

if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
  echo "No se pudo obtener vm_public_ip desde Terraform."
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "No existe la key privada en: $KEY_PATH"
  echo "   Ejecuta terraform apply (y que genere la key) antes."
  exit 1
fi

cat > "$ANSIBLE_INV" <<EOF
[vm]
azurevm ansible_host=${VM_IP} ansible_user=azureuser ansible_ssh_private_key_file=${KEY_PATH}

[vm:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
EOF

echo "Inventory generado en: $ANSIBLE_INV"
echo "   IP: $VM_IP"
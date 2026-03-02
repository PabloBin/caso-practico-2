# Ejecución (pasos reproducibles)

## Requisitos previos
- Azure CLI (`az`) autenticado contra tu suscripción.
- Terraform instalado.
- Ansible instalado.
- Colecciones Ansible:
  - `azure.azcollection`
  - `kubernetes.core`
- Acceso a los secretos de **Ansible Vault** (password del vault).

## 1) Terraform (infraestructura)

Desde la raíz del repo:

    cd terraform
    cp terraform.tfvars.example terraform.tfvars
    terraform fmt -recursive
    terraform init
    terraform apply -auto-approve

## 2) Actualizar password del ACR en Vault (cuando rota)

> Este paso **solo es necesario si ha cambiado** el `acr_password` (por ejemplo, tras regenerar credenciales del ACR).
> Si ha cambiado, hazlo **antes de ejecutar** `ansible-playbook site.yml`, o fallarán los pasos que usan el registry.

Este repo incluye el script:

- `scripts/update-vault-acr-password.sh`

Se usa cuando cambie el `acr_password`, para mantener `ansible/group_vars/vault.yml` sincronizado.

## 3) Esperar AKS accesible (kubeconfig) antes de Ansible

Si acabas de crear AKS, primero asegúrate de poder traer credenciales y que el clúster responde:

    cd terraform
    AKS_RG=$(terraform output -raw aks_resource_group)
    AKS_NAME=$(terraform output -raw aks_name)

    # Traer kubeconfig
    az aks get-credentials -g "$AKS_RG" -n "$AKS_NAME" --overwrite-existing

    # Comprobación rápida
    kubectl get nodes

> Esto evita errores tipo `NameResolutionError` / problemas de resolución o acceso al API server cuando el clúster aún no está totalmente listo.

## 4) Ansible (configuración + despliegues)

Desde la raíz del repo:

    cd ansible
    ansible-playbook site.yml --ask-vault-pass

## Ejecución por partes (tags reales del proyecto)

### Sincronizar inventario/variables desde Terraform
    ansible-playbook site.yml --ask-vault-pass --tags "sync_tf"

### Preparar VM (Ubuntu) e instalar Podman
    ansible-playbook site.yml --ask-vault-pass --tags "vm"

### Generar assets nginx-secure (cert + htpasswd)
    ansible-playbook site.yml --ask-vault-pass --tags "nginx_assets"

### Build & Push imagen nginx-secure al ACR
    ansible-playbook site.yml --ask-vault-pass --tags "nginx_image"

### Subir imágenes (AKS) al ACR
    ansible-playbook site.yml --ask-vault-pass --tags "acr_images"

### Desplegar nginx-secure en VM (Podman + TLS + Basic Auth)
    ansible-playbook site.yml --ask-vault-pass --tags "deploy_vm"

### Crear secretos AKS (Redis)
    ansible-playbook site.yml --ask-vault-pass --tags "aks_secrets"

### Desplegar aplicación en AKS
    ansible-playbook site.yml --ask-vault-pass --tags "aks_deploy"

## Validaciones rápidas

### VM nginx-secure
    VM_IP=$(terraform -chdir=terraform output -raw vm_public_ip)

    # Debe devolver 401
    curl -kI --max-time 10 "https://$VM_IP:8443/"

    # Debe devolver 200 con credenciales correctas (usa tus valores reales)
    curl -k --user "USER:PASS" --max-time 10 "https://$VM_IP:8443/"

### AKS Azure Vote
    EXTERNAL_IP=$(kubectl get svc -n azure-vote azure-vote-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Azure Vote LB=$EXTERNAL_IP"
    curl -i --max-time 10 "http://$EXTERNAL_IP/" | head
    kubectl get pods -n azure-vote

### PVC
    kubectl get pvc -n azure-vote
    kubectl describe pvc -n azure-vote
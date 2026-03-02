# Caso Práctico 2 — Terraform + Ansible en Azure (ACR + VM + AKS)

Repositorio para desplegar **100% automatizado** (sin recursos creados a mano) la infraestructura y las aplicaciones requeridas en Azure:

- **ACR** (Azure Container Registry) accesible desde Internet con autenticación.
- **VM Ubuntu 22.04** con **Podman rootless** ejecutando **nginx-secure** desde imagen alojada en ACR.
  - Acceso público por **HTTPS (8443)** con **certificado autofirmado x.509** y **autenticación básica (htpasswd)**.
  - Servicio persistente mediante **systemd --user** + **linger**.
- **AKS (1 worker)** desplegando **Azure Vote** con **Redis** y **persistencia** (PVC).

---

## Requisitos previos

En la máquina desde la que ejecutas:

- Azure CLI (`az`)
- Terraform
- Ansible + colecciones:
  - `azure.azcollection`
  - `kubernetes.core`
- Acceso a una suscripción de Azure (y permisos para crear RG, ACR, VM, AKS, role assignments).

> Nota: este repo usa **Ansible Vault** para secretos (por ejemplo credenciales Basic Auth y secret de Redis).

---

## Documentación

- [Arquitectura](docs/arquitectura.md)
- [Ejecución paso a paso](docs/ejecucion.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Terraform (infraestructura)](terraform/README.md)
- [Ansible (orquestación y tags)](ansible/README.md)

## Estructura del repositorio

- `terraform/` — infraestructura Azure (RG, ACR, VM, AKS, NSG, role AcrPull).
- `ansible/`
  - `site.yml` — **punto de entrada**: orquesta todo por tags.
  - `playbooks/` — playbooks importados por `site.yml`.
  - `roles/` — roles (VM base, build/push imágenes, deploy VM, deploy AKS, etc.).
  - `group_vars/` — variables (incluye `vault.yml` cifrado).
- `podman/nginx-secure/` — Dockerfile/Containerfile, html, nginx.conf, certs (si aplica).

---

## Despliegue

### 1) Terraform (infraestructura)

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

### 3) Esperar AKS accesible (kubeconfig) antes de Ansible

Si acabas de crear AKS, primero asegúrate de poder traer credenciales y que el clúster responde:

    cd terraform
    AKS_RG=$(terraform output -raw aks_resource_group)
    AKS_NAME=$(terraform output -raw aks_name)

    # Traer kubeconfig
    az aks get-credentials -g "$AKS_RG" -n "$AKS_NAME" --overwrite-existing

    # Comprobación rápida
    kubectl get nodes

> Esto evita errores tipo `NameResolutionError` / problemas de resolución o acceso al API server cuando el clúster aún no está totalmente listo.

### 4) Ansible (configuración + despliegues)

    cd ../ansible
    ansible-playbook site.yml --ask-vault-pass

Se Puede ejecutar por partes usando tags (ejemplos):

    # Solo sincronizar outputs de Terraform (IPs, nombres, etc.)
    ansible-playbook site.yml -t sync --ask-vault-pass

    # Configurar VM base (podman, dependencias, etc.)
    ansible-playbook site.yml -t vm --ask-vault-pass

    # Build + push de la imagen nginx-secure al ACR
    ansible-playbook site.yml -t build_nginx --ask-vault-pass

    # Deploy nginx-secure en VM (systemd --user)
    ansible-playbook site.yml -t deploy_vm --ask-vault-pass

    # Secretos + despliegue AKS (Azure Vote + Redis + PVC)
    ansible-playbook site.yml -t aks --ask-vault-pass

---

## Validaciones

### A) Validar nginx-secure en VM (HTTPS + Basic Auth)

    VM_IP=$(terraform -chdir=terraform output -raw vm_public_ip)

    # Debe devolver 401 (pide credenciales)
    curl -kI --max-time 10 "https://$VM_IP:8443/"

    # Debe devolver 200 con usuario/contraseña (usa tus valores reales)
    curl -k --user "USER:PASS" --max-time 10 "https://$VM_IP:8443/"

### B) Validar AKS (Azure Vote)

    # obtener IP externa del servicio
    EXTERNAL_IP=$(kubectl get svc -n azure-vote azure-vote-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Azure Vote LB=$EXTERNAL_IP"

    # debe responder en HTTP
    curl -i --max-time 10 "http://$EXTERNAL_IP/" | head
    kubectl get pods -n azure-vote

### C) Validar persistencia Redis (PVC)

    kubectl get pvc -n azure-vote
    kubectl describe pvc -n azure-vote

---
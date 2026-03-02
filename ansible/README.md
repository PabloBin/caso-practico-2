# Ansible (Configuración y despliegues)

## Punto de entrada

El orquestador principal es:

- `site.yml`

Ejecuta todo:

    ansible-playbook site.yml --ask-vault-pass

---

## Tags (ejecución por partes)

Estas son las tags disponibles en `site.yml`:

- `sync_tf`      -> sincroniza inventario/variables desde Terraform outputs
- `vm`           -> prepara VM (Ubuntu) e instala Podman
- `nginx_assets` -> genera cert + htpasswd para construir la imagen nginx-secure
- `nginx_image`  -> build + push de nginx-secure al ACR
- `acr_images`   -> push de imágenes AKS al ACR
- `deploy_vm`    -> despliega nginx-secure en VM (pull + run + systemd --user)
- `aks_secrets`  -> crea secrets (Redis) en AKS (módulo k8s)
- `aks_deploy`   -> despliega Azure Vote en AKS (módulo k8s)

Ejemplos:

    # preparar VM y desplegar nginx-secure
    ansible-playbook site.yml --ask-vault-pass --tags "vm,deploy_vm"

    # desplegar solo AKS
    ansible-playbook site.yml --ask-vault-pass --tags "aks_secrets,aks_deploy"

---

## Vault (secretos)

Este repo usa `ansible/group_vars/vault.yml` cifrado con Ansible Vault.

Si se rota el password del ACR, actualiza Vault antes de ejecutar Ansible:

- `scripts/update-vault-acr-password.sh`
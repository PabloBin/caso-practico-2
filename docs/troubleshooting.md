# Troubleshooting (problemas típicos y soluciones)

Este documento recopila fallos habituales durante el despliegue y validación del CP2.

---

## 1) VM (nginx-secure en Podman rootless)

### 1.1 No responde `https://<VM_IP>:8443`
**Síntomas**
- `curl -kI https://<VM_IP>:8443/` hace timeout o “connection refused”.

**Checks (desde tu máquina)**
    VM_IP=$(terraform -chdir=terraform output -raw vm_public_ip)
    curl -vk --max-time 10 "https://$VM_IP:8443/"

**Causas típicas**
- NSG no permite 8443/tcp.
- Servicio no está levantado.
- El contenedor no publica el puerto esperado.

**Checks (en la VM)**
    # ver puertos escuchando
    ss -lntp | grep 8443 || true

    # ver contenedores podman
    podman ps -a

    # ver logs del contenedor (ajusta nombre si difiere)
    podman logs nginx-secure --tail 200

### 1.2 Devuelve 401 pero nunca consigo 200 con credenciales
**Síntomas**
- `curl -kI` devuelve 401 (correcto), pero con `--user` sigue 401.

**Checks**
    curl -kI --max-time 10 "https://$VM_IP:8443/"
    curl -k --user "USER:PASS" --max-time 10 "https://$VM_IP:8443/"

**Causas típicas**
- Usuario/password no coincide con el `htpasswd` que quedó dentro de la imagen.
- `nginx.conf` apunta a una ruta incorrecta de `htpasswd`.

**Qué revisar**
- Dentro del contenedor (si tienes acceso):
    podman exec -it nginx-secure sh
    cat /etc/nginx/conf.d/default.conf 2>/dev/null || true
    cat /etc/nginx/nginx.conf 2>/dev/null || true

### 1.3 Tras reiniciar la VM el contenedor queda “Exited”
**Causa típica**
- Falta `linger` o el servicio systemd de usuario no está habilitado.

**Checks**
    loginctl show-user "$USER" | grep -i linger || true

    systemctl --user status nginx-secure.service
    systemctl --user is-enabled nginx-secure.service || true

**Solución típica**
    loginctl enable-linger "$USER"
    systemctl --user daemon-reload
    systemctl --user enable --now nginx-secure.service

**Logs del servicio**
    journalctl --user -u nginx-secure.service -n 200 --no-pager

---

## 2) ACR (login / push / pull)

### 2.1 Falla push/pull por credenciales
**Síntomas**
- Errores de autenticación contra el registry.
- `podman login` falla.
- Tasks de Ansible relacionadas con ACR fallan.

**Causa típica**
- Se rotó/regeneró `acr_password` y Vault está desactualizado.

**Solución**
- Actualiza Vault con el script:
  - `scripts/update-vault-acr-password.sh`
- Luego vuelve a ejecutar el tag que falló (por ejemplo `nginx_image`, `acr_images` o `deploy_vm`).

---

## 3) AKS (Azure Vote + Redis + PVC)

### 3.1 El LoadBalancer no tiene EXTERNAL_IP (tarda mucho)
**Nota**
- Es normal que tarde algunos minutos.

**Checks**
    kubectl get svc -n azure-vote
    kubectl describe svc -n azure-vote azure-vote-front

### 3.2 Pods en Pending / CrashLoopBackOff
**Checks**
    kubectl get pods -n azure-vote -o wide
    kubectl describe pod -n azure-vote <POD_NAME>
    kubectl get events -n azure-vote --sort-by=.lastTimestamp

**Causas típicas**
- PVC sin enlazar (storageclass, permisos).
- Secret de Redis ausente o mal referenciado.
- Imagen no descargable (ACR auth).

### 3.3 PVC en Pending (no se enlaza)
**Checks**
    kubectl get sc
    kubectl get pvc -n azure-vote
    kubectl describe pvc -n azure-vote

**Causas típicas**
- StorageClass inexistente/no por defecto.
- Parámetros incompatibles.

### 3.4 Redis NOAUTH / Azure Vote no conecta
**Checks**
    kubectl get secret -n azure-vote
    kubectl describe deployment -n azure-vote azure-vote-front
    kubectl logs -n azure-vote deploy/azure-vote-front --tail 200

**Causas típicas**
- Secret no creado (`aks_secrets` no ejecutado).
- El deployment no referencia la clave correcta del Secret.

---

## 4) Errores de acceso/resolución a AKS desde tu máquina (NameResolutionError, etc.)

### 4.1 El cluster aún no está listo o kubeconfig no actualizado
**Solución recomendada (antes de Ansible)**
    cd terraform
    AKS_RG=$(terraform output -raw aks_resource_group)
    AKS_NAME=$(terraform output -raw aks_name)

    az aks get-credentials -g "$AKS_RG" -n "$AKS_NAME" --overwrite-existing
    kubectl get nodes

## 5) Ansible: “Primera ejecución falla (SSH 22 timeout) y segunda funciona”

**Síntoma**
- Tras `terraform apply` (o `destroy/apply`), al ejecutar:

  `ansible-playbook site.yml --ask-vault-pass`

  falla el play de la VM con *Connection timed out* en el puerto 22, pero al ejecutar el mismo comando por segunda vez funciona.

**Causa**
- Ansible **carga el inventario una sola vez al arrancar el proceso**.
- Aunque el paso `sync_tf` regenere `ansible/inventories/azure/inventory.ini` con la IP nueva, los siguientes plays del **mismo run** siguen usando el inventario que ya estaba cargado en memoria al inicio (con IP antigua).

**Solución aplicada en este repo**
- En `playbooks/00-sync/sync-from-terraform.yml` se refresca el inventario **en memoria** usando `add_host` con los outputs de Terraform (IP pública, usuario y clave SSH).
- Así, los plays posteriores (`hosts: vm`) ya conectan a la IP correcta en la **primera** ejecución.

**Comprobación rápida**
- Revisa el resumen de `sync_tf` (debe mostrar la IP pública actual).
- Si necesitas ver el inventario generado:

  `cat ansible/inventories/azure/inventory.ini`
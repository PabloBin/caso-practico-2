# Arquitectura (ACR + VM + AKS)

## Objetivo
Desplegar en Azure, de forma **100% automatizada**, la infraestructura y dos aplicaciones:

- **VM (Podman)**: servidor web **nginx-secure** accesible desde Internet por **HTTPS 8443**, con **certificado x.509 autofirmado** y **Basic Auth (htpasswd)**.
- **AKS (1 worker)**: aplicación **Azure Vote** con **Redis** y **persistencia** (PVC).

## Componentes

- **Resource Group (RG)**: contenedor lógico de todos los recursos.
- **ACR (Azure Container Registry)**:
  - Accesible desde Internet con autenticación.
  - Repositorios separados para las imágenes:
    - `podman/nginx-secure:casopractico2`
    - `aks/*:casopractico2` (front y redis)
- **VM Ubuntu 22.04**:
  - Configurada por Ansible.
  - Usa **Podman rootless**.
  - Ejecuta `nginx-secure` como servicio persistente con **systemd --user**.
  - Se habilita **linger** para que el servicio sobreviva a reinicios aunque no haya sesión interactiva.
- **NSG (Network Security Group)**:
  - Permite entrada desde Internet a:
    - `22/tcp` (SSH)
    - `80/tcp` (si se usa)
    - `8443/tcp` (HTTPS rootless → puerto público del nginx-secure)
- **AKS (Kubernetes)**:
  - 1 nodo worker.
  - Acceso autenticado al ACR (role assignment **AcrPull**).
  - Namespace `azure-vote`.
  - Servicio `LoadBalancer` para exponer `azure-vote-front`.
  - PVC para persistencia de Redis.

## Flujo de despliegue

1) **Terraform** crea RG + ACR + VM + AKS + NSG + permisos (AcrPull).
2) **Ansible**:
   - Sincroniza outputs (IPs, nombres).
   - Configura VM (Podman, deps).
   - Construye y sube imagen `podman/nginx-secure:casopractico2` al ACR.
   - Despliega el contenedor en la VM como servicio systemd de usuario.
   - Despliega en AKS (Azure Vote + Redis + PVC) usando `kubernetes.core.k8s`.

## Diagrama (alto nivel)

Cliente (Internet)
  |-- HTTPS 8443 --> VM Ubuntu (Podman rootless) --> nginx-secure
  |
  |-- HTTP --> AKS (LoadBalancer) --> azure-vote-front --> redis (PVC)

ACR
  ^            ^
  | pull       | pull
VM (podman)    AKS (kubelet)
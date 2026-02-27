# Caso Práctico 2 (UNIR) — Terraform + Ansible + ACR + Podman + AKS

Este repositorio despliega en **Azure** (100% IaC) la infraestructura y aplicaciones requeridas:

- **Terraform**: Resource Group + ACR + VM Linux + AKS (1 worker)
- **ACR**: accesible desde Internet, autenticación, y repositorios con tag `casopractico2`
- **VM (Podman)**: servidor web **nginx-secure** como contenedor, con:
  - **TLS x.509 autofirmado**
  - **Basic Auth (htpasswd)**
  - imagen en ACR con el contenido/cert/credenciales dentro
- **AKS**: aplicación distinta (Azure Vote + Redis) con **persistencia** (PVC) y acceso público

---

## 1) Requisitos previos

### En mi máquina Ubuntu (control node)
- Azure CLI (`az`)
- Terraform
- Ansible + colecciones:
  ```bash
  cd ansible
  ansible-galaxy collection install -r requirements.yml
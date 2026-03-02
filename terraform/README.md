# Terraform (Infraestructura Azure)

Este módulo despliega la infraestructura necesaria para el Caso Práctico 2:

- Resource Group
- ACR (Azure Container Registry)
- VM Ubuntu 22.04 + IP pública + NSG
- AKS (1 worker)
- Role assignment para que AKS pueda hacer pull del ACR (AcrPull)

---

## Variables

Este proyecto usa variables para nombrado y configuración. Para ejecutarlo:

1) Copia el ejemplo:
    
    cp terraform.tfvars.example terraform.tfvars

2) Ajusta valores (especialmente `name_prefix`).

Variables principales (obligatorias si no tienen `default`):
- `project` (ej. `casopractico2`)
- `env` (ej. `dev`)
- `location` (ej. `italynorth`)
- `name_prefix` (prefijo único global, usado en nombres como ACR)

---

## Ejecución

Desde `terraform/`:

    terraform fmt -recursive
    terraform init
    terraform apply -auto-approve

---

## Outputs

Terraform expone outputs consumidos por Ansible (por ejemplo IP pública de la VM, nombre del ACR, datos de AKS, etc.).

Para verlos:

    terraform output

Y para obtener valores concretos:

    terraform output -raw vm_public_ip
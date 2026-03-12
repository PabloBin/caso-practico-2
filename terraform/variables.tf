variable "project" {
  type        = string
  description = "Identificador del proyecto (por ejemplo, casopractico2)"
}

variable "env" {
  type        = string
  description = "Entorno (por ejemplo, dev)"
}

variable "location" {
  type        = string
  description = "Región de Azure (por ejemplo, italynorth)"
}

variable "name_prefix" {
  type        = string
  description = "Prefijo único para nombres globalmente únicos (ACR) y para el nombrado de recursos"
}

variable "vm_admin_username" {
  type        = string
  description = "Nombre de usuario administrador para la máquina virtual Linux"
  default     = "azureuser"
}

# --------------------
# Clave SSH (generada por Terraform)
# --------------------
variable "ssh_key_output_dir" {
  type        = string
  description = "Directorio (relativo a la carpeta terraform/) donde se escribirá el par de claves SSH generado"
  default     = "../.keys"
}

variable "ssh_key_name" {
  type        = string
  description = "Nombre base del archivo para la clave SSH generada (clave privada). La clave pública será <nombre>.pub"
  default     = "vm_ubuntu_key"
}

variable "aks_node_count" {
  type        = number
  description = "Número de nodos en el pool de nodos de AKS"
  default     = 1
}

variable "aks_vm_size" {
  type        = string
  description = "Tamaño de máquina virtual para los nodos de AKS"
  default     = "Standard_B2s_v2"
}

variable "aks_dns_prefix" {
  type        = string
  description = "Prefijo DNS para AKS"
  default     = "cp2aks"
}
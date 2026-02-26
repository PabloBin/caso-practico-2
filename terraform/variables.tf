variable "project" {
  type        = string
  description = "Project identifier (e.g., casopractico2)"
}

variable "env" {
  type        = string
  description = "Environment (e.g., dev)"
}

variable "location" {
  type        = string
  description = "Azure region (e.g., westeurope)"
}

variable "name_prefix" {
  type        = string
  description = "Unique prefix for globally-unique names (ACR) and resource naming"
}

variable "vm_admin_username" {
  type        = string
  description = "Admin username for the Linux VM"
  default     = "azureuser"
}

variable "vm_ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

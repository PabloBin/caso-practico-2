locals {
  # Naming
  rg_name  = "${var.name_prefix}-rg"
  acr_name = replace("${var.name_prefix}acr", "-", "") # ACR solo permite caracteres alfanuméricos.
  aks_name = "${var.name_prefix}-aks"
  vm_name  = "${var.name_prefix}-vm"

  vnet_name   = "${var.name_prefix}-vnet"
  subnet_name = "${var.name_prefix}-subnet"
  nsg_name    = "${var.name_prefix}-nsg"
  pip_name    = "${var.name_prefix}-pip"
  nic_name    = "${var.name_prefix}-nic"

  # Tags
  tags = {
    environment = var.project
    project     = var.project
    env         = var.env
  }
}

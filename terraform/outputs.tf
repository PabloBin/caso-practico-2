output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "location" {
  value = var.location
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "vm_admin_username" {
  value = var.vm_admin_username
}

# Safe outputs for the generated SSH key (no private key in outputs)
output "ssh_public_key_openssh" {
  value = tls_private_key.vm_ssh.public_key_openssh
}

output "ssh_private_key_path" {
  value = local_file.vm_ssh_private.filename
}

output "ssh_public_key_path" {
  value = local_file.vm_ssh_public.filename
}

# --------------------
# Par de claves SSH para la VM (generado por Terraform)
# NOTA:
# - La clave privada se almacenará en el estado de Terraform (como parte del recurso tls_private_key).
# - NO mostramos la clave privada en las salidas; solo la escribimos en un archivo local en ../.keys (ignorado por Git).
# --------------------
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "vm_ssh_private" {
  filename             = "${var.ssh_key_output_dir}/${var.ssh_key_name}"
  content              = tls_private_key.vm_ssh.private_key_pem
  file_permission      = "0600"
  directory_permission = "0700"
}

resource "local_file" "vm_ssh_public" {
  filename             = "${var.ssh_key_output_dir}/${var.ssh_key_name}.pub"
  content              = tls_private_key.vm_ssh.public_key_openssh
  file_permission      = "0644"
  directory_permission = "0700"
}
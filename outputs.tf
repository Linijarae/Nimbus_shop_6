output "site_url" {
  value       = "http://${azurerm_public_ip.pip_lb.ip_address}"
  description = "URL du site vitrine"
}

output "jumpbox_ip" {
  value       = azurerm_public_ip.pip_jumpbox.ip_address
  description = "IP de la Jumpbox pour le SSH"
}
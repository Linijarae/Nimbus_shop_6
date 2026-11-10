output "site_url" {
  value       = "http://${azurerm_public_ip.pip_lb.ip_address}"
  description = "URL du site vitrine"
}
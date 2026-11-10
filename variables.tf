variable "subscription_id" {
    type = string 
    description = "ID de l'abonnement Azure" 
} 
variable "binome" {
    type = string
    description = "Votre numéro du groupe" 
} 
variable "region" {
    type = string
    default = "denmarkeast"
} 
variable "taille_vm" {
    type = string
    default = "Standard_B2ats_v2"
}
variable "ssh_pub_key" {
  type        = string
  description = "Chemin vers la clé SSH publique"
}
variable "my_ip" {
  type        = string
  description = "IP publique autorisée pour le SSH"
}
variable "admin_email" {
  type        = string
  description = "Email pour recevoir l'alerte CPU"
}
resource "azurerm_resource_group" "rg" {
    name        = "rg-nimbus-${var.binome}"
    location    = var.region
    tags = {
        projet = "nimbus-shop"
        owner = var.binome
    }
}

resource "azurerm_virtual_network" "vnet" {
  name          = "vnet-${var.binome}"
  address_space = ["10.6.0.0/16"]
  location      = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet-web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.6.1.0/24"]
}

resource "azurerm_subnet" "snet-admin" {
  name                 = "snet-admin"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.6.2.0/24"]
}

resource "azurerm_network_security_group" "nsg_web" {
  name                = "nsg-web-nimbus-${var.binome}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowHTTPInternet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowProbe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic_web" {
  count               = 2
  name                = "nic-web-${count.index + 1}-nimbus-${var.binome}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet-web.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_web" {
  count               = 2
  name                = "vm-web-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.taille_vm
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.nic_web[count.index].id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.ssh_pub_key)
  }

  os_disk {
    name                 = "osdisk-web-${count.index + 1}-nimbus-${var.binome}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = filebase64("${path.module}/cloud-init.yaml")
}

resource "azurerm_public_ip" "pip_lb" {
  name                = "pip-lb-nimbus-${var.binome}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "lb-nimbus-${var.binome}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_lb_assoc" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.nic_web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_pool.id
}

resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-health"
  protocol        = "Http"
  port            = 80
  request_path    = "/sante"
}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_pool.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}

resource "azurerm_public_ip" "pip_nat" {
  name                = "pip-nat-nimbus-${var.binome}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "natgw" {
  name                = "natgw-nimbus-${var.binome}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.pip_nat.id
}

resource "azurerm_subnet_nat_gateway_association" "natgw_snet_assoc" {
  subnet_id      = azurerm_subnet.snet-web.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

resource "azurerm_subnet_network_security_group_association" "nsg_web_assoc" {
  subnet_id                 = azurerm_subnet.snet-web.id
  network_security_group_id = azurerm_network_security_group.nsg_web.id
}
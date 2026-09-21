
# resource "azurerm_virtual_network" "vnet1" {
#   name                = "example-network"
#   address_space       = ["10.0.0.0/16"]
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
# }

# Pritunl subnet
resource "azurerm_subnet" "pritunl_subnet" {
  name                 = "pritunl"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "pritunlnic" {
  name                = "pritunl-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pritunl_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pritunl_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "pritunlvm" {
  name                = "pritunlvm0122"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2ats_v2"
  admin_username      = "adminuser"

  network_interface_ids = [
    azurerm_network_interface.pritunlnic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "pritunlnsg" {
  name                = "pritunl-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH - temporary/administrative access
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  # Pritunl web dashboard
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  # Pritunl VPN traffic
  security_rule {
    name                       = "Allow-OpenVPN"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1194"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "pritunl_nicrule" {
  network_interface_id      = azurerm_network_interface.pritunlnic.id
  network_security_group_id = azurerm_network_security_group.pritunlnsg.id
}

resource "azurerm_public_ip" "pritunl_public_ip" {
  name                = "pritunl-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}
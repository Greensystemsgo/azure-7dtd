# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rtwl_7dtd_rg" {
    name     = "rtwl_7dtd"
    location = "West US 2"

    tags = {
        environment = "rtwl_7dtd"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "rtwl_7dtd_network" {
    name                = "rtwl_7dtd_vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "West US 2"
    resource_group_name = azurerm_resource_group.rtwl_7dtd_rg.name

    tags = {
        environment = "rtwl_7dtd"
    }
}

# Create subnet
resource "azurerm_subnet" "rtwl_7dtd_subnet" {
    name                 = "rtwl_7dtd_subnet"
    resource_group_name  = azurerm_resource_group.rtwl_7dtd_rg.name
    virtual_network_name = azurerm_virtual_network.rtwl_7dtd_network.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "rtwl_7dtd_publicip" {
    name                         = "rtwl_7dtd_publicip"
    location                     = "West US 2"
    resource_group_name          = azurerm_resource_group.rtwl_7dtd_rg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "rtwl_7dtd"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "rtwl_7dtd_sg" {
    name                = "rtwl_7dtd_sg"
    location            = "West US 2"
    resource_group_name = azurerm_resource_group.rtwl_7dtd_rg.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "rtwl_7dtd"
    }
}

# Create network interface
resource "azurerm_network_interface" "rtwl_7dtd_nic" {
    name                      = "rtwl_7dtd_nic"
    location                  = "West US 2"
    resource_group_name       = azurerm_resource_group.rtwl_7dtd_rg.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.rtwl_7dtd_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.rtwl_7dtd_publicip.id
    }

    tags = {
        environment = "rtwl_7dtd"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.rtwl_7dtd_nic.id
    network_security_group_id = azurerm_network_security_group.rtwl_7dtd_sg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.rtwl_7dtd_rg.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "rtwl_7dtd_storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.rtwl_7dtd_rg.name
    location                    = "West US 2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "rtwl_7dtd"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = "${tls_private_key.example_ssh.private_key_pem}" }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "rtwl_7dtd_vm" {
    name                  = "rtwl_7dtd_vm"
    location              = "West US 2"
    resource_group_name   = azurerm_resource_group.rtwl_7dtd_rg.name
    network_interface_ids = [azurerm_network_interface.rtwl_7dtd_nic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "rtwl_7dtd_osdisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.5"
        version   = "latest"
    }

    computer_name  = "7dtdvm"
    admin_username = "cnorris"
    disable_password_authentication = true
        
    admin_ssh_key {
        username       = "cnorris"
        public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD9NFoelZ8RzKcTzmMlyYhWm9q6VyazMO5CZGumHsiVR35oUrrkPcD/EChgDAs8y4W/FEadLSSTF2QZqnCKppGaxGaBG7/VX3vroa5Nf2k5kwNAkPK1m3UcSUd3dAybWiMTnj+lPLM8AFF+9iEk4o67wMnH2sphSdBvOFf9GFzzywp8rcgcMkfObPe/p5OPM/b32Vn0ku2fAseei3pinKZMkXjC5Wr2QHgnetdgj+CDid5uYv4GrwIFHWPOboxrdc/b8AsQubncfYZFhWzJeVNKtXx1NMbFVEVqU8y/qSDGT/wuP5SBcc1p+yEWuBzNsHZsgEMsu4sUgRYrI5H5mbGeFRAEzrBhiaun0HwUj05CkD6VqErWCm3VivQ1/wm0k6gS6D9qj6SC/f5cPDbsMYaMVA2Ph7OnlwgjP1sYFgOC6FCq9EV6GzWKXIGHx51JD5L0YPRuT49tASHMTR4HbaIy6Jw7O1KNyBmcpsgNgPtQNY7HQ9PRsqtGGOkwa8YvP16RgN8Z8/a7UQU/X2up1Zx1Ahw10F9aptpEi84OwRRUYoeZ2zJd6vxW666BnqcPeIDQwBUF0uPS1LAydcTqEKTSeeUv4gUJSmnTYfveTMSl60YCjCbYzxGnEZB9GjEq1QLXdff9i2qepRHHZBOUCBRK0DyEixY1G50SFxPjpoV26Q=="
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.rtwl_7dtd_storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "rtwl_7dtd"
    }
}
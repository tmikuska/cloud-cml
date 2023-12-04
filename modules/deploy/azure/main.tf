#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

// https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-terraform?tabs=azure-cli

// https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal

// storage account iam
// https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal?tabs=delegate-condition


locals {
  cml = templatefile("${path.module}/../data/cml.sh", {
    cfg = merge(
      var.cfg,
      { sas_token = data.azurerm_storage_account_sas.cml.sas }
    )
    }
  )
  del      = templatefile("${path.module}/../data/del.sh", { cfg = var.cfg })
  copyfile = templatefile("${path.module}/../data/copyfile.sh", { cfg = var.cfg })
}

# this creates a new resource group
# resource "azurerm_resource_group" "cml" {
#   name     = "cml-east-us"
#   location = "eastus"
# }

# this references an existing resource group
data "azurerm_resource_group" "cml" {
  name = var.cfg.azure.resource_group
  # name = "cml-east-us"
}

data "azurerm_storage_account" "cml" {
  # name                = "cmlrefplatsoftware"
  name                = var.cfg.azure.storage_account
  resource_group_name = data.azurerm_resource_group.cml.name
  # location                 = data.azurerm_resource_group.cml.location
  # account_tier             = "Standard"
  # account_replication_type = "GRS"
  #
  # tags = {
  #   environment = "staging"
  # }
}


data "azurerm_storage_account_sas" "cml" {
  connection_string = data.azurerm_storage_account.cml.primary_connection_string
  https_only        = true
  # signed_version    = "2017-07-29"
  signed_version = "2022-11-02"

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "1h")

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = true
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

resource "azurerm_network_security_group" "cml" {
  name                = "cml-sg-1"
  location            = data.azurerm_resource_group.cml.location
  resource_group_name = data.azurerm_resource_group.cml.name

  security_rule {
    name                       = "allow22in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow1122in"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1122"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow443in"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "test9090in"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}


resource "azurerm_public_ip" "cml" {
  name                = "cml-pub-ip-1"
  resource_group_name = data.azurerm_resource_group.cml.name
  location            = data.azurerm_resource_group.cml.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}


resource "azurerm_virtual_network" "cml" {
  name                = "cml-network"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.cml.location
  resource_group_name = data.azurerm_resource_group.cml.name
}

resource "azurerm_subnet" "cml" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.cml.name
  virtual_network_name = azurerm_virtual_network.cml.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "cml" {
  name                = "cml-nic"
  location            = data.azurerm_resource_group.cml.location
  resource_group_name = data.azurerm_resource_group.cml.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cml.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cml.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "cml" {
  network_interface_id      = azurerm_network_interface.cml.id
  network_security_group_id = azurerm_network_security_group.cml.id
}

resource "azurerm_linux_virtual_machine" "cml" {
  name                = "cml-machine"
  resource_group_name = data.azurerm_resource_group.cml.name
  location            = data.azurerm_resource_group.cml.location

  # size                = "Standard_F2"
  # https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization
  # https://learn.microsoft.com/en-us/azure/virtual-machines/dv5-dsv5-series
  # Size	vCPU	Memory: GiB	Temp storage (SSD) GiB	Max data disks	Max NICs	Max network bandwidth (Mbps)
  # Standard_D2_v5	2	8	Remote Storage Only	4	2	12500
  # Standard_D4_v5	4	16	Remote Storage Only	8	2	12500
  # Standard_D8_v5	8	32	Remote Storage Only	16	4	12500
  # Standard_D16_v5	16	64	Remote Storage Only	32	8	12500
  # Standard_D32_v5	32	128	Remote Storage Only	32	8	16000
  # Standard_D48_v5	48	192	Remote Storage Only	32	8	24000
  # Standard_D64_v5	64	256	Remote Storage Only	32	8	30000
  # Standard_D96_v5	96	384	Remote Storage Only	32	8	35000
  #
  # https://learn.microsoft.com/en-us/azure/virtual-machines/ddv4-ddsv4-series
  # Size	vCPU	Memory: GiB	Temp storage (SSD) GiB	Max data disks	Max temp storage throughput: IOPS/MBps*	Max NICs	Expected network bandwidth (Mbps)
  # Standard_D2d_v41	2	8	75	4	9000/125	2	5000
  # Standard_D4d_v4	4	16	150	8	19000/250	2	10000
  # Standard_D8d_v4	8	32	300	16	38000/500	4	12500
  # Standard_D16d_v4	16	64	600	32	75000/1000	8	12500
  # Standard_D32d_v4	32	128	1200	32	150000/2000	8	16000
  # Standard_D48d_v4	48	192	1800	32	225000/3000	8	24000
  # Standard_D64d_v4	64	256	2400	32	300000/4000	8	30000

  size = "Standard_D4d_v4"
  # size = "Standard_D4_v5"

  admin_username = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.cml.id,
  ]

  admin_ssh_key {
    username = "adminuser"
    # public_key = file("~/.ssh/id_rsa.pub")
    public_key = data.azurerm_ssh_public_key.cml.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/../data/userdata.txt", {
    cfg      = var.cfg
    cml      = local.cml
    del      = local.del
    copyfile = local.copyfile
    path     = path.module
  }))

}

data "azurerm_ssh_public_key" "cml" {
  name                = "rschmied-key"
  resource_group_name = data.azurerm_resource_group.cml.name
}

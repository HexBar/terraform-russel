resource "azurerm_resource_group" "WeightTracker" {
  name     = format("%s-%s", var.resource_group_abbv, var.project_name)
  location = "West Europe"
}



resource "azurerm_virtual_network" "virtual_network" {
  name                = var.virtual_network_name
  resource_group_name = azurerm_resource_group.WeightTracker.name
  address_space       = ["10.0.0.0/16"]
  location            = "West Europe"
}


resource "azurerm_subnet" "subnet_web" {
  name                 = var.subnet_web_name
  resource_group_name  = azurerm_resource_group.WeightTracker.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_network_security_group" "nsg_web" {
  name                = var.nsg_web_name
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.WeightTracker.name

  security_rule {
    name                       = "Allow_Web_Port_8080"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }




  security_rule {
    name                       = "Allow_Web_Port_80"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


  security_rule {
    name                       = "Allow_Web_Port_5000"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_Web_Subnet_SSH"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "176.230.143.97"
    destination_address_prefix = "*"
  }
}


resource "azurerm_subnet" "subnet_db" {
  name                 = var.subnet_db_name
  resource_group_name  = azurerm_resource_group.WeightTracker.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_network_security_group" "nsg_db" {
  name                = var.nsg_db_name
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.WeightTracker.name

  security_rule {
    name                       = "Allow_DB_Subnet_Inbound"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.0.2.0"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_DB_Subnet_SSH"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "176.230.143.97"
    destination_address_prefix = "*"
  }
}


resource "azurerm_public_ip" "public_ip_db" {
  name                = "public-ip-db-prod"  
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.WeightTracker.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic_db" {
  name                = "nic-db-prod"
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.WeightTracker.name

  ip_configuration {
    name                          = "ipconfig-db-private"
    subnet_id                     = azurerm_subnet.subnet_db.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10" 
    primary                       = true
  }

  ip_configuration {
    name                          = "ipconfig-db-public"
    subnet_id                     = azurerm_subnet.subnet_db.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_db.id
  }
}



resource "azurerm_virtual_machine" "db_vm" {
  name                  = "vm-db-prod"
  location              = "West Europe"
  resource_group_name   = azurerm_resource_group.WeightTracker.name
  network_interface_ids = [azurerm_network_interface.nic_db.id]
  vm_size               = "Standard_B2s"

  storage_os_disk {
    name              = "osdisk-db"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "vm-db-prod"
    admin_username = "bar"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/bar/.ssh/authorized_keys"
      key_data = var.db_ssh_public_key
    }
  }

  

  provisioner "remote-exec" {
    connection {
      host        = azurerm_public_ip.public_ip_db.ip_address
      type        = "ssh"
      user        = "bar"
      private_key = file("C:/Users/bar/terraformkeys/db-ssh-key")
    }

    inline = [
    "sudo apt-get update",
    "sudo apt-get install -y postgresql postgresql-client",
    "sudo service postgresql start",
    "sleep 10",
    "sudo sed -i '/^# IPv4 local connections:/a host    all             all             10.0.2.0/24             trust' /etc/postgresql/10/main/pg_hba.conf",
    "sudo sed -i \"s/^#listen_addresses = .*$/listen_addresses = '*'/\" /etc/postgresql/10/main/postgresql.conf",
    "sudo service postgresql restart",
    "sudo -u postgres psql -c \"CREATE USER bar WITH SUPERUSER PASSWORD '${var.db_password}';\"",
    "sudo -u postgres psql -c \"CREATE DATABASE weighttrackerdb;\"",
    "sudo -u postgres psql -d weighttrackerdb -c \"CREATE TABLE data (name VARCHAR, weight_value INTEGER, mytime TIMESTAMP);\"",
    "sudo -u postgres psql -c \"\\q\"",
    "sudo service postgresql restart",
    "psql -U shachar -d weighttrackerdb;"
 ]
}

  storage_data_disk {
    name              = "datadisk-db"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    disk_size_gb      = 4
    lun               = 1
  }
}


data "template_file" "app_py" {
  template = file("${path.module}/app.py")

}





resource "azurerm_public_ip" "public_ip_web" {
  name                = "public-ip-web"
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.WeightTracker.name
  allocation_method   = "Static"
}


resource "azurerm_network_interface" "nic_web" {
  name                = "nic-web"
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.WeightTracker.name

  ip_configuration {
    name                          = "ipconfig-web"
    subnet_id                     = azurerm_subnet.subnet_web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_web.id
  }
}



resource "azurerm_virtual_machine" "web_vm" {
  name                  = "vm-webapp-prod"
  location              = "West Europe"
  resource_group_name   = azurerm_resource_group.WeightTracker.name
  network_interface_ids = [azurerm_network_interface.nic_web.id]
  vm_size               = "Standard_B2s"

  storage_os_disk {
    name              = "osdisk-web"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "vm-webapp-prod"
    admin_username = "shachar"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/bar/.ssh/authorized_keys"
      key_data = var.web_ssh_public_key
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = azurerm_public_ip.public_ip_web.ip_address
      type        = "ssh"
      user        = "shachar"
      private_key = file("C:/Users/bar/terraformkeys/web-ssh-key")
    }

    inline = [
    "sudo apt-get update",
      "sudo apt-get install -y python3-pip",
      "sudo -H pip3 install --upgrade pip",
      "sudo -H pip3 install flask flask-cors psycopg2-binary",
      "echo 'export DB_PASSWORD=\"${var.db_password}\"' >> ~/.bashrc",
      "echo '${data.template_file.app_py.rendered}' >> app.py",
      "python3 app.py",
   ]
  }
  

  storage_data_disk {
    name              = "datadisk-web"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    disk_size_gb      = 4
    lun               = 1
  }
}

variable project_name {
  type = string
  description = "resource group name"
  default = "WeightTracker"
}

variable resource_group_abbv {
  type = string 
  description = "resource group abrevaition"
  default= "rg"
}


variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group"
  default= "rg-WeightTracker"
}

variable "virtual_network_name" {
  type        = string
  description = "Name of the Azure virtual network"
  default= "vnet-WeightTracker"
}

variable "subnet_web_name" {
  type        = string
  description = "Name of the web subnet"
  default= "snet-web"
}

variable "subnet_db_name" {
  type        = string
  description = "Name of the database subnet"
  default= "snet-db"
}

variable "nsg_web_name" {
  type        = string
  description = "Name of the web network security group"
  default= "nsg-web"
}

variable "nsg_db_name" {
  type        = string
  description = "Name of the database network security group"
  default= "nsg-db"
}




variable "web_ssh_public_key" {
  type        = string
  description = "SSH public key for web VM"
  default= ""
}

variable "db_ssh_public_key" {
  type        = string
  description = "SSH public key for database VM"
  default= ""
}

variable "db_password" {
  type        = string
  description = "Password for the database user"
  default= ""
}

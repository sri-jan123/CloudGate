terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tf_backend"
    storage_account_name = "tfbackend0122"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
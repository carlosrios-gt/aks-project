terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-aks-devops-cr"
  location = "eastus"
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-devops-cr"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-devops-cr"

  default_node_pool {
    name       = "system"
    node_count = 1
    vm_size    = "Standard_D2as_v7"
    os_sku     = "Ubuntu"
  }

  linux_profile {
    admin_username = "azureuser"

    ssh_key {
      key_data = file("./aks-devops_rsa.pub")
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "kube_admin_config" {
  value     = azurerm_kubernetes_cluster.main.kube_admin_config_raw
  sensitive = true
}
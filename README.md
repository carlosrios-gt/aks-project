AKS con Terraform

Usar la cuenta de Azure que tiene crédito activo.
1. Crear carpeta y entrar
cd $HOME\Documents
mkdir aks-project
cd aks-project

2. Revisar herramientas y entrar a Azure
az version
terraform version
kubectl version --client
git --version

az login
az account show --output table

Verificar que todo esté instalado y entras a tu suscripción de Azure.
3. Guardar variables
$LOCATION = "eastus"
$RG_NAME = "rg-aks-devops-cr"
$AKS_NAME = "aks-devops-cr"
$DNS_PREFIX = "aks-devops-cr"
$SP_NAME = "sp-aks-devops-cr"

$SUBSCRIPTION_ID = az account show --query id -o tsv
$TENANT_ID = az account show --query tenantId -o tsv

Definir nombres para no escribirlos manualmente en cada comando.
4. Habilitar servicios necesarios de Azure
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.ManagedIdentity --wait

5. Crear permisos para Terraform
$SUBSCRIPTION_ID = az account show --query id -o tsv
$TENANT_ID = az account show --query tenantId -o tsv

$SP_NAME = "sp-aks-devops-cr"

$SP_JSON = az ad sp create-for-rbac `
  --name $SP_NAME `
  --role Contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID" `
  --output json | ConvertFrom-Json

$env:ARM_CLIENT_ID = $SP_JSON.appId
$env:ARM_CLIENT_SECRET = $SP_JSON.password
$env:ARM_TENANT_ID = $TENANT_ID
$env:ARM_SUBSCRIPTION_ID = $SUBSCRIPTION_ID

Crear un Service Principal para que Terraform pueda crear recursos en Azure.
6. Crear llave SSH
ssh-keygen -t rsa -b 4096 -f .\aks-devops_rsa
7. Crear main.tf
Primero abre el archivo:
notepad main.tf

->  main.tf <-
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
    vm_size    = "Standard_D2as_v7" (F16a_v7)
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


Definir con Terraform el Resource Group y el cluster AKS.
8. Crear el cluster con Terraform
## Si da error de creacion de llave, crearla en el proyecto
cd "C:\Users\Carlos Rios\Documents\aks-project"
Remove-Item .\aks-devops_rsa* -Force -ErrorAction SilentlyContinue
ssh-keygen -t rsa -b 4096 -f .\aks-devops_rsa
Test-Path .\aks-devops_rsa.pub   Debe salir TRUE
-------------
terraform init
terraform fmt
terraform validate
terraform plan -out aks.tfplan
terraform apply aks.tfplan

--------------
## En caso de error revisar si Terraform tiene recursos creados
terraform state list
terraform fmt
terraform validate
terraform plan -out aks.tfplan

PASO 8
terraform apply aks.tfplan


Terraform crea los recursos en Azure. Puede tardar varios minutos.
9. Conectar kubectl al cluster
# Verificar existencia de cluster
az aks list --resource-group rg-aks-devops-cr --output table
az aks get-credentials --resource-group rg-aks-devops-cr --name aks-devops-cr --admin --overwrite-existing
kubectl config current-context
kubectl get nodes

# Crear el kubeconfig
terraform output -raw kube_admin_config | Out-File -FilePath .\kubeconfig -Encoding utf8
Test-Path .\kubeconfig

az aks get-credentials --resource-group rg-aks-devops-cr --name aks-devops-cr --admin --file .\kubeconfig --overwrite-existing
terraform output -raw kube_admin_config | Set-Content -Path .\kubeconfig -Encoding utf8

Debe dar TRUE
---------------
$env:KUBECONFIG = (Resolve-Path .\kubeconfig).Path

kubectl get nodes

Evidencia importante: kubectl get nodes debe mostrar el nodo del cluster en estado Ready.
10. Crear nginx.yaml
mkdir k8s
notepad .\k8s\nginx.yaml

Pega esto dentro de nginx.yaml y guarda:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer
  selector:
    app: nginx-demo
  ports:
  - port: 80
    targetPort: 80

Definir una aplicación nginx y un servicio LoadBalancer para exponerla con IP pública.
11. Desplegar nginx y probar IP
kubectl apply -f .\k8s\nginx.yaml
kubectl get pods
kubectl get svc nginx-service

$EXTERNAL_IP = kubectl get svc nginx-service -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
echo $EXTERNAL_IP

Invoke-WebRequest -Uri "http://$EXTERNAL_IP"
start "http://$EXTERNAL_IP"

Si EXTERNAL-IP sale pending, esperar 1-3 minutos: ejecutar kubectl get svc nginx-service.
12. Crear checklist para la entrega
notepad checklist.md


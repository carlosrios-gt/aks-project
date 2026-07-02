# AKS Project Checklist

1. Environment configured: Azure CLI, Terraform, kubectl, Git, az login.
2. Permissions granted: Service Principal with Contributor role.
3. Resource Group created with Terraform.
4. Storage account: optional, not used.
5. SSH keys created with ssh-keygen -t rsa -b 4096.
6. Terraform script includes azurerm provider, resource group, AKS and kubeconfig output.
7. Terraform executed with init, plan and apply. Cluster verified with kubectl get nodes.
8. Application deployed with Deployment + LoadBalancer Service. External IP tested.


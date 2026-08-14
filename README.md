# Azure Automated Web Cluster: Bicep & Ansible GitOps Pipeline

A high-availability, load-balanced web server cluster deployed entirely through an automated GitOps CI/CD pipeline. 
This project showcases the boundary between Infrastructure as Code (IaC) using Azure Bicep and Configuration Management using Ansible, backed by automated syntax and security scanning.

# Tooling & DevSecOps Stack
-CI/CD Platform: GitHub Actions
-Infrastructure as Code (IaC): Azure & Bicep
-Configuration Management: Ansible (via azure.azcollection dynamic inventory)
-Code Quality & Syntax Scanning: bicep lint and ansible-lint

# Trigger the Deployment
-Commit all files into your repository.
-Push your changes to the main branch: git push origin main.
-Watch the workflow execute under the Actions tab in your GitHub repository.

# Testing High Availability
-Located the Public IP Address of the Azure Load Balancer via the Azure Portal.
-Visited the IP in my browser. I then seen a message highlighting the hostname of the backend server (e.g., Hello from Bicep + Ansible Backend VM: web-vm-1).
-Refresh the page to watch the load balancer distribute traffic across the cluster nodes.

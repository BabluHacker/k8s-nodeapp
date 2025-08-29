#!/bin/bash

# Navigate to terraform directory
cd terraform/

# Initialize Terraform
terraform init

# Format terraform files
terraform fmt

# Validate terraform configuration
terraform validate

# Generate terraform plan and save to file
terraform plan -out=tfplan.binary

# Convert plan to readable format
terraform show -no-color tfplan.binary > terraform-plan-output.txt

# Also create a JSON version for documentation
terraform show -json tfplan.binary > terraform-plan-output.json

# Display the plan
cat terraform-plan-output.txt
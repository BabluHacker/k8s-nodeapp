# Node.js Application Deployment on AWS EKS

## 📋 Table of Contents
- [Architecture Overview](#architecture-overview)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Infrastructure Components](#infrastructure-components)
- [Deployment Instructions](#deployment-instructions)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring and Logging](#monitoring-and-logging)
- [Security Considerations](#security-considerations)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Assumptions](#assumptions)

## 🏗️ Architecture Overview

This project implements a production-ready infrastructure for a Node.js application deployed on Amazon EKS (Elastic Kubernetes Service) with a fully automated CI/CD pipeline.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
            ┌────────────────┐
            │ Load Balancer  │
            │     (NLB)      │
            └────────┬───────┘
                     │
     ┌───────────────┴───────────────┐
     │         AWS VPC (10.0.0.0/16) │
     │  ┌────────────────────────┐  │
     │  │   Public Subnets       │  │
     │  │  ┌──────┐  ┌──────┐   │  │
     │  │  │ NAT  │  │ NAT  │   │  │
     │  │  │ GW-1 │  │ GW-2 │   │  │
     │  │  └──┬───┘  └───┬──┘   │  │
     │  └─────┼──────────┼──────┘  │
     │        │          │          │
     │  ┌─────▼──────────▼──────┐  │
     │  │   Private Subnets      │  │
     │  │  ┌─────────────────┐  │  │
     │  │  │   EKS Cluster   │  │  │
     │  │  │  ┌───────────┐  │  │  │
     │  │  │  │ Node Group│  │  │  │
     │  │  │  │  (t3.med) │  │  │  │
     │  │  │  │  Min: 1   │  │  │  │
     │  │  │  │  Max: 4   │  │  │  │
     │  │  │  └───────────┘  │  │  │
     │  │  └─────────────────┘  │  │
     │  └────────────────────────┘  │
     └───────────────────────────────┘
                     │
                     ▼
            ┌────────────────┐
            │      ECR       │
            │  (Container    │
            │   Registry)    │
            └────────────────┘
```

### Data Flow

1. **Developer** pushes code to GitHub
2. **GitHub Actions** triggered automatically
3. **CI/CD Pipeline** builds Docker image
4. **Docker Image** pushed to Amazon ECR
5. **Helm** deploys application to EKS
6. **LoadBalancer** exposes application to internet
7. **Users** access application via LoadBalancer URL

## 🛠️ Technology Stack

- **Cloud Provider**: AWS (Amazon Web Services)
- **Container Orchestration**: Amazon EKS (Kubernetes v1.29)
- **Infrastructure as Code**: Terraform v1.0+
- **Container Registry**: Amazon ECR
- **Package Manager**: Helm v3
- **CI/CD**: GitHub Actions
- **Application Runtime**: Node.js
- **Load Balancer**: AWS Network Load Balancer (NLB)
- **Monitoring**: CloudWatch, Kubernetes metrics
- **Networking**: AWS VPC with public/private subnets

## 📦 Prerequisites

### Required Tools
- AWS CLI v2.x configured with appropriate credentials
- Terraform >= 1.0
- kubectl >= 1.29
- Helm >= 3.0
- Docker >= 20.10
- Git

### AWS Account Requirements
- IAM user with the following permissions:
   - EKS full access
   - EC2 full access
   - VPC full access
   - IAM role creation
   - ECR full access
   - CloudWatch access
   - KMS access

### Local Environment Setup
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

## 📁 Project Structure

```
nodejs-eks-deployment/
├── .github/
│   └── workflows/
│       └── deploy-prod.yml              # GitHub Actions CI/CD pipeline - branch main
│       └── deploy-staging.yml              # GitHub Actions CI/CD pipeline - branch staging
├── terraform/
│   ├── main.tf                     # Main Terraform configuration
│   ├── variables.tf                # Variable definitions
│   ├── terraform.tfvars           # Variable values
│   ├── outputs.tf                 # Output definitions
│   ├── backend.tf                 # S3 backend configuration
│   └── terraform-plan-output.txt  # Terraform plan output
├── helm/
│   └── nodeapp-k8s-project/
│       ├── Chart.yaml             # Helm chart metadata
│       ├── values.yaml            # Default values
│       ├── values-production.yaml # Production values
│       └── templates/
│           ├── deployment.yaml    # Kubernetes Deployment
│           ├── service.yaml       # Kubernetes Service
│           ├── hpa.yaml          # Horizontal Pod Autoscaler
│           ├── ingress.yaml      # Ingress configuration
│           └── serviceaccount.yaml # Service Account

├── index.js                  # Node.js application
├── package.json              # Node.js dependencies
├── Dockerfile                # Container definition
├── build.sh                  # to build AWS infra using terraform
├── test-deployment.sh        # test current deployments 
└── README.md                 # This file
```

## 🏗️ Infrastructure Components

### Networking
- **VPC**: 10.0.0.0/16 CIDR block
- **Public Subnets**: 2 subnets for NAT Gateways and Load Balancer
- **Private Subnets**: 2 subnets for EKS worker nodes
- **NAT Gateways**: 2 for high availability
- **Internet Gateway**: For public subnet internet access
- **Route Tables**: Separate for public and private subnets

### Compute
- **EKS Cluster**: Managed Kubernetes v1.29
- **Node Group**:
   - Instance Type: t3.medium
   - Min Size: 1
   - Max Size: 4
   - Desired Size: 2

### Storage
- **ECR Repository**: For Docker images
- **S3 Bucket**: For Terraform state

### Security
- **IAM Roles**:
   - EKS Cluster Role
   - EKS Node Group Role
- **Security Groups**:
   - EKS Cluster Security Group
   - EKS Nodes Security Group
- **KMS**: For EKS secrets encryption

## 📝 Deployment Instructions

### Step 1: Clone Repository
```bash
git clone git@github.com:BabluHacker/k8s-nodeapp.git
cd k8s-nodeapp
```

### Step 2: Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
# Enter output format: json
```

### Step 3: Create S3 Backend for Terraform State
```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
    --bucket nodejs-app-terraform-state-enosis \
    --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-east-1
```

### Step 4: Deploy Infrastructure with Terraform
```bash
cd terraform/

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply -auto-approve

# Save outputs
terraform output > terraform-outputs.txt
```

### Step 5: Configure kubectl
```bash
# Update kubeconfig
aws eks update-kubeconfig --name nodejs-app-cluster --region us-east-1

# Verify connection
kubectl get nodes
```

### Step 6: Initial Manual Deployment (Optional)
```bash
# Build and push Docker image manually
cd ../nodejs-app/
docker build -t nodejs-app .

# Get ECR repository URL
ECR_URL=$(terraform -chdir=../terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Tag and push image
docker tag nodejs-app:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Deploy with Helm
cd ../helm/
helm install nodeapp ./nodeapp-k8s-project \
    --namespace production \
    --create-namespace \
    --set image.repository=$ECR_URL:latest \
    --set service.type=LoadBalancer
```

### Step 7: Setup GitHub Actions
```bash
# Add GitHub Secrets
# Go to GitHub repository → Settings → Secrets and variables → Actions
# Add the following secrets:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY

# Push code to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main
```

### Step 8: Access Application
```bash
# Get LoadBalancer URL
kubectl get svc -n production

# Access application
curl http://<LOAD_BALANCER_URL>:3000
```

## 🔄 CI/CD Pipeline

### Pipeline Stages

1. **Checkout Code**: Pull latest code from repository
2. **Configure AWS**: Setup AWS credentials
3. **Login to ECR**: Authenticate with container registry
4. **Build & Push**: Build Docker image and push to ECR
5. **Setup Tools**: Install kubectl and Helm
6. **Update Kubeconfig**: Configure cluster access
7. **Deploy**: Deploy application using Helm
8. **Verify**: Check deployment status and get URL

### Triggering Deployments

Deployments are triggered automatically on:
- Push to `main` branch
- Push to `develop` branch
- Pull requests to `main` branch

### Manual Deployment
```bash
# Using GitHub CLI
gh workflow run deploy.yml

# Or push a tag
git tag v1.0.0
git push origin v1.0.0
```

## 📊 Monitoring and Logging

### CloudWatch Container Insights
```bash
# Enable Container Insights
aws eks update-cluster-config \
    --name nodejs-app-cluster \
    --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

### Application Metrics
- CPU Utilization
- Memory Usage
- Request Count
- Response Time
- Error Rate

### Viewing Logs
```bash
# View pod logs
kubectl logs -n production -l app.kubernetes.io/name=nodeapp-k8s-project

# Stream logs
kubectl logs -n production -l app.kubernetes.io/name=nodeapp-k8s-project -f

# View previous container logs
kubectl logs -n production <pod-name> --previous
```

## 🔒 Security Considerations

### Best Practices Implemented

1. **Network Security**
   - Private subnets for worker nodes
   - Security groups with minimal required ports
   - Network segmentation

2. **Access Control**
   - IAM roles with least privilege
   - RBAC for Kubernetes access
   - Service accounts for pods

3. **Data Protection**
   - Encryption at rest using KMS
   - Encrypted secrets in Kubernetes
   - TLS for data in transit

4. **Container Security**
   - Non-root user in containers
   - Read-only root filesystem where possible
   - Resource limits to prevent DoS
   - Image scanning in ECR

5. **Compliance**
   - CloudWatch logging enabled
   - Audit logs for EKS cluster
   - Version control for all configurations

### Security Checklist
- ✅ Private EKS endpoint enabled
- ✅ Public access restricted to specific IPs (configurable)
- ✅ Secrets encrypted with KMS
- ✅ ECR image scanning enabled
- ✅ Pod security context configured
- ✅ Network policies (can be added)
- ✅ Resource quotas and limits

## 💰 Cost Optimization

### Current Setup Costs (Estimated Monthly)
- **EKS Cluster**: $72 (0.10/hour)
- **EC2 Instances**: ~$67 (2x t3.medium)
- **NAT Gateways**: ~$90 (2x $45)
- **Load Balancer**: ~$25
- **ECR Storage**: ~$1
- **Total**: ~$255/month

### Cost Optimization Strategies

1. **Use Spot Instances** for non-critical workloads
2. **Implement Cluster Autoscaler** to scale nodes based on demand
3. **Use single NAT Gateway** for dev/test environments
4. **Schedule dev/test clusters** to run only during business hours
5. **Right-size instances** based on actual usage metrics
6. **Use Reserved Instances** for predictable workloads

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Pods Not Starting
```bash
# Check pod status
kubectl get pods -n production
kubectl describe pod <pod-name> -n production

# Common solutions:
# - Check image pull secrets
# - Verify ECR permissions
# - Check resource limits
```

#### 2. LoadBalancer No External IP
```bash
# Check service status
kubectl describe svc nodeapp-nodeapp-k8s-project -n production

# Wait for provisioning (2-3 minutes)
# Check AWS console for Load Balancer status
```

#### 3. Cannot Connect to Cluster
```bash
# Update kubeconfig
aws eks update-kubeconfig --name nodejs-app-cluster --region us-east-1

# Check cluster status
aws eks describe-cluster --name nodejs-app-cluster --query cluster.status
```

#### 4. Terraform State Lock
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

#### 5. GitHub Actions Failing
- Check AWS credentials in GitHub Secrets
- Verify IAM permissions
- Check ECR repository exists
- Review action logs for specific errors

## 📌 Assumptions

1. **AWS Account**: Fresh AWS account or sufficient permissions
2. **Region**: Deployment in us-east-1 (Northern Virginia)
3. **Domain**: No custom domain required (using LoadBalancer URL)
4. **SSL/TLS**: Not required for this demo (can be added)
5. **Database**: Application doesn't require persistent storage
6. **Secrets**: No application-specific secrets required
7. **Monitoring**: Basic CloudWatch monitoring is sufficient
8. **Backup**: No backup strategy required for stateless app
9. **Multi-region**: Single region deployment is sufficient
10. **Authentication**: No authentication required for the app

## 🚀 Future Enhancements

1. **Add Custom Domain** with Route53 and ACM certificates
2. **Implement Blue-Green Deployments** for zero-downtime updates
3. **Add Prometheus and Grafana** for advanced monitoring
4. **Implement GitOps** with ArgoCD or Flux
5. **Add Istio Service Mesh** for advanced traffic management
6. **Implement Backup Strategy** using Velero
7. **Add Network Policies** for micro-segmentation
8. **Implement Pod Security Policies**
9. **Add Horizontal Cluster Autoscaler**
10. **Multi-region Deployment** for disaster recovery

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Check GitHub Actions logs
4. Review AWS documentation

## 📄 License

This project is created for demonstration purposes.

---
**Last Updated**: December 2024
**Version**: 1.0.0
**Author**: DevOps Team
#!/bin/bash
set -e

# Configuration - change these as needed
CLUSTER_NAME="wordpress-cluster"
REGION="us-east-1"
NODE_GROUP_NAME="wordpress-nodes"
INSTANCE_TYPE="t3.medium"
MIN_NODES=2
MAX_NODES=5
DESIRED_NODES=2
ECR_REPOSITORY_NAME="wordpress"

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting."; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo "eksctl is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting."; exit 1; }

echo "====== Setting up EKS Cluster ======"

# Create EKS cluster
echo "Creating EKS cluster (this may take 15-20 minutes)..."
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --nodegroup-name $NODE_GROUP_NAME \
  --node-type $INSTANCE_TYPE \
  --nodes-min $MIN_NODES \
  --nodes-max $MAX_NODES \
  --nodes $DESIRED_NODES \
  --with-oidc \
  --ssh-access \
  --ssh-public-key ~/.ssh/id_rsa.pub \
  --managed

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

echo "====== Setting up ECR Repository ======"

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $REGION >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $REGION

# Get the ECR repository URI
ECR_REPOSITORY_URI=$(aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $REGION --query 'repositories[0].repositoryUri' --output text)
echo "ECR Repository URI: $ECR_REPOSITORY_URI"

echo "====== Building and Pushing Docker Image ======"

# Authenticate Docker to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI

# Build Docker image
docker build -t $ECR_REPOSITORY_NAME:latest .

# Tag and push the image
docker tag $ECR_REPOSITORY_NAME:latest $ECR_REPOSITORY_URI:latest
docker push $ECR_REPOSITORY_URI:latest

echo "====== Deploying WordPress to EKS ======"

# Update the Kubernetes manifests with the ECR repository URI
sed -i "s|\${ECR_REPOSITORY_URI}|$ECR_REPOSITORY_URI|g" kubernetes/wordpress.yaml

# Apply the Kubernetes manifests
kubectl apply -f kubernetes/wordpress.yaml

echo "====== Deployment Complete ======"

# Wait for WordPress to be ready
echo "Waiting for WordPress LoadBalancer to be provisioned..."
sleep 30
kubectl wait --namespace wordpress --for=condition=ready pod -l app=wordpress --timeout=300s

# Get the LoadBalancer URL
WORDPRESS_URL=$(kubectl get svc wordpress -n wordpress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "WordPress is now available at: http://$WORDPRESS_URL"
echo "You can complete the WordPress installation by visiting this URL."

echo "====== Monitoring Commands ======"
echo "To check the status of your pods:"
echo "  kubectl get pods -n wordpress"
echo "To check the services:"
echo "  kubectl get svc -n wordpress"
echo "To check the persistent volume claims:"
echo "  kubectl get pvc -n wordpress"
echo "To view logs for WordPress:"
echo "  kubectl logs -n wordpress -l app=wordpress"
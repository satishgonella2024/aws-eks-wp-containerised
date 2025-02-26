#!/bin/bash
set -e

# Get the ECR repository URI
ECR_REPOSITORY_URI=$(aws ecr describe-repositories --repository-names wordpress --region us-east-1 --query 'repositories[0].repositoryUri' --output text)
echo "ECR Repository URI: $ECR_REPOSITORY_URI"

# Replace the placeholder in the YAML
cat kubernetes/wordpress-simple.yaml | sed "s|\${ECR_REPOSITORY_URI}|$ECR_REPOSITORY_URI|g" > kubernetes/wordpress-simple-updated.yaml

# Make sure the WordPress namespace is deleted
kubectl delete namespace wordpress --ignore-not-found=true

# Wait for namespace to be fully deleted
echo "Waiting for namespace to be fully deleted..."
sleep 10

# Apply the simplified deployment
echo "Applying simplified WordPress deployment..."
kubectl apply -f kubernetes/wordpress-simple-updated.yaml

# Wait for the deployment to complete
echo "Waiting for pods to start..."
sleep 20

# Check pod status
kubectl get pods -n wordpress

# Wait for WordPress service to get external IP
echo "Waiting for LoadBalancer to be provisioned..."
sleep 30

# Get the WordPress URL
WORDPRESS_URL=$(kubectl get svc wordpress -n wordpress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "WordPress will be available at: http://$WORDPRESS_URL"
echo "Note: It may take a few minutes for the external IP to be fully provisioned and for WordPress to initialize."

echo "====== Deployment Complete ======"
echo "To check the status of your pods:"
echo "  kubectl get pods -n wordpress"
echo "To check the services:"
echo "  kubectl get svc -n wordpress"
echo "To view logs for WordPress:"
echo "  kubectl logs -n wordpress -l app=wordpress"
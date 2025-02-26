# WordPress on EKS

This project demonstrates how to containerize WordPress and deploy it to Amazon EKS (Elastic Kubernetes Service).

## Project Structure

- `Dockerfile` - Container definition for WordPress
- `docker-compose.yml` - Local development setup
- `kubernetes/` - Kubernetes manifests for EKS deployment
- `scripts/` - Deployment and utility scripts

## Prerequisites

- AWS CLI
- eksctl
- kubectl
- Docker

## Local Development

To test WordPress locally:

```bash
docker-compose up -d
```

Access WordPress at http://localhost:8080

## EKS Deployment

1. Configure AWS credentials:
   ```bash
   aws configure
   ```

2. Run the deployment script:
   ```bash
   ./scripts/eks-deploy.sh
   ```

3. Access WordPress using the LoadBalancer URL provided at the end of the deployment.

## Architecture

This deployment includes:

- WordPress running on Apache with PHP 8.1
- MySQL 8.0 database
- Persistent storage for both WordPress content and database
- Horizontal Pod Autoscaler for handling traffic spikes
- LoadBalancer for accessing the WordPress site

## Customization

You can modify the configuration parameters in `scripts/eks-deploy.sh` to adjust:

- Cluster region
- Instance type
- Number of nodes
- Storage size

## Cleanup

To delete the EKS cluster and all resources:

```bash
eksctl delete cluster --name wordpress-cluster --region us-west-2
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

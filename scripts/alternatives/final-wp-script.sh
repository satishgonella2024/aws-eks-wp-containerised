#!/bin/bash
set -e

# Delete existing resources
echo "Deleting existing WordPress deployment..."
kubectl delete namespace wordpress --ignore-not-found=true

# Wait for namespace to be fully deleted
echo "Waiting for namespace to be fully deleted..."
sleep 10

# Create updated WordPress manifest with explicit storage class
cat > kubernetes/wordpress-final.yaml << 'EOL'
---
# WordPress Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: wordpress
---
# MySQL Secret
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: wordpress
type: Opaque
data:
  # These are base64 encoded values
  root-password: cm9vdF9wYXNzd29yZA==
  password: d29yZHByZXNzX3Bhc3N3b3Jk
---
# MySQL PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: gp2
---
# WordPress PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: gp2
---
# MySQL Deployment (single pod for simplicity)
apiVersion: v1
kind: Pod
metadata:
  name: mysql
  namespace: wordpress
  labels:
    app: mysql
spec:
  containers:
  - image: mysql:5.7
    name: mysql
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-secret
          key: root-password
    - name: MYSQL_DATABASE
      value: wordpress
    - name: MYSQL_USER
      value: wordpress
    - name: MYSQL_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-secret
          key: password
    ports:
    - containerPort: 3306
      name: mysql
    volumeMounts:
    - name: mysql-data
      mountPath: /var/lib/mysql
  volumes:
  - name: mysql-data
    persistentVolumeClaim:
      claimName: mysql-pvc
---
# MySQL Service
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: wordpress
spec:
  ports:
  - port: 3306
  selector:
    app: mysql
---
# WordPress Pod (single pod for simplicity)
apiVersion: v1
kind: Pod
metadata:
  name: wordpress
  namespace: wordpress
  labels:
    app: wordpress
spec:
  containers:
  - image: wordpress:latest
    name: wordpress
    env:
    - name: WORDPRESS_DB_HOST
      value: mysql
    - name: WORDPRESS_DB_USER
      value: wordpress
    - name: WORDPRESS_DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-secret
          key: password
    - name: WORDPRESS_DB_NAME
      value: wordpress
    ports:
    - containerPort: 80
      name: wordpress
    volumeMounts:
    - name: wordpress-data
      mountPath: /var/www/html
  volumes:
  - name: wordpress-data
    persistentVolumeClaim:
      claimName: wordpress-pvc
---
# WordPress Service
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: wordpress
spec:
  ports:
  - port: 80
  selector:
    app: wordpress
  type: LoadBalancer
EOL

echo "Created final WordPress manifest at kubernetes/wordpress-final.yaml"

# Apply the updated deployment
echo "Applying final WordPress deployment..."
kubectl apply -f kubernetes/wordpress-final.yaml

echo "Waiting for pods to initialize (this may take a few minutes)..."
sleep 30

# Check pod status
kubectl get pods -n wordpress
kubectl get pvc -n wordpress

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
echo "To check the persistent volume claims:"
echo "  kubectl get pvc -n wordpress"
echo "To view logs for WordPress:"
echo "  kubectl logs -n wordpress wordpress"
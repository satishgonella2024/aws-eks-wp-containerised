#!/bin/bash
set -e

# Delete existing resources
echo "Deleting existing WordPress deployment..."
kubectl delete namespace wordpress --ignore-not-found=true

# Wait for namespace to be fully deleted
echo "Waiting for namespace to be fully deleted..."
sleep 10

# Create updated WordPress manifest with correct storage settings
cat > kubernetes/wordpress-pvc-fixed.yaml << 'EOL'
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
  volumeMode: Filesystem
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
  volumeMode: Filesystem
---
# MySQL Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: wordpress
spec:
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - image: mysql:8.0
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
        resources:
          limits:
            cpu: 0.5
            memory: 1Gi
          requests:
            cpu: 0.2
            memory: 512Mi
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
  clusterIP: None
---
# WordPress Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
  strategy:
    type: Recreate
  template:
    metadata:
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
          mountPath: /var/www/html/wp-content
        resources:
          limits:
            cpu: 0.5
            memory: 512Mi
          requests:
            cpu: 0.2
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 120
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 60
          periodSeconds: 10
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
---
# Horizontal Pod Autoscaler for WordPress
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: wordpress-hpa
  namespace: wordpress
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: wordpress
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOL

echo "Created WordPress manifest with fixed PVC settings at kubernetes/wordpress-pvc-fixed.yaml"

# Apply the updated deployment
echo "Applying WordPress deployment with fixed PVCs..."
kubectl apply -f kubernetes/wordpress-pvc-fixed.yaml

echo "Waiting for pods to start (this may take a few minutes)..."
sleep 30

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
echo "To check the persistent volume claims:"
echo "  kubectl get pvc -n wordpress"
echo "To view logs for WordPress:"
echo "  kubectl logs -n wordpress -l app=wordpress"
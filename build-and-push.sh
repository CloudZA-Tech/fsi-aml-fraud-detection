#!/bin/bash

set -e

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <region> <account_id> <namespace>"
    echo "Example: $0 eu-west-1 123456789012 cloudza"
    exit 1
fi

REGION=$1
ACCOUNT_ID=$2
NAMESPACE=$3

ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Logging into ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_BASE}

echo "Building and pushing frontend..."
docker build -t ${NAMESPACE}/threatsight360-frontend:latest -f docker/Dockerfile.frontend .
docker tag ${NAMESPACE}/threatsight360-frontend:latest ${ECR_BASE}/${NAMESPACE}/threatsight360-frontend:latest
docker push ${ECR_BASE}/${NAMESPACE}/threatsight360-frontend:latest

echo "Building and pushing backend..."
docker build -t ${NAMESPACE}/threatsight360-backend:latest -f Dockerfile.backend .
docker tag ${NAMESPACE}/threatsight360-backend:latest ${ECR_BASE}/${NAMESPACE}/threatsight360-backend:latest
docker push ${ECR_BASE}/${NAMESPACE}/threatsight360-backend:latest

echo "Building and pushing aml-backend..."
docker build -t ${NAMESPACE}/threatsight360-aml-backend:latest -f Dockerfile.aml-backend .
docker tag ${NAMESPACE}/threatsight360-aml-backend:latest ${ECR_BASE}/${NAMESPACE}/threatsight360-aml-backend:latest
docker push ${ECR_BASE}/${NAMESPACE}/threatsight360-aml-backend:latest

echo "All images built and pushed successfully!"
echo "Frontend: ${ECR_BASE}/${NAMESPACE}/threatsight360-frontend:latest"
echo "Backend: ${ECR_BASE}/${NAMESPACE}/threatsight360-backend:latest"
echo "AML Backend: ${ECR_BASE}/${NAMESPACE}/threatsight360-aml-backend:latest"

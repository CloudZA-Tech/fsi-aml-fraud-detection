# ThreatSight 360 - AWS ECS Fargate Deployment Guide

This guide walks you through deploying the ThreatSight 360 fraud detection platform on AWS ECS Fargate using CloudFormation with an existing VPC.

## Prerequisites

1. **AWS Account** with permissions to create ECS, ALB, IAM, CloudWatch resources
2. **Existing VPC** with 2 public subnets in different availability zones
3. **Docker Images** pushed to Amazon ECR (3 images)
4. **MongoDB Atlas** cluster with connection string and indexes configured
5. **AWS Bedrock** access with Claude 3 Sonnet enabled

## Architecture

- **Frontend** (Next.js) - Port 3000
- **Backend** (FastAPI) - Port 8000 - Fraud Detection
- **AML Backend** (FastAPI) - Port 8001 - Entity Resolution & Compliance
- **ALB** with path-based routing: `/` → Frontend, `/api/*` → Backend, `/aml/*` → AML Backend

## Step 1: Build and Push Docker Images to ECR

### Create ECR Repositories

```bash
aws ecr create-repository --repository-name threatsight360-frontend
aws ecr create-repository --repository-name threatsight360-backend
aws ecr create-repository --repository-name threatsight360-aml-backend
```

### Authenticate Docker to ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### Build and Push Images

```bash
# Frontend
docker build -f docker/Dockerfile.frontend -t threatsight360-frontend .
docker tag threatsight360-frontend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/threatsight360-frontend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/threatsight360-frontend:latest

# Backend (Fraud Detection)
docker build -f Dockerfile.backend -t threatsight360-backend .
docker tag threatsight360-backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/threatsight360-backend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/threatsight360-backend:latest

# AML Backend
docker build -f Dockerfile.aml-backend -t threatsight360-aml-backend .
docker tag threatsight360-aml-backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/threatsight360-aml-backend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/threatsight360-aml-backend:latest
```

## Step 2: Prepare MongoDB Atlas

Ensure your MongoDB Atlas cluster has these indexes configured:

- `transaction_vector_index` on `transactions` collection
- `entity_resolution_search` on `entities` collection
- `entity_text_search_index` on `entities` collection
- `entity_vector_search_index` on `entities` collection

See main README.md for detailed index definitions.

## Step 3: Deploy CloudFormation Stack

### Option A: HTTP Only (Quick Demo)

Leave ACM and DNS parameters empty for HTTP-only deployment.

### Option B: HTTPS with Custom Domain

**Prerequisites:**
1. ACM certificate in the same region as deployment
2. Route53 hosted zone for your domain

**Get ACM Certificate ARN:**
```bash
aws acm list-certificates --region us-east-1
```

**Get Hosted Zone ID:**
```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='example.com.'].Id" --output text
```

### Using AWS Console

1. Navigate to CloudFormation in AWS Console
2. Click "Create Stack" → "With new resources"
3. Upload `cloudformation-ecs-fargate.yaml`
4. Fill in parameters:
   - **MongoDBURI**: `mongodb+srv://user:pass@cluster.mongodb.net/`
   - **MongoDBName**: `fsi-threatsight360`
   - **AWSBedrockAccessKey**: Your AWS access key
   - **AWSBedrockSecretKey**: Your AWS secret key
   - **AWSBedrockRegion**: `us-east-1`
   - **FrontendImage**: ECR URI for frontend
   - **BackendImage**: ECR URI for backend
   - **AMLBackendImage**: ECR URI for AML backend
   - **VpcId**: Your existing VPC ID
   - **PublicSubnet1Id**: First public subnet ID
   - **PublicSubnet2Id**: Second public subnet ID (different AZ)
5. Click through to create the stack

### Using AWS CLI

Create `parameters.json`:

```json
[
  {
    "ParameterKey": "MongoDBURI",
    "ParameterValue": "mongodb+srv://user:pass@cluster.mongodb.net/"
  },
  {
    "ParameterKey": "MongoDBName",
    "ParameterValue": "fsi-threatsight360"
  },
  {
    "ParameterKey": "AWSBedrockAccessKey",
    "ParameterValue": "YOUR_ACCESS_KEY"
  },
  {
    "ParameterKey": "AWSBedrockSecretKey",
    "ParameterValue": "YOUR_SECRET_KEY"
  },
  {
    "ParameterKey": "AWSBedrockRegion",
    "ParameterValue": "us-east-1"
  },
  {
    "ParameterKey": "FrontendImage",
    "ParameterValue": "123456789012.dkr.ecr.us-east-1.amazonaws.com/threatsight360-frontend:latest"
  },
  {
    "ParameterKey": "BackendImage",
    "ParameterValue": "123456789012.dkr.ecr.us-east-1.amazonaws.com/threatsight360-backend:latest"
  },
  {
    "ParameterKey": "AMLBackendImage",
    "ParameterValue": "123456789012.dkr.ecr.us-east-1.amazonaws.com/threatsight360-aml-backend:latest"
  },
  {
    "ParameterKey": "VpcId",
    "ParameterValue": "vpc-xxxxxxxxx"
  },
  {
    "ParameterKey": "PublicSubnet1Id",
    "ParameterValue": "subnet-xxxxxxxxx"
  },
  {
    "ParameterKey": "PublicSubnet2Id",
    "ParameterValue": "subnet-yyyyyyyyy"
  },
  {
    "ParameterKey": "ACMCertificateArn",
    "ParameterValue": "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
  },
  {
    "ParameterKey": "BaseDomainName",
    "ParameterValue": "dev.cloudza.tech"
  },
  {
    "ParameterKey": "SubdomainPrefix",
    "ParameterValue": "threatsight360"
  },
  {
    "ParameterKey": "HostedZoneId",
    "ParameterValue": "Z1234567890ABC"
  }
]
```

Deploy:

```bash
aws cloudformation create-stack \
  --stack-name threatsight360-platform \
  --template-body file://cloudformation-ecs-fargate.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

Monitor:

```bash
aws cloudformation describe-stacks \
  --stack-name threatsight360-platform \
  --query 'Stacks[0].StackStatus'
```

## Step 4: Access the Application

Get the Load Balancer URL:

```bash
aws cloudformation describe-stacks \
  --stack-name threatsight360-platform \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text
```

Access:
- **Frontend**: `https://threatsight360.dev.cloudza.tech` (or `http://<alb-dns-name>` for HTTP)
- **Fraud API Docs**: `https://threatsight360.dev.cloudza.tech/docs`
- **AML API Docs**: `https://threatsight360.dev.cloudza.tech/aml/docs`

**Note**: If using HTTPS, wait 2-3 minutes for DNS propagation after stack creation. The CNAME record `threatsight360.dev.cloudza.tech` will point to the ALB DNS hostname.

## Troubleshooting

### Check Service Status

```bash
aws ecs describe-services \
  --cluster ThreatSight360-Cluster \
  --services threatsight360-frontend threatsight360-backend threatsight360-aml-backend
```

### View Container Logs

```bash
aws logs tail /ecs/threatsight360-frontend --follow
aws logs tail /ecs/threatsight360-backend --follow
aws logs tail /ecs/threatsight360-aml-backend --follow
```

### Common Issues

1. **Tasks not starting**: Check CloudWatch logs for MongoDB connection or Bedrock credential errors
2. **Health checks failing**: Verify MongoDB Atlas network access allows AWS IP ranges
3. **502 Bad Gateway**: Services may still be starting (wait 2-3 minutes)

## Cost Optimization for Demo

**Estimated cost**: ~$0.13/hour or ~$3/day

- Fargate: 3 tasks × 0.5 vCPU × 1GB RAM
- ALB: ~$0.025/hour
- Data Transfer: Minimal

To minimize costs:
1. Stop services when not in use
2. Delete stack after demo

## Cleanup

```bash
aws cloudformation delete-stack --stack-name threatsight360-platform
```

## Production Considerations

For production:
- Use HTTPS with ACM certificate
- Enable ALB access logs
- Implement auto-scaling
- Use AWS Secrets Manager for credentials
- Enable container insights
- Configure backup and DR
- Implement WAF rules

# ThreatSight 360 - Complete Deployment Guide

This comprehensive guide covers deploying the ThreatSight 360 fraud detection platform on AWS ECS Fargate with Cognito authentication.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Build and Push Docker Images](#build-and-push-docker-images)
5. [Configure AWS Cognito](#configure-aws-cognito)
6. [Deploy CloudFormation Stack](#deploy-cloudformation-stack)
7. [Post-Deployment Configuration](#post-deployment-configuration)
8. [Updates and Redeployment](#updates-and-redeployment)
9. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
10. [Production Considerations](#production-considerations)

## Architecture Overview

### Services
- **Frontend** (Next.js) - Port 8080 - User interface with Cognito authentication
- **Fraud Backend** (FastAPI) - Port 8000 - Fraud detection and risk modeling
- **AML Backend** (FastAPI) - Port 8001 - Entity resolution and compliance

### Infrastructure
- **Application Load Balancer** with path-based routing
- **ECS Fargate** for container orchestration
- **Amazon ECR** for Docker image storage
- **AWS Cognito** for user authentication
- **MongoDB Atlas** for data persistence
- **AWS Bedrock** for AI/ML capabilities

### Routing
- `/` → Frontend (with authentication)
- `/api/proxy/fraud/*` → Fraud Backend (proxied through frontend)
- `/api/aml/*` → AML Backend (proxied through frontend)
- `/api/health` → Health check endpoint (no auth required)
- `/api/auth/*` → NextAuth authentication endpoints

## Prerequisites

### Required Services

1. **AWS Account** with permissions for:
   - ECS, ECR, ALB, IAM, CloudWatch, Cognito
   - CloudFormation stack creation

2. **Existing VPC** with:
   - 2 public subnets in different availability zones
   - Internet Gateway attached
   - Route tables configured for public access

3. **MongoDB Atlas** cluster with:
   - Connection string (SRV format)
   - Network access configured for AWS IP ranges
   - Required indexes (see below)

4. **AWS Bedrock** access:
   - Claude 3 Sonnet model enabled
   - Access keys with Bedrock permissions

5. **Development Tools**:
   - Docker Desktop installed and running
   - AWS CLI configured (`aws configure`)
   - Git (for cloning repository)

### MongoDB Atlas Indexes

Ensure these indexes are configured:

**Fraud Detection Database:**
- `transaction_vector_index` on `transactions` collection

**AML Database:**
- `entity_resolution_search` on `entities` collection
- `entity_text_search_index` on `entities` collection  
- `entity_vector_search_index` on `entities` collection
- `transaction_vector_index` on `transactions` collection

See main README.md for detailed index definitions.

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd threatsight360
```

### 2. Create ECR Repositories

```bash
# Set your AWS region and account ID
export AWS_REGION=eu-west-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export NAMESPACE=cloudza  # Your ECR namespace/prefix

# Create repositories
aws ecr create-repository --repository-name ${NAMESPACE}/threatsight360-frontend --region ${AWS_REGION}
aws ecr create-repository --repository-name ${NAMESPACE}/threatsight360-backend --region ${AWS_REGION}
aws ecr create-repository --repository-name ${NAMESPACE}/threatsight360-aml-backend --region ${AWS_REGION}
```

### 3. Set Up AWS Cognito User Pool

#### Create User Pool

1. Go to AWS Console → Cognito → User Pools
2. Click "Create user pool"
3. Configure sign-in options:
   - ✅ Email
   - ✅ Username (optional)
4. Configure security requirements:
   - Password policy: Default or custom
   - MFA: Optional (recommended for production)
5. Configure sign-up experience:
   - Self-registration: Enabled
   - Required attributes: email, name
6. Configure message delivery:
   - Email provider: Cognito (for testing) or SES (for production)
7. Integrate your app:
   - User pool name: `threatsight360-users`
   - App client name: `threatsight360-app`
   - ✅ Generate client secret
8. Review and create

#### Configure App Client

1. Go to your User Pool → App integration → App clients
2. Click on your app client
3. Configure Hosted UI:
   - **Allowed callback URLs:**
     ```
     https://threatsight360.dev.cloudza.tech/api/auth/callback/cognito
     http://localhost:3000/api/auth/callback/cognito
     ```
   - **Allowed sign-out URLs:**
     ```
     https://threatsight360.dev.cloudza.tech
     http://localhost:3000
     ```
   - **OAuth 2.0 grant types:**
     - ✅ Authorization code grant
     - ✅ Implicit grant
   - **OpenID Connect scopes:**
     - ✅ openid
     - ✅ email
     - ✅ profile

#### Save Cognito Configuration

Note these values for later:
- **User Pool ID**: `us-east-1_XXXXXXXXX`
- **App Client ID**: `xxxxxxxxxxxxxxxxxxxx`
- **App Client Secret**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- **Cognito Issuer**: `https://cognito-idp.{region}.amazonaws.com/{user-pool-id}`

## Build and Push Docker Images

### Using the Automated Script

The `build-and-push.sh` script simplifies building and deploying images.

#### Build All Images

```bash
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE}
```

#### Build Specific Image

```bash
# Frontend only (faster for UI changes)
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -t frontend

# Fraud backend only
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -t fraud-backend

# AML backend only
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -t aml-backend
```

#### Build and Auto-Deploy

```bash
# Build and trigger ECS deployment
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -f

# Build specific image and deploy
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -t frontend -f
```

### Manual Build (Alternative)

If you prefer manual control:

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build and push frontend
docker build -f docker/Dockerfile.frontend -t ${NAMESPACE}/threatsight360-frontend .
docker tag ${NAMESPACE}/threatsight360-frontend:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAMESPACE}/threatsight360-frontend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAMESPACE}/threatsight360-frontend:latest

# Build and push fraud backend
docker build -f Dockerfile.backend -t ${NAMESPACE}/threatsight360-backend .
docker tag ${NAMESPACE}/threatsight360-backend:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAMESPACE}/threatsight360-backend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAMESPACE}/threatsight360-backend:latest

# Build and push AML backend
docker build -f Dockerfile.aml-backend -t ${NAMESPACE}/threatsight360-aml-backend .
docker tag ${NAMESPACE}/threatsight360-aml-backend:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAMESPACE}/threatsight360-aml-backend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAMESPACE}/threatsight360-aml-backend:latest
```

## Configure AWS Cognito

See [COGNITO_SETUP.md](COGNITO_SETUP.md) for detailed Cognito configuration and troubleshooting.

### Quick Configuration Checklist

- ✅ User Pool created
- ✅ App Client created with client secret
- ✅ Callback URLs configured: `https://your-domain.com/api/auth/callback/cognito`
- ✅ Sign-out URLs configured: `https://your-domain.com`
- ✅ OAuth 2.0 flows enabled (Authorization code grant)
- ✅ OpenID Connect scopes enabled (openid, email, profile)

## Deploy CloudFormation Stack

### Prepare Parameters

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
    "ParameterKey": "APIKey",
    "ParameterValue": "your-secure-api-key-here"
  },
  {
    "ParameterKey": "CognitoUserPoolId",
    "ParameterValue": "us-east-1_XXXXXXXXX"
  },
  {
    "ParameterKey": "CognitoClientId",
    "ParameterValue": "xxxxxxxxxxxxxxxxxxxx"
  },
  {
    "ParameterKey": "CognitoClientSecret",
    "ParameterValue": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  },
  {
    "ParameterKey": "NextAuthSecret",
    "ParameterValue": "generate-with-openssl-rand-base64-32"
  },
  {
    "ParameterKey": "FrontendImage",
    "ParameterValue": "123456789012.dkr.ecr.eu-west-1.amazonaws.com/cloudza/threatsight360-frontend:latest"
  },
  {
    "ParameterKey": "BackendImage",
    "ParameterValue": "123456789012.dkr.ecr.eu-west-1.amazonaws.com/cloudza/threatsight360-backend:latest"
  },
  {
    "ParameterKey": "AMLBackendImage",
    "ParameterValue": "123456789012.dkr.ecr.eu-west-1.amazonaws.com/cloudza/threatsight360-aml-backend:latest"
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
    "ParameterValue": "arn:aws:acm:eu-west-1:123456789012:certificate/xxxxx"
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

### Generate NextAuth Secret

```bash
openssl rand -base64 32
```

### Deploy Stack

```bash
aws cloudformation create-stack \
  --stack-name threatsight360-platform \
  --template-body file://cloudformation-ecs-fargate.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_IAM \
  --region ${AWS_REGION}
```

### Monitor Deployment

```bash
# Watch stack status
aws cloudformation describe-stacks \
  --stack-name threatsight360-platform \
  --query 'Stacks[0].StackStatus' \
  --region ${AWS_REGION}

# Watch stack events
aws cloudformation describe-stack-events \
  --stack-name threatsight360-platform \
  --region ${AWS_REGION} \
  --max-items 10
```

Deployment typically takes 5-10 minutes.

## Post-Deployment Configuration

### 1. Get Application URL

```bash
aws cloudformation describe-stacks \
  --stack-name threatsight360-platform \
  --query 'Stacks[0].Outputs[?OutputKey==`ApplicationURL`].OutputValue' \
  --output text \
  --region ${AWS_REGION}
```

### 2. Verify Cognito Callback URLs

Ensure the callback URL in Cognito matches your deployed domain:
```
https://threatsight360.dev.cloudza.tech/api/auth/callback/cognito
```

### 3. Create Test User

```bash
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_XXXXXXXXX \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com Name=email_verified,Value=true \
  --temporary-password TempPass123! \
  --region ${AWS_REGION}
```

### 4. Test Application

1. Navigate to `https://threatsight360.dev.cloudza.tech`
2. You should be redirected to the custom sign-in page
3. Click "Sign in with Cognito"
4. Authenticate with Cognito
5. You should be redirected back and signed in

### 5. Verify Health Checks

```bash
curl https://threatsight360.dev.cloudza.tech/api/health
# Should return: {"status":"ok"}
```

## Updates and Redeployment

### Quick Updates

For rapid iteration during development:

```bash
# Update frontend only
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -t frontend -f

# Update fraud backend only
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -t fraud-backend -f

# Update AML backend only
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -t aml-backend -f
```

### Full Redeployment

```bash
# Build all images and deploy
./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} ${NAMESPACE} -f
```

### Manual ECS Service Update

```bash
# Force new deployment without rebuilding images
aws ecs update-service \
  --cluster ThreatSight360-Cluster \
  --service threatsight360-frontend \
  --force-new-deployment \
  --region ${AWS_REGION}
```

### CloudFormation Stack Update

When changing infrastructure or environment variables:

```bash
aws cloudformation update-stack \
  --stack-name threatsight360-platform \
  --template-body file://cloudformation-ecs-fargate.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_IAM \
  --region ${AWS_REGION}
```

## Monitoring and Troubleshooting

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


### Check Service Health

```bash
# Check all services
aws ecs describe-services \
  --cluster ThreatSight360-Cluster \
  --services threatsight360-frontend threatsight360-backend threatsight360-aml-backend \
  --region ${AWS_REGION} \
  --query 'services[*].[serviceName,desiredCount,runningCount,deployments[0].status]' \
  --output table
```

### View Container Logs

```bash
# Frontend logs
aws logs tail /ecs/threatsight360-frontend --follow --region ${AWS_REGION}

# Fraud backend logs
aws logs tail /ecs/threatsight360-backend --follow --region ${AWS_REGION}

# AML backend logs
aws logs tail /ecs/threatsight360-aml-backend --follow --region ${AWS_REGION}
```

### Common Issues

#### 1. Tasks Not Starting

**Symptoms:** ECS tasks fail to start or immediately stop

**Check:**
```bash
aws ecs describe-tasks \
  --cluster ThreatSight360-Cluster \
  --tasks $(aws ecs list-tasks --cluster ThreatSight360-Cluster --service-name threatsight360-frontend --query 'taskArns[0]' --output text) \
  --region ${AWS_REGION}
```

**Common causes:**
- MongoDB connection string incorrect
- AWS Bedrock credentials invalid
- Insufficient IAM permissions
- Image pull errors (check ECR permissions)

#### 2. Health Checks Failing

**Symptoms:** Tasks start but ALB marks them unhealthy

**Check health endpoint:**
```bash
curl https://threatsight360.dev.cloudza.tech/api/health
```

**Common causes:**
- Middleware blocking health check endpoint (should be fixed)
- MongoDB Atlas network access not configured for AWS IPs
- Backend services not responding on correct ports

#### 3. Authentication Not Working

**Symptoms:** Cognito sign-in fails or redirects incorrectly

**Check:**
- Cognito callback URL matches exactly: `https://your-domain.com/api/auth/callback/cognito`
- `NEXTAUTH_URL` environment variable is set correctly
- `NEXTAUTH_SECRET` is generated and set
- Cognito client secret is correct

**Debug:**
```bash
# Check frontend logs for NextAuth errors
aws logs tail /ecs/threatsight360-frontend --follow --region ${AWS_REGION} | grep NextAuth
```

See [COGNITO_SETUP.md](COGNITO_SETUP.md) for detailed troubleshooting.

#### 4. Nonce Mismatch Error

**Symptoms:** `Error [OAuthCallbackError]: nonce mismatch`

**Cause:** Cookie configuration issues in HTTPS environment

**Solution:** Already fixed in latest deployment. Ensure:
- `NEXTAUTH_URL` starts with `https://`
- Cookies are configured with `Secure` flag
- Browser allows third-party cookies

#### 5. 502 Bad Gateway

**Symptoms:** ALB returns 502 error

**Common causes:**
- Services still starting (wait 2-3 minutes)
- Health checks failing
- Security groups blocking traffic
- Target group has no healthy targets

**Check target health:**
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names ThreatSight360-Frontend-TG --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --region ${AWS_REGION}
```

#### 6. WebSocket Connection Failed

**Symptoms:** Model admin panel WebSocket disconnects

**Check:**
- WebSocket path transformation is correct
- ALB supports WebSocket connections (it does by default)
- Security groups allow WebSocket traffic

**Verify:**
```bash
# Check if WebSocket endpoint is accessible
wscat -c wss://threatsight360.dev.cloudza.tech/ws/fraud/models/change-stream
```

### Performance Monitoring

#### CloudWatch Metrics

```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=threatsight360-frontend Name=ClusterName,Value=ThreatSight360-Cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ${AWS_REGION}
```

#### Enable Container Insights

```bash
aws ecs update-cluster-settings \
  --cluster ThreatSight360-Cluster \
  --settings name=containerInsights,value=enabled \
  --region ${AWS_REGION}
```

## Production Considerations

### Security

1. **Use AWS Secrets Manager** for sensitive credentials:
```bash
# Store MongoDB URI
aws secretsmanager create-secret \
  --name threatsight360/mongodb-uri \
  --secret-string "mongodb+srv://user:pass@cluster.mongodb.net/" \
  --region ${AWS_REGION}

# Update task definition to reference secret
```

2. **Enable WAF** for ALB:
```bash
# Create WAF web ACL
aws wafv2 create-web-acl \
  --name threatsight360-waf \
  --scope REGIONAL \
  --default-action Allow={} \
  --region ${AWS_REGION}
```

3. **Restrict Security Groups**:
   - ALB: Only allow 80/443 from internet
   - ECS Tasks: Only allow traffic from ALB
   - MongoDB Atlas: Whitelist specific AWS IP ranges

4. **Enable ALB Access Logs**:
```bash
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn <alb-arn> \
  --attributes Key=access_logs.s3.enabled,Value=true Key=access_logs.s3.bucket,Value=my-logs-bucket \
  --region ${AWS_REGION}
```

### High Availability

1. **Auto Scaling**:
```bash
# Create auto-scaling target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/ThreatSight360-Cluster/threatsight360-frontend \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10 \
  --region ${AWS_REGION}

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/ThreatSight360-Cluster/threatsight360-frontend \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json \
  --region ${AWS_REGION}
```

2. **Multi-AZ Deployment**: Already configured with 2 subnets in different AZs

3. **Database Backups**: Configure MongoDB Atlas automated backups

### Monitoring and Alerting

1. **CloudWatch Alarms**:
```bash
# High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name threatsight360-high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --region ${AWS_REGION}
```

2. **Log Aggregation**: Consider using CloudWatch Logs Insights or third-party tools

3. **Application Performance Monitoring**: Integrate APM tools like New Relic or Datadog

### Cost Optimization

**Current estimated cost**: ~$0.13/hour or ~$95/month

**Optimization strategies:**

1. **Use Fargate Spot** for non-critical workloads (up to 70% savings)
2. **Right-size tasks** based on actual usage
3. **Use Reserved Capacity** for predictable workloads
4. **Enable ALB deletion protection** only in production
5. **Set up budget alerts**:
```bash
aws budgets create-budget \
  --account-id ${AWS_ACCOUNT_ID} \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

### Backup and Disaster Recovery

1. **MongoDB Atlas**: Enable continuous backups with point-in-time recovery
2. **ECR Images**: Enable image scanning and lifecycle policies
3. **CloudFormation Templates**: Version control in Git
4. **Configuration**: Store in AWS Systems Manager Parameter Store

### CI/CD Integration

#### GitHub Actions Example

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-1
      
      - name: Build and deploy
        run: |
          ./build-and-push.sh eu-west-1 ${{ secrets.AWS_ACCOUNT_ID }} cloudza -f
```

#### GitLab CI Example

```yaml
deploy:
  stage: deploy
  image: docker:latest
  services:
    - docker:dind
  script:
    - apk add --no-cache aws-cli bash
    - ./build-and-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID} cloudza -f
  only:
    - main
```

## Cleanup

### Delete Stack

```bash
aws cloudformation delete-stack \
  --stack-name threatsight360-platform \
  --region ${AWS_REGION}
```

### Delete ECR Images

```bash
aws ecr batch-delete-image \
  --repository-name ${NAMESPACE}/threatsight360-frontend \
  --image-ids imageTag=latest \
  --region ${AWS_REGION}

aws ecr batch-delete-image \
  --repository-name ${NAMESPACE}/threatsight360-backend \
  --image-ids imageTag=latest \
  --region ${AWS_REGION}

aws ecr batch-delete-image \
  --repository-name ${NAMESPACE}/threatsight360-aml-backend \
  --image-ids imageTag=latest \
  --region ${AWS_REGION}
```

### Delete ECR Repositories

```bash
aws ecr delete-repository \
  --repository-name ${NAMESPACE}/threatsight360-frontend \
  --force \
  --region ${AWS_REGION}

aws ecr delete-repository \
  --repository-name ${NAMESPACE}/threatsight360-backend \
  --force \
  --region ${AWS_REGION}

aws ecr delete-repository \
  --repository-name ${NAMESPACE}/threatsight360-aml-backend \
  --force \
  --region ${AWS_REGION}
```

## Additional Resources

- [COGNITO_SETUP.md](COGNITO_SETUP.md) - Detailed Cognito configuration and troubleshooting
- [build-and-push.sh](build-and-push.sh) - Automated build and deployment script
- [cloudformation-ecs-fargate.yaml](cloudformation-ecs-fargate.yaml) - Infrastructure as Code template
- [README.md](README.md) - Application overview and features

## Support

For issues or questions:
1. Check CloudWatch logs for error messages
2. Review [COGNITO_SETUP.md](COGNITO_SETUP.md) for authentication issues
3. Verify all prerequisites are met
4. Check AWS service quotas and limits
5. Contact your system administrator

---

**Last Updated:** March 2026  
**Version:** 2.0 (with Cognito integration)

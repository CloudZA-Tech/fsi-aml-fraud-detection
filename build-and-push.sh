#!/bin/bash

set -e

# Default values
BUILD_TARGET="all"
FORCE_REDEPLOY=false
ECS_CLUSTER="ThreatSight360-Cluster"
STACK_NAME="threatsight360-platform"

# Function to display usage
usage() {
    echo "Usage: $0 <region> <account_id> <namespace> [OPTIONS]"
    echo ""
    echo "Required arguments:"
    echo "  region        AWS region (e.g., eu-west-1)"
    echo "  account_id    AWS account ID"
    echo "  namespace     ECR namespace/prefix"
    echo ""
    echo "Options:"
    echo "  -t, --target <image>       Build only specific image (frontend|aml-backend|fraud-backend|all)"
    echo "  -f, --force-redeploy       Force ECS service update after push"
    echo "  -c, --cluster <name>       ECS cluster name (default: ThreatSight360-Cluster)"
    echo "  -s, --stack <name>         CloudFormation stack name (for automatic cluster detection)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 eu-west-1 123456789012 cloudza"
    echo "  $0 eu-west-1 123456789012 cloudza --target frontend"
    echo "  $0 eu-west-1 123456789012 cloudza --target aml-backend --force-redeploy"
    echo "  $0 eu-west-1 123456789012 cloudza -t fraud-backend -f -c ThreatSight360-Cluster"
    echo "  $0 eu-west-1 123456789012 cloudza -f -s threatsight360-stack"
    exit 1
}

# Check minimum required arguments
if [ "$#" -lt 3 ]; then
    usage
fi

REGION=$1
ACCOUNT_ID=$2
NAMESPACE=$3
shift 3

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            BUILD_TARGET="$2"
            if [[ ! "$BUILD_TARGET" =~ ^(frontend|aml-backend|fraud-backend|all)$ ]]; then
                echo "Error: Invalid target '$BUILD_TARGET'. Must be: frontend, aml-backend, fraud-backend, or all"
                exit 1
            fi
            shift 2
            ;;
        -f|--force-redeploy)
            FORCE_REDEPLOY=true
            shift
            ;;
        -c|--cluster)
            ECS_CLUSTER="$2"
            shift 2
            ;;
        -s|--stack)
            STACK_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done

# Set default cluster name if not specified
if [ -z "$ECS_CLUSTER" ]; then
    ECS_CLUSTER="ThreatSight360-Cluster"
fi

ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "=========================================="
echo "Build Configuration:"
echo "  Region: ${REGION}"
echo "  Account ID: ${ACCOUNT_ID}"
echo "  Namespace: ${NAMESPACE}"
echo "  Build Target: ${BUILD_TARGET}"
echo "  Force Redeploy: ${FORCE_REDEPLOY}"
if [ "$FORCE_REDEPLOY" = true ]; then
    echo "  ECS Cluster: ${ECS_CLUSTER}"
    if [ -n "$STACK_NAME" ]; then
        echo "  CloudFormation Stack: ${STACK_NAME}"
    fi
fi
echo "=========================================="
echo ""

echo "Logging into ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_BASE}

# Function to build and push an image
build_and_push() {
    local name=$1
    local dockerfile=$2
    local image_name="${NAMESPACE}/threatsight360-${name}:latest"
    local ecr_image="${ECR_BASE}/${image_name}"
    
    echo ""
    echo "=========================================="
    echo "Building and pushing ${name}..."
    echo "=========================================="
    docker build -t ${image_name} -f ${dockerfile} .
    docker tag ${image_name} ${ecr_image}
    docker push ${ecr_image}
    echo "✓ ${name} pushed: ${ecr_image}"
}

# Build based on target
if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "frontend" ]; then
    build_and_push "frontend" "docker/Dockerfile.frontend"
fi

if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "fraud-backend" ]; then
    build_and_push "backend" "Dockerfile.backend"
fi

if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "aml-backend" ]; then
    build_and_push "aml-backend" "Dockerfile.aml-backend"
fi

echo ""
echo "=========================================="
echo "Build Summary:"
echo "=========================================="
if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "frontend" ]; then
    echo "✓ Frontend: ${ECR_BASE}/${NAMESPACE}/threatsight360-frontend:latest"
fi
if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "fraud-backend" ]; then
    echo "✓ Fraud Backend: ${ECR_BASE}/${NAMESPACE}/threatsight360-backend:latest"
fi
if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "aml-backend" ]; then
    echo "✓ AML Backend: ${ECR_BASE}/${NAMESPACE}/threatsight360-aml-backend:latest"
fi
echo ""

# Force redeploy if requested
if [ "$FORCE_REDEPLOY" = true ]; then
    echo "=========================================="
    echo "Force Redeploying ECS Services"
    echo "=========================================="
    
    # If stack name provided, get cluster from CloudFormation
    if [ -n "$STACK_NAME" ]; then
        echo "Detecting ECS cluster from CloudFormation stack: ${STACK_NAME}"
        DETECTED_CLUSTER=$(aws cloudformation describe-stack-resources \
            --stack-name ${STACK_NAME} \
            --region ${REGION} \
            --query "StackResources[?ResourceType=='AWS::ECS::Cluster'].PhysicalResourceId" \
            --output text 2>/dev/null)
        
        if [ -n "$DETECTED_CLUSTER" ]; then
            ECS_CLUSTER=$DETECTED_CLUSTER
            echo "✓ Detected cluster: ${ECS_CLUSTER}"
        else
            echo "⚠ Could not detect cluster from stack, using: ${ECS_CLUSTER}"
        fi
    fi
    
    # Function to force update ECS service
    force_update_service() {
        local service_name=$1
        echo ""
        echo "Updating service: ${service_name}"
        
        # Check if service exists
        if ! aws ecs describe-services \
            --cluster ${ECS_CLUSTER} \
            --services ${service_name} \
            --region ${REGION} \
            --query "services[0].serviceName" \
            --output text 2>/dev/null | grep -q "${service_name}"; then
            echo "⚠ Service ${service_name} not found in cluster ${ECS_CLUSTER}, skipping..."
            return
        fi
        
        # Force new deployment
        aws ecs update-service \
            --cluster ${ECS_CLUSTER} \
            --service ${service_name} \
            --force-new-deployment \
            --region ${REGION} \
            --output text > /dev/null
        
        echo "✓ ${service_name} deployment triggered"
    }
    
    # Update services based on build target
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "frontend" ]; then
        force_update_service "threatsight360-frontend"
    fi
    
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "fraud-backend" ]; then
        force_update_service "threatsight360-backend"
    fi
    
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "aml-backend" ]; then
        force_update_service "threatsight360-aml-backend"
    fi
    
    echo ""
    echo "=========================================="
    echo "Monitoring Deployment Status"
    echo "=========================================="
    echo "Note: ECS deployments can take 2-5 minutes to complete."
    echo ""
    echo "To monitor deployment progress, run:"
    
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "frontend" ]; then
        echo "  aws ecs describe-services --cluster ${ECS_CLUSTER} --services threatsight360-frontend --region ${REGION}"
    fi
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "fraud-backend" ]; then
        echo "  aws ecs describe-services --cluster ${ECS_CLUSTER} --services threatsight360-backend --region ${REGION}"
    fi
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "aml-backend" ]; then
        echo "  aws ecs describe-services --cluster ${ECS_CLUSTER} --services threatsight360-aml-backend --region ${REGION}"
    fi
    
    echo ""
    echo "✓ ECS service updates triggered successfully!"
else
    echo "=========================================="
    echo "Manual Deployment Steps"
    echo "=========================================="
    echo "To deploy the new images, run:"
    echo ""
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "frontend" ]; then
        echo "  aws ecs update-service --cluster ${ECS_CLUSTER} --service threatsight360-frontend --force-new-deployment --region ${REGION}"
    fi
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "fraud-backend" ]; then
        echo "  aws ecs update-service --cluster ${ECS_CLUSTER} --service threatsight360-backend --force-new-deployment --region ${REGION}"
    fi
    if [ "$BUILD_TARGET" = "all" ] || [ "$BUILD_TARGET" = "aml-backend" ]; then
        echo "  aws ecs update-service --cluster ${ECS_CLUSTER} --service threatsight360-aml-backend --force-new-deployment --region ${REGION}"
    fi
    echo ""
    echo "Or wait for the next scheduled deployment."
fi

echo ""
echo "=========================================="
echo "All operations completed successfully!"
echo "=========================================="

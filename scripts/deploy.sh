#!/bin/bash

# Static Website Deployment Script
# Usage: ./scripts/deploy.sh [environment] [action]
# Example: ./scripts/deploy.sh dev deploy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-dev}
ACTION=${2:-deploy}
CONFIG_FILE="deploy-config.json"
CF_TEMPLATE="cloudformation/main.yaml"
SOURCE_DIR="src"

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if jq is installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install jq first."
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is required but not installed. Please install AWS CLI first."
        exit 1
    fi
}

# Get configuration for environment
get_config() {
    local env=$1
    if ! jq -e ".${env}" "$CONFIG_FILE" > /dev/null 2>&1; then
        print_error "Configuration for environment '${env}' not found in ${CONFIG_FILE}"
        exit 1
    fi

    STACK_NAME=$(jq -r ".${env}.stackName" "$CONFIG_FILE")
    REGION=$(jq -r ".${env}.region" "$CONFIG_FILE")

    # Build parameters
    PARAMETERS=""
    for param in $(jq -r ".${env}.parameters | keys[]" "$CONFIG_FILE"); do
        value=$(jq -r ".${env}.parameters.${param}" "$CONFIG_FILE")
        PARAMETERS="${PARAMETERS} ParameterKey=${param},ParameterValue=${value}"
    done

    # Build tags
    TAGS=""
    for tag in $(jq -r ".${env}.tags | keys[]" "$CONFIG_FILE"); do
        value=$(jq -r ".${env}.tags.${tag}" "$CONFIG_FILE")
        TAGS="${TAGS} Key=${tag},Value=${value}"
    done
}

# Check if stack exists
stack_exists() {
    aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &>/dev/null
}

# Deploy infrastructure
deploy_infrastructure() {
    print_info "Deploying infrastructure for environment: $ENVIRONMENT"
    print_info "Stack Name: $STACK_NAME"
    print_info "Region: $REGION"

    local stack_operation=""

    if stack_exists; then
        print_info "Stack exists. Updating..."
        if ! aws cloudformation update-stack \
            --stack-name "$STACK_NAME" \
            --template-body file://$CF_TEMPLATE \
            --parameters $PARAMETERS \
            --tags $TAGS \
            --region "$REGION" \
            --capabilities CAPABILITY_IAM; then
            print_error "Failed to initiate stack update"
            exit 1
        fi
        stack_operation="update"
    else
        print_info "Stack does not exist. Creating..."
        if ! aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-body file://$CF_TEMPLATE \
            --parameters $PARAMETERS \
            --tags $TAGS \
            --region "$REGION" \
            --capabilities CAPABILITY_IAM; then
            print_error "Failed to initiate stack creation"
            exit 1
        fi
        stack_operation="create"
    fi

    print_info "Waiting for stack operation to complete..."

    if [ "$stack_operation" = "update" ]; then
        if ! aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION"; then
            print_error "Stack update failed or timed out"
            print_info "Checking stack events for details..."
            aws cloudformation describe-stack-events --stack-name "$STACK_NAME" --region "$REGION" \
                --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED` || ResourceStatus==`DELETE_FAILED`].[Timestamp,ResourceType,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
                --output table
            exit 1
        fi
    else
        if ! aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"; then
            print_error "Stack creation failed or timed out"
            print_info "Checking stack events for details..."
            aws cloudformation describe-stack-events --stack-name "$STACK_NAME" --region "$REGION" \
                --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED` || ResourceStatus==`DELETE_FAILED`].[Timestamp,ResourceType,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
                --output table
            exit 1
        fi
    fi

    print_success "Infrastructure deployment completed!"
}

# Get stack outputs
get_stack_outputs() {
    print_info "Retrieving stack outputs..."

    if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &>/dev/null; then
        print_error "Failed to retrieve stack information"
        exit 1
    fi

    BUCKET_NAME=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
        --output text 2>/dev/null)

    DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
        --output text 2>/dev/null)

    WEBSITE_URL=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
        --output text 2>/dev/null)

    if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "None" ]; then
        print_warning "Could not retrieve bucket name from stack outputs"
    else
        print_info "Bucket Name: $BUCKET_NAME"
    fi

    if [ -z "$DISTRIBUTION_ID" ] || [ "$DISTRIBUTION_ID" = "None" ]; then
        print_warning "Could not retrieve distribution ID from stack outputs"
    else
        print_info "Distribution ID: $DISTRIBUTION_ID"
    fi

    if [ -z "$WEBSITE_URL" ] || [ "$WEBSITE_URL" = "None" ]; then
        print_warning "Could not retrieve website URL from stack outputs"
    else
        print_info "Website URL: $WEBSITE_URL"
    fi
}

# Deploy website content
deploy_content() {
    print_info "Deploying website content to S3..."

    if [ ! -d "$SOURCE_DIR" ]; then
        print_error "Source directory '$SOURCE_DIR' not found!"
        exit 1
    fi

    if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "None" ]; then
        print_error "Bucket name not available for content deployment"
        exit 1
    fi

    # Sync files to S3
    if ! aws s3 sync "$SOURCE_DIR" "s3://$BUCKET_NAME" \
        --region "$REGION" \
        --delete \
        --cache-control "max-age=31536000" \
        --exclude "*.html" \
        --exclude "*.json"; then
        print_error "Failed to sync static assets to S3"
        exit 1
    fi

    # Upload HTML files with shorter cache control
    if ! aws s3 sync "$SOURCE_DIR" "s3://$BUCKET_NAME" \
        --region "$REGION" \
        --delete \
        --cache-control "max-age=3600" \
        --content-type "text/html" \
        --include "*.html"; then
        print_error "Failed to sync HTML files to S3"
        exit 1
    fi

    # Upload JSON files with shorter cache control
    if ! aws s3 sync "$SOURCE_DIR" "s3://$BUCKET_NAME" \
        --region "$REGION" \
        --delete \
        --cache-control "max-age=3600" \
        --content-type "application/json" \
        --include "*.json"; then
        print_error "Failed to sync JSON files to S3"
        exit 1
    fi

    print_success "Website content deployed!"
}

# Invalidate CloudFront cache
invalidate_cache() {
    print_info "Invalidating CloudFront cache..."

    if [ -z "$DISTRIBUTION_ID" ] || [ "$DISTRIBUTION_ID" = "None" ]; then
        print_error "Distribution ID not available for cache invalidation"
        exit 1
    fi

    if ! INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id "$DISTRIBUTION_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text 2>/dev/null); then
        print_error "Failed to create CloudFront invalidation"
        exit 1
    fi

    print_info "Invalidation ID: $INVALIDATION_ID"
    print_info "Waiting for invalidation to complete..."

    if ! aws cloudfront wait invalidation-completed \
        --distribution-id "$DISTRIBUTION_ID" \
        --id "$INVALIDATION_ID"; then
        print_error "Invalidation failed or timed out"
        exit 1
    fi

    print_success "Cache invalidation completed!"
}

# Delete stack
delete_stack() {
    print_warning "Deleting stack: $STACK_NAME"
    read -p "Are you sure you want to delete the stack? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Empty S3 bucket first
        if [ -n "$BUCKET_NAME" ] && [ "$BUCKET_NAME" != "None" ]; then
            print_info "Emptying S3 bucket: $BUCKET_NAME"
            if ! aws s3 rm "s3://$BUCKET_NAME" --recursive --region "$REGION" 2>/dev/null; then
                print_warning "Failed to empty S3 bucket or bucket doesn't exist"
            fi
        fi

        if ! aws cloudformation delete-stack \
            --stack-name "$STACK_NAME" \
            --region "$REGION"; then
            print_error "Failed to initiate stack deletion"
            exit 1
        fi

        print_info "Waiting for stack deletion to complete..."
        if ! aws cloudformation wait stack-delete-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION"; then
            print_error "Stack deletion failed or timed out"
            exit 1
        fi

        print_success "Stack deleted successfully!"
    else
        print_info "Stack deletion cancelled."
    fi
}

# Validate CloudFormation template
validate_template() {
    print_info "Validating CloudFormation template..."

    aws cloudformation validate-template \
        --template-body file://$CF_TEMPLATE \
        --region "$REGION"

    print_success "Template validation successful!"
}

# Show help
show_help() {
    echo "Usage: $0 [environment] [action]"
    echo ""
    echo "Environments:"
    echo "  dev      - Development environment"
    echo "  staging  - Staging environment"
    echo "  prod     - Production environment"
    echo ""
    echo "Actions:"
    echo "  deploy   - Deploy infrastructure and content (default)"
    echo "  infra    - Deploy only infrastructure"
    echo "  content  - Deploy only website content"
    echo "  delete   - Delete the stack"
    echo "  validate - Validate CloudFormation template"
    echo "  outputs  - Show stack outputs"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev deploy"
    echo "  $0 prod content"
    echo "  $0 staging delete"
}

# Main execution
main() {
    case $ACTION in
        "help")
            show_help
            ;;
        "validate")
            check_dependencies
            get_config $ENVIRONMENT
            validate_template
            ;;
        "deploy")
            check_dependencies
            get_config $ENVIRONMENT
            deploy_infrastructure
            get_stack_outputs
            deploy_content
            invalidate_cache
            print_success "Deployment completed! Website URL: $WEBSITE_URL"
            ;;
        "infra")
            check_dependencies
            get_config $ENVIRONMENT
            deploy_infrastructure
            get_stack_outputs
            print_success "Infrastructure deployment completed!"
            ;;
        "content")
            check_dependencies
            get_config $ENVIRONMENT
            get_stack_outputs
            deploy_content
            invalidate_cache
            print_success "Content deployment completed!"
            ;;
        "delete")
            check_dependencies
            get_config $ENVIRONMENT
            get_stack_outputs
            delete_stack
            ;;
        "outputs")
            check_dependencies
            get_config $ENVIRONMENT
            get_stack_outputs
            ;;
        *)
            print_error "Unknown action: $ACTION"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main

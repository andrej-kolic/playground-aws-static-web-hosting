#!/bin/bash

# DNS & SSL Stack Deployment Script
# This script deploys the shared infrastructure (hosted zone and SSL certificate)
# that is used across all environments
# Usage: ./scripts/deploy-dns-ssl.sh [action]
# Example: ./scripts/deploy-dns-ssl.sh deploy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ACTION=${1:-deploy}
CONFIG_FILE="dns-ssl-config.json"
CF_TEMPLATE="cloudformation/dns-ssl.yaml"
CONFIG_ROOT="dns_ssl"

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

# Check if files exist
check_files() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file $CONFIG_FILE not found"
        exit 1
    fi

    if [[ ! -f "$CF_TEMPLATE" ]]; then
        print_error "CloudFormation template $CF_TEMPLATE not found"
        exit 1
    fi
}

# Get configuration for dns-ssl stack
get_config() {
    local key=$1
    echo $(jq -r ".${CONFIG_ROOT}.${key}" "$CONFIG_FILE")
}

# Get all parameters as CloudFormation format
get_parameters() {
    local params=$(jq -r ".${CONFIG_ROOT}.parameters | to_entries | map(\"ParameterKey=\" + .key + \",ParameterValue=\" + .value) | join(\" \")" "$CONFIG_FILE")
    echo "$params"
}

# Get all tags as CloudFormation format
get_tags() {
    local tags=$(jq -r ".${CONFIG_ROOT}.tags | to_entries | map(\"Key=\" + .key + \",Value=\" + .value) | join(\" \")" "$CONFIG_FILE")
    echo "$tags"
}

# Deploy CloudFormation stack
deploy_stack() {
    local stack_name=$(get_config "stackName")
    local region=$(get_config "region")
    local parameters=$(get_parameters)
    local tags=$(get_tags)

    print_info "Deploying dns-ssl stack: $stack_name"
    print_info "Region: $region"
    print_info "Template: $CF_TEMPLATE"

    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$region" &>/dev/null; then
        print_info "Stack exists, updating..."
        local action="update-stack"
    else
        print_info "Stack does not exist, creating..."
        local action="create-stack"
    fi

    # Deploy stack
    aws cloudformation "$action" \
        --stack-name "$stack_name" \
        --template-body "file://$CF_TEMPLATE" \
        --parameters $parameters \
        --tags $tags \
        --region "$region" \
        --capabilities CAPABILITY_IAM

    print_info "Waiting for stack operation to complete..."
    if [[ "$action" == "create-stack" ]]; then
        aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$region"
    else
        aws cloudformation wait stack-update-complete --stack-name "$stack_name" --region "$region"
    fi

    print_success "Stack operation completed successfully!"

    # Get and display outputs
    print_info "Stack outputs:"
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
        --output table
}

# Delete CloudFormation stack
delete_stack() {
    local stack_name=$(get_config "stackName")
    local region=$(get_config "region")

    print_warning "Deleting dns-ssl stack: $stack_name"
    print_warning "This will delete the hosted zone and SSL certificate!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        exit 0
    fi

    aws cloudformation delete-stack \
        --stack-name "$stack_name" \
        --region "$region"

    print_info "Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$region"

    print_success "Stack deleted successfully!"
}

# Get stack status
get_status() {
    local stack_name=$(get_config "stackName")
    local region=$(get_config "region")

    print_info "Getting status for dns-ssl stack: $stack_name"

    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$region" &>/dev/null; then
        aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$region" \
            --query 'Stacks[0].[StackName,StackStatus,CreationTime]' \
            --output table

        print_info "Stack outputs:"
        aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$region" \
            --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
            --output table
    else
        print_warning "Stack $stack_name does not exist"
    fi
}

# Validate CloudFormation template
validate_template() {
    local region=$(get_config "region")
    print_info "region: $region"

    print_info "Validating CloudFormation template: $CF_TEMPLATE"

    aws cloudformation validate-template \
        --region "$region" \
        --template-body "file://$CF_TEMPLATE"

    if [[ $? -eq 0 ]]; then
        print_success "Template validation successful!"
    else
        print_error "Template validation failed!"
        exit 1
    fi
}

# Show help
show_help() {
    echo "DNS & SSL Stack Deployment Script"
    echo ""
    echo "Usage: $0 [action]"
    echo ""
    echo "Actions:"
    echo "  deploy    Deploy or update the DNS & SSL stack (default)"
    echo "  delete    Delete the DNS & SSL stack"
    echo "  status    Get the current status of the DNS & SSL stack"
    echo "  validate  Validate the CloudFormation template"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy    # Deploy the DNS & SSL stack"
    echo "  $0 delete    # Delete the DNS & SSL stack"
    echo "  $0 status    # Get stack status"
}

# Main execution
main() {
    check_dependencies
    check_files

    case "$ACTION" in
        deploy)
            validate_template
            deploy_stack
            ;;
        delete)
            delete_stack
            ;;
        status)
            get_status
            ;;
        validate)
            validate_template
            ;;
        help|--help|-h)
            show_help
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

# AWS Static Website Hosting - Deployment Guide

## Architecture Overview

This project uses a two-stack approach for AWS static website hosting:

1. **Infrastructure Stack** (`infrastructure.yaml`) - Deployed once, shared across all environments
   - Route53 Hosted Zone
   - Wildcard SSL Certificate (supports all subdomains)

2. **Environment Stack** (`main.yaml`) - Deployed per environment (dev, staging, prod)
   - S3 Bucket for static content
   - CloudFront Distribution
   - Route53 DNS records

## Prerequisites

- AWS CLI installed and configured
- `jq` command-line JSON processor
- Domain name registered (modify `andrejkolic.com` in configs to your domain)

## Deployment Process

### Step 1: Deploy Infrastructure Stack (One-time setup)

The infrastructure stack creates shared resources that are used across all environments:

```bash
# Deploy the infrastructure stack
./scripts/deploy-infrastructure.sh deploy

# Check the status
./scripts/deploy-infrastructure.sh status
```

This will create:
- Route53 hosted zone for your domain
- Wildcard SSL certificate (`*.andrejkolic.com`) that covers all subdomains
- DNS validation records for the certificate

**Important**: After the infrastructure stack is deployed, you need to update your domain's nameservers to point to the Route53 hosted zone. The nameservers will be shown in the stack outputs.

### Step 2: Deploy Environment Stacks

After the infrastructure stack is deployed and DNS is properly configured, deploy your environment stacks:

```bash
# Deploy development environment
./scripts/deploy.sh dev deploy

# Deploy staging environment
./scripts/deploy.sh staging deploy

# Deploy production environment
./scripts/deploy.sh prod deploy
```

## Configuration Files

### infrastructure-config.json
Configuration for the shared infrastructure stack:
```json
{
  "infrastructure": {
    "stackName": "static-website-infrastructure",
    "region": "us-east-1",
    "parameters": {
      "DomainName": "andrejkolic.com",
      "CreateWildcardCertificate": "true"
    }
  }
}
```

### deploy-config.json
Configuration for environment-specific stacks:
```json
{
  "dev": {
    "stackName": "static-website-dev",
    "parameters": {
      "InfrastructureStackName": "static-website-infrastructure",
      "SubDomain": "dev",
      "Environment": "dev",
      "UseSSL": "true",
      "CreateRoute53Records": "true"
    }
  }
}
```

## Subdomain Mapping

With the wildcard certificate, you can use any subdomain:

- **Dev**: `dev.andrejkolic.com`
- **Staging**: `staging.andrejkolic.com`
- **Production**: `www.andrejkolic.com`

## Troubleshooting

### Certificate Validation Issues

If you encounter certificate validation errors:

1. Ensure the hosted zone is properly created
2. Verify your domain's nameservers point to the Route53 hosted zone
3. Wait for DNS propagation (can take up to 48 hours)
4. Check for existing certificates that might conflict

### DNS Resolution Issues

1. Check nameserver configuration:
   ```bash
   dig NS andrejkolic.com
   ```

2. Verify DNS propagation:
   ```bash
   dig dev.andrejkolic.com
   ```

### Stack Dependencies

The environment stacks depend on the infrastructure stack. Make sure:
1. Infrastructure stack is deployed successfully
2. The `InfrastructureStackName` parameter matches the actual stack name
3. The infrastructure stack exports are available

## Useful Commands

```bash
# Validate templates
./scripts/deploy-infrastructure.sh validate
./scripts/deploy.sh dev validate

# Check stack status
./scripts/deploy-infrastructure.sh status
./scripts/deploy.sh dev status

# Delete stacks (be careful!)
./scripts/deploy.sh dev delete
./scripts/deploy-infrastructure.sh delete  # Only delete this after all env stacks are deleted
```

## Cost Optimization

- The wildcard certificate is free with AWS Certificate Manager
- Route53 hosted zone costs $0.50/month
- CloudFront has a generous free tier
- S3 storage costs are minimal for static websites

## Security Notes

- S3 buckets are configured with CloudFront Origin Access Control (OAC)
- Direct S3 access is blocked
- All traffic is served over HTTPS
- CloudFront provides DDoS protection

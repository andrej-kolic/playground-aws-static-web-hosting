# Static Website Hosting on AWS

A complete solution for hosting static websites on AWS using S3, CloudFront, and Route53, with Infrastructure as Code (CloudFormation) and CI/CD deployment through GitHub Actions.

## 🏠 Architecture

This project creates a robust, scalable static website hosting solution with:

- **S3 Bucket**: Static website hosting with versioning
- **CloudFront**: Global CDN for fast content delivery
- **Route53**: DNS management (optional)
- **ACM Certificate**: SSL/TLS certificates (optional)
- **Origin Access Control**: Secure S3 access

## 🛠️ Features

- 🚀 **Multi-environment support** (dev, staging, prod)
- 🔒 **SSL certificates** with automatic renewal
- 🌍 **Global CDN** with CloudFront
- 📝 **Infrastructure as Code** with CloudFormation
- 🔄 **CI/CD deployment** with GitHub Actions
- 📈 **Cost optimization** with intelligent caching
- 🔍 **Drift detection** and compliance monitoring
- 🚨 **Security scanning** with cfn_nag

## 📋 Prerequisites

### Local Development
- AWS CLI installed and configured
- jq (JSON processor)
- Bash shell
- AWS account with appropriate permissions

### GitHub Actions
- AWS Access Key ID and Secret Access Key stored in GitHub Secrets
- Repository secrets configured (see setup section)

## 🎦 Quick Start

### 1. Clone and Configure

```bash
git clone <repo-url>
cd <repo-dir> # for example 'aws-static-web-hosting'
```

### 2. Update Configuration

Edit `deploy-config.json` with your domain and preferences:

```json
{
  "dev": {
    "stackName": "your-website-dev",
    "region": "eu-west-1",
    "parameters": {
      "DomainName": "yourdomain.com",
      "SubDomain": "dev",
      "Environment": "dev",
      "CreateSSLCertificate": "false",
      "CreateRoute53Records": "false"
    }
  }
}
```

### 3. Deploy Locally

```bash
# Deploy to development environment
./scripts/deploy.sh dev deploy

# Deploy only infrastructure
./scripts/deploy.sh dev infra

# Deploy only content
./scripts/deploy.sh dev content

# Validate CloudFormation template
./scripts/deploy.sh dev validate
```

### 4. Deploy via GitHub Actions

1. Push to `develop` branch for automatic dev deployment
2. Push to `main` branch for automatic staging deployment
3. Use manual workflow dispatch for production deployment

## 📋 Configuration

### Environment Configuration

The `deploy-config.json` file contains environment-specific settings:

```json
{
  "environment_name": {
    "stackName": "CloudFormation stack name",
    "region": "AWS region",
    "parameters": {
      "DomainName": "example.com",
      "SubDomain": "www",
      "Environment": "prod",
      "CreateSSLCertificate": "true",
      "CreateRoute53Records": "true"
    },
    "tags": {
      "Environment": "prod",
      "Project": "StaticWebsite",
      "Owner": "DevTeam"
    }
  }
}
```

### CloudFormation Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `DomainName` | Your domain name | `example.com` | Yes |
| `SubDomain` | Subdomain prefix | `www` | No |
| `Environment` | Environment name | `dev` | Yes |
| `CreateSSLCertificate` | Create SSL cert | `false` | Yes |
| `CreateRoute53Records` | Create DNS records | `false` | Yes |

## 🚀 Deployment Options

### Local Deployment

Use the deployment script for local development and testing:

```bash
# Available commands
./scripts/deploy.sh [environment] [action]

# Examples
./scripts/deploy.sh dev deploy      # Full deployment
./scripts/deploy.sh prod infra      # Infrastructure only
./scripts/deploy.sh staging content # Content only
./scripts/deploy.sh dev delete      # Delete stack
./scripts/deploy.sh dev outputs     # Show outputs
./scripts/deploy.sh dev validate    # Validate template
./scripts/deploy.sh help            # Show help
```

### GitHub Actions Deployment

The workflow supports multiple deployment strategies:

1. **Automatic Deployments**:
   - `develop` branch → dev environment
   - `main` branch → staging environment

2. **Manual Deployments**:
   - Use "Actions" tab in GitHub
   - Select "Deploy Static Website"
   - Choose environment and action

3. **Pull Request Deployments**:
   - Automatic dev environment deployment
   - PR comments with deployment URLs

## 🔒 Security

### AWS Permissions

The deployment requires the following AWS permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "s3:*",
        "cloudfront:*",
        "route53:*",
        "acm:*",
        "iam:PassRole",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

### GitHub Secrets

Configure these secrets in your GitHub repository:

| Secret Name | Description |
|-------------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key |
| `INFRACOST_API_KEY` | Infracost API key (optional) |

## 📈 Monitoring and Maintenance

### Drift Detection

Automatic drift detection runs on a schedule to check for configuration changes:

```yaml
# In .github/workflows/deploy.yml
drift-detection:
  runs-on: ubuntu-latest
  if: github.event_name == 'schedule'
```

### Cost Monitoring

Optional cost estimation on pull requests (requires Infracost setup).

### Security Scanning

Automatic security scanning using cfn_nag for CloudFormation templates.

## 📚 File Structure

```
.
├── src/                          # Website source files
│   ├── index.html               # Main HTML file
│   ├── styles.css               # CSS styles
│   ├── script.js                # JavaScript
│   └── error.html               # 404 error page
├── cloudformation/               # Infrastructure templates
│   └── main.yaml                # Main CloudFormation template
├── scripts/                      # Deployment scripts
│   └── deploy.sh                # Main deployment script
├── .github/workflows/            # GitHub Actions
│   └── deploy.yml               # Deployment workflow
├── deploy-config.json            # Environment configuration
├── package.json                  # Project metadata
└── README.md                     # This file
```

## 🐛 Troubleshooting

### Common Issues

1. **SSL Certificate Validation**
   - Ensure DNS records are properly configured
   - Certificate validation can take up to 30 minutes

2. **CloudFront Cache Issues**
   - Use cache invalidation after content updates
   - Cache TTL settings affect update propagation

3. **S3 Bucket Naming**
   - Bucket names must be globally unique
   - Use account ID suffix to ensure uniqueness

4. **Route53 Dependencies**
   - Hosted zone must exist before creating DNS records
   - Verify domain ownership

### Debug Commands

```bash
# Check stack status
aws cloudformation describe-stacks --stack-name your-stack-name

# View stack events
aws cloudformation describe-stack-events --stack-name your-stack-name

# Check CloudFront distribution
aws cloudfront list-distributions

# Test website
curl -I https://your-domain.com
```

## 🔄 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test deployments
5. Submit a pull request

## 📋 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🚀 Next Steps

- [ ] Add monitoring with CloudWatch
- [ ] Implement blue-green deployments
- [ ] Add performance testing
- [ ] Integrate with AWS WAF
- [ ] Add backup and restore procedures
- [ ] Implement multi-region deployment

---

**Built with ❤️ using AWS CloudFormation and GitHub Actions**


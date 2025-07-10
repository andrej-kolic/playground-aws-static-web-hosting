# DNS Configuration Guide

## Setup Steps

### 1. Create the Main Hosted Zone (One Time Setup)

Run the hosted zone creation script:

```bash
./scripts/create-hosted-zone.sh yourdomain.com
```

This will:
- Create a Route53 hosted zone for your domain
- Display the nameservers you need to configure
- Give you the Hosted Zone ID to use in deployments

### 2. Configure Nameservers at Your Domain Provider

Take the nameservers from step 1 and configure them in your domain provider's DNS settings. This is typically done in your domain registrar's control panel.

**Example nameservers:**
```
ns-123.awsdns-12.com
ns-456.awsdns-45.net
ns-789.awsdns-78.org
ns-012.awsdns-01.co.uk
```

### 3. Update Your Deploy Configuration

Edit `deploy-config.json` and set `HostedZoneId` actual hosted zone ID from step 1.

### 4. Deploy Your Environments

Now you can deploy each environment and they will all use the same hosted zone:

```bash
# Deploy dev environment (no DNS records)
make deploy ENV=dev

# Deploy staging environment (creates staging-www.yourdomain.com)
make deploy ENV=staging

# Deploy production environment (creates prod-www.yourdomain.com)
make deploy ENV=prod
```

## DNS Propagation

After configuring nameservers at your domain provider:
- Changes can take up to 48 hours to propagate globally
- You can check propagation using tools like `dig` or online DNS checkers
- SSL certificate validation will work once DNS is propagated

## Environment URL Examples

With domain `andrejkolic.com`:

- **Dev**: `https://dev.andrejkolic.com` (or CloudFront URL if no SSL)
- **Staging**: `https://staging.andrejkolic.com`
- **Production**: `https://www.andrejkolic.com`

## Troubleshooting

### SSL Certificate Issues
- Ensure DNS records are created before requesting SSL certificates
- DNS validation requires the hosted zone to be properly configured
- Check that the domain validation records are created in Route53

### DNS Not Resolving
- Verify nameservers are correctly configured at your domain provider
- Check DNS propagation using `dig yourdomain.com NS`
- Ensure the hosted zone ID is correct in your deploy configuration

### CloudFormation Validation Errors
- Make sure `HostedZoneId` parameter is provided when `CreateRoute53Records` is `true`
- Verify the hosted zone exists and you have permissions to access it

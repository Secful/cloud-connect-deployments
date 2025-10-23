# Azure Deployment Solutions

This directory contains deployment and management scripts for Microsoft Azure integration with Salt Security.

## Structure

- `subscription/deployment/` - Subscription-level deployment scripts and resources
- `subscription/deletion/` - Subscription-level deletion scripts and resources
- `management-group/` - Management group-level scripts *(future)*

## Scripts

### Subscription-Level Deployment
- **File**: `subscription/deployment/subscription-level-deployment.sh`
- **Purpose**: Creates and configures Azure authentication components (Service Principal, Custom Role, etc.)
- **Documentation**: [subscription/deployment/SUBSCRIPTION_LEVEL_DEPLOYMENT.md](subscription/deployment/SUBSCRIPTION_LEVEL_DEPLOYMENT.md)

### Subscription-Level Deletion
- **File**: `subscription/deletion/subscription-level-deletion.sh`
- **Purpose**: Removes Azure resources created by the deployment script
- **Documentation**: [subscription/deletion/SUBSCRIPTION_LEVEL_DELETION.md](subscription/deletion/SUBSCRIPTION_LEVEL_DELETION.md)

## Quick Start

### Deploy Azure Resources
```bash
./subscription/deployment/subscription-level-deployment.sh \
  --subscription-id=your-subscription-id \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-token \
  --installation-id=your-installation-id \
  --attempt-id=your-attempt-id
```

### Delete Azure Resources
```bash
./subscription/deletion/subscription-level-deletion.sh \
  --subscription-id=your-subscription-id \
  --nonce=nonce-from-deployment \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-token
```

## Testing

Manual test plans are available to validate script functionality:
- **[subscription/deployment/DEPLOYMENT_MANUAL_TEST_PLAN.md](subscription/deployment/DEPLOYMENT_MANUAL_TEST_PLAN.md)** - Manual deployment testing procedures
- **[subscription/deletion/DELETION_MANUAL_TEST_PLAN.md](subscription/deletion/DELETION_MANUAL_TEST_PLAN.md)** - Manual deletion testing procedures

## Documentation

- **[subscription/deployment/SUBSCRIPTION_LEVEL_DEPLOYMENT.md](subscription/deployment/SUBSCRIPTION_LEVEL_DEPLOYMENT.md)** - Complete deployment script guide
- **[subscription/deletion/SUBSCRIPTION_LEVEL_DELETION.md](subscription/deletion/SUBSCRIPTION_LEVEL_DELETION.md)** - Complete deletion script guide
- **[subscription/deployment/DEPLOYMENT_MANUAL_TEST_PLAN.md](subscription/deployment/DEPLOYMENT_MANUAL_TEST_PLAN.md)** - Manual deployment testing procedures
- **[subscription/deletion/DELETION_MANUAL_TEST_PLAN.md](subscription/deletion/DELETION_MANUAL_TEST_PLAN.md)** - Manual deletion testing procedures

## Prerequisites

- Azure CLI (`az`) - authenticated and configured
- Standard Unix utilities: `jq`, `curl`, `uuidgen`
- Appropriate Azure subscription permissions

## Support

For issues or questions:
1. Check the relevant documentation files
2. Review test plans for expected behavior
3. Examine script log files for detailed error information
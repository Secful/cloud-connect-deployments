# Azure Deployment Solutions

This directory contains deployment and management scripts for Microsoft Azure integration with Salt Security.

## Scripts

### Deployment Script
- **File**: `azure-deployment-script.sh`
- **Purpose**: Creates and configures Azure authentication components (Service Principal, Custom Role, etc.)
- **Documentation**: [DEPLOYMENT.md](DEPLOYMENT.md)

### Deletion Script  
- **File**: `azure-deletion-script.sh`
- **Purpose**: Removes Azure resources created by the deployment script
- **Documentation**: [DELETION.md](DELETION.md) *(coming soon)*

## Quick Start

### Deploy Azure Resources
```bash
./azure-deployment-script.sh \
  --subscription-id=your-subscription-id \
  --backend-url=https://api.saltsecurity.com/webhook \
  --bearer-token=your-token \
  --installation-id=your-installation-id \
  --attempt-id=your-attempt-id
```

### Delete Azure Resources
```bash
./azure-deletion-script.sh [options]
```

## Testing

The `tests/` directory contains comprehensive test suites for validating script functionality:
- Unit tests for individual components
- Integration tests with Azure services
- Mock environments for safe testing

See [tests/README.md](tests/README.md) for testing documentation.

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment script guide
- **[DELETION.md](DELETION.md)** - Deletion script guide *(coming soon)*
- **[DEPLOYMENT_MANUAL_TEST_PLAN.md](DEPLOYMENT_MANUAL_TEST_PLAN.md)** - Manual testing procedures
- **[DELETION_MANUAL_TEST_PLAN.md](DELETION_MANUAL_TEST_PLAN.md)** - Deletion testing procedures *(if exists)*

## Prerequisites

- Azure CLI (`az`) - authenticated and configured
- Standard Unix utilities: `jq`, `curl`, `uuidgen`
- Appropriate Azure subscription permissions

## Support

For issues or questions:
1. Check the relevant documentation files
2. Review test plans for expected behavior
3. Examine script log files for detailed error information
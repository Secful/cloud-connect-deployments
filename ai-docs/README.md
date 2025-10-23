# Cloud Connect Deployments

## Overview
Multi-cloud deployment automation repository for Salt Security cloud connectivity. Provides shell script-based deployment solutions for Azure, AWS, and GCP integration with automated Azure AD app creation, service principal setup, and role assignment.

## Key Features - IMPLEMENTED
- **Azure subscription-level deployment** - Creates Azure AD apps, service principals, custom roles
- **Azure management-group deployment** - Parallel deployment across multiple subscriptions  
- **Azure resource deletion** - Automated cleanup of Salt Security Azure resources
- **Salt Security API integration** - Deployment status reporting and credential exchange
- **Comprehensive logging** - Timestamped logs with unique nonce identifiers
- **Error handling** - Graceful failures with detailed error reporting

## Key Features - PLANNED
- **AWS deployment solutions** - Infrastructure templates and deployment scripts
- **GCP deployment solutions** - Google Cloud integration automation

## Quick Start
### Deploy Azure Resources (Subscription Level)
```bash
./azure/subscription/deployment/subscription-level-deployment.sh \
  --subscription-id=your-subscription-id \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-token \
  --installation-id=your-installation-id \
  --attempt-id=your-attempt-id
```

### Deploy Azure Resources (Management Group Level)
```bash
./azure/management-group/deployment/management-group-level-deployment.sh \
  --management-group-id=your-mg-id \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-token \
  --installation-id=your-installation-id \
  --attempt-id=your-attempt-id
```

## Technology Stack - CURRENT
- **Shell Scripting**: Bash scripts for deployment automation
- **Azure CLI**: Azure resource management and authentication
- **Unix Utilities**: jq (JSON processing), curl (HTTP client), uuidgen (unique IDs)
- **Salt Security API**: v1/cloud-connect endpoints for status reporting
- **Azure AD**: Application and service principal management
- **Azure RBAC**: Custom role creation and assignment

## Architecture
See [ARCHITECTURE.md](ARCHITECTURE.md) for system design and deployment patterns.

## API
See [API.md](API.md) for Salt Security API integration and Azure CLI patterns.
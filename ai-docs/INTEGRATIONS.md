# External System Integrations

## Overview
Current integrations with Salt Security cloud-connect platform and Azure services for automated deployment and management of cloud connectivity resources.

## Salt Security Cloud-Connect API - INTEGRATED

### Integration Architecture
- **API Version**: v1  
- **Base URLs**: 
  - `https://api.saltsecurity.com`
  - `https://api.us.saltsecurity.io`
  - `https://api.eu.saltsecurity.io`
- **Authentication**: Bearer token-based
- **Content Type**: `application/json`
- **Integration Pattern**: REST API client using curl

### Endpoints Integrated
1. **Deployment Status Reporting**
   - **Endpoint**: `POST /v1/cloud-connect/scan/azure`
   - **Purpose**: Report deployment progress and exchange Azure credentials
   - **Integration Status**: ✅ Fully Implemented

2. **Account Deletion Notification**  
   - **Endpoint**: `DELETE /v1/cloud-connect/organizations/accounts/azure/{subscription-id}`
   - **Purpose**: Notify platform when Azure resources are removed
   - **Integration Status**: ✅ Fully Implemented

### Integration Features
- **Status Lifecycle Management**: Initiated → Succeeded/Failed/Unknown
- **Credential Exchange**: Secure transmission of Azure AD application credentials  
- **Error Handling**: Graceful degradation when API unavailable
- **Multi-region Support**: Dynamic endpoint selection based on user configuration

## Microsoft Azure Services - INTEGRATED

### Azure CLI Integration
- **Tool**: Azure CLI (`az`) version 2.x+
- **Authentication**: Interactive login session or service principal
- **Scope**: Subscription and management group level operations
- **Integration Pattern**: Command-line interface with JSON output parsing

### Azure Active Directory
- **Service**: Azure AD Applications and Service Principals
- **Operations**: Create, configure, and delete applications and service principals
- **Permissions**: Application.ReadWrite.All, Directory.Read.All
- **Integration Status**: ✅ Fully Implemented

### Azure Role-Based Access Control (RBAC)
- **Service**: Custom role definitions and role assignments
- **Operations**: Create custom roles, assign roles to service principals
- **Scope**: Subscription-level role assignments
- **Integration Status**: ✅ Fully Implemented

### Azure Resource Management
- **Service**: Azure Resource Manager (ARM)
- **Operations**: Subscription and management group enumeration
- **Authentication**: Azure CLI session
- **Integration Status**: ✅ Fully Implemented

## Integration Patterns

### Authentication Flow
```
User → Azure CLI Login → Script Execution → Azure API Calls
                                        ↓
                                  Salt Security API → Bearer Token Auth
```

### Data Flow Architecture
```
Azure Resources Created → Credential Extraction → Salt Security API → Platform Integration
```

### Error Handling Integration
- **Azure CLI Errors**: JSON error response parsing with retry logic
- **Salt API Errors**: HTTP status code handling with warning logs  
- **Network Failures**: Timeout handling and connection error reporting
- **Permission Errors**: Clear error messages with remediation guidance

## Dependency Management

### Required External Tools
- **Azure CLI**: Microsoft's official Azure command-line interface
  - **Installation**: `https://docs.microsoft.com/en-us/cli/azure/install-azure-cli`
  - **Minimum Version**: 2.0+
  - **Validation**: `az --version`

- **jq**: JSON processor for parsing API responses
  - **Installation**: `sudo apt-get install jq` or `brew install jq`
  - **Validation**: `jq --version`

- **curl**: HTTP client for Salt Security API communication
  - **Installation**: Usually pre-installed on Unix systems
  - **Validation**: `curl --version`

- **uuidgen**: UUID generator for unique resource naming
  - **Installation**: Usually pre-installed on Unix systems  
  - **Validation**: `uuidgen`

### Optional External Tools
- **parallel**: GNU Parallel for concurrent management group deployments
  - **Installation**: `sudo apt-get install parallel`
  - **Usage**: Management group multi-subscription processing
  - **Fallback**: Sequential processing if not available

## Configuration Management

### Salt Security Configuration
```bash
# Required Parameters
SALT_HOST="https://api.saltsecurity.com"
BEARER_TOKEN="your-api-token"
INSTALLATION_ID="uuid-for-tracking"
ATTEMPT_ID="uuid-for-tracking"
```

### Azure Configuration  
```bash
# Azure CLI must be logged in
az login

# Target subscription configuration
SUBSCRIPTION_ID="target-subscription-uuid"
MANAGEMENT_GROUP_ID="target-mg-id" # Optional for MG deployments
```

### Resource Naming Configuration
```bash
# Optional custom naming (defaults provided)
APP_NAME="SaltAppServicePrincipal"  # Default prefix
ROLE_NAME="SaltCustomAppRole"       # Default prefix  
```

## Integration Testing

### Salt Security API Testing
- **Connection Testing**: HTTP connectivity and authentication validation
- **Endpoint Testing**: POST/DELETE request-response validation
- **Error Scenario Testing**: Network failure and authentication error handling

### Azure Integration Testing  
- **Authentication Testing**: Azure CLI session validation
- **Permission Testing**: Required Azure AD and RBAC permissions verification
- **Resource Testing**: End-to-end resource creation and deletion workflows

## Security Considerations

### API Security
- **Token Management**: Bearer tokens passed via command-line parameters (not environment variables)
- **HTTPS Enforcement**: All Salt Security API calls use HTTPS
- **Credential Handling**: Azure client secrets transmitted securely to Salt platform

### Azure Security
- **Least Privilege**: Custom roles with minimal required permissions
- **Resource Isolation**: Unique nonce-based naming prevents conflicts
- **Audit Trail**: Comprehensive logging of all Azure operations

## Future Integration Plans

### AWS Integration - PLANNED
- AWS CLI integration for deployment automation  
- Salt Security cloud-connect API extension for AWS
- IAM role and policy management automation

### Google Cloud Platform Integration - PLANNED  
- gcloud CLI integration for deployment automation
- Salt Security cloud-connect API extension for GCP
- Service account and IAM binding automation
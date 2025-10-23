# External API Documentation - Current Implementation

## Overview
Integration patterns with Salt Security cloud-connect API and Azure CLI for automated Azure resource provisioning and management.

## External APIs Provided - CURRENTLY AVAILABLE
*This system does not provide external APIs - it is a client-side deployment automation tool.*

## External APIs Consumed - CURRENTLY INTEGRATED

### Salt Security Cloud-Connect API
#### Deployment Status Reporting
- **Service:** Salt Security Platform
- **Method:** POST
- **Path:** `/v1/cloud-connect/scan/azure`
- **Purpose:** Report Azure deployment status and exchange connection credentials
- **Authentication:** Bearer token in Authorization header
- **Request Format:** JSON payload with deployment status and Azure credentials
- **Response Format:** JSON with deployment acknowledgment
- **Example:**
```bash
curl -X POST "${SALT_HOST}/v1/cloud-connect/scan/azure" \
  -H "Authorization: Bearer ${BEARER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "accountId": "subscription-id",
    "stackId": "unique-nonce",
    "region": "Global",
    "deploymentStatus": "Succeeded",
    "installationId": "uuid",
    "attemptId": "uuid",
    "connectionFields": {
      "clientId": "azure-app-id",
      "tenantId": "azure-tenant-id", 
      "clientSecret": "azure-client-secret",
      "subscriptionId": "azure-subscription-id"
    }
  }'
```
- **Status:** ✅ Working

#### Account Deletion
- **Service:** Salt Security Platform
- **Method:** DELETE
- **Path:** `/v1/cloud-connect/organizations/accounts/azure/{subscription-id}`
- **Purpose:** Notify Salt Security when Azure resources are deleted
- **Authentication:** Bearer token in Authorization header
- **Request Format:** No request body
- **Response Format:** HTTP status code
- **Example:**
```bash
curl -X DELETE "${SALT_HOST}/v1/cloud-connect/organizations/accounts/azure/${SUBSCRIPTION_ID}" \
  -H "Authorization: Bearer ${BEARER_TOKEN}"
```
- **Status:** ✅ Working

### Azure CLI Integration
#### Azure AD Application Management
- **Service:** Azure CLI (`az ad app`)
- **Purpose:** Create and manage Azure AD applications for Salt Security
- **Authentication:** Azure CLI login session
- **Commands Used:**
```bash
# Create application
az ad app create --display-name "SaltAppServicePrincipal-${nonce}"

# Create service principal
az ad sp create --id "${app_id}"

# Create client secret
az ad app credential reset --id "${app_id}" --years 2
```
- **Status:** ✅ Working

#### Azure RBAC Management  
- **Service:** Azure CLI (`az role`)
- **Purpose:** Create custom roles and assign to service principals
- **Authentication:** Azure CLI login session
- **Commands Used:**
```bash
# Create custom role
az role definition create --role-definition role-definition.json

# Assign role
az role assignment create --assignee "${sp_object_id}" \
  --role "SaltCustomAppRole-${nonce}" \
  --scope "/subscriptions/${subscription_id}"
```
- **Status:** ✅ Working

#### Azure Resource Management
- **Service:** Azure CLI (`az account`)
- **Purpose:** Subscription and tenant information retrieval
- **Authentication:** Azure CLI login session  
- **Commands Used:**
```bash
# Get subscription details
az account show --subscription "${subscription_id}"

# List management group subscriptions
az account management-group subscription show-sub-under-mg \
  --name "${management_group_id}"
```
- **Status:** ✅ Working

## Authentication Patterns

### Salt Security API
- **Method:** Bearer Token Authentication
- **Header:** `Authorization: Bearer {token}`
- **Token Source:** User-provided parameter `--bearer-token`
- **Validation:** No client-side token validation performed
- **Supported Endpoints:**
  - `https://api.saltsecurity.com`
  - `https://api.us.saltsecurity.io`
  - `https://api.eu.saltsecurity.io`

### Azure CLI
- **Method:** Azure CLI Authentication Session
- **Prerequisites:** `az login` must be executed prior to script execution
- **Permissions Required:**
  - Azure AD application creation
  - Service principal management
  - Custom role definition
  - Role assignment at subscription scope

## Data Exchange Formats

### Salt Security API Payload Structure
```json
{
  "accountId": "string - Azure subscription ID",
  "stackId": "string - Unique 8-character nonce", 
  "region": "string - Always 'Global' for Azure",
  "errorMessage": "string - Error details if deployment failed",
  "createdBy": "string - Username who initiated deployment",
  "deploymentStatus": "string - Initiated|Succeeded|Failed|Unknown",
  "installationId": "string - UUID for installation tracking",
  "attemptId": "string - UUID for attempt tracking", 
  "connectionFields": {
    "clientId": "string - Azure AD application ID",
    "tenantId": "string - Azure AD tenant ID",
    "clientSecret": "string - Azure AD application secret",
    "subscriptionId": "string - Azure subscription ID"
  }
}
```

### Azure Custom Role Definition
```json
{
  "Name": "SaltCustomAppRole-{nonce}",
  "Description": "Custom role for Salt Security API Management, Kubernetes, and Resource Groups access",
  "Actions": [
    "Microsoft.ApiManagement/*/read",
    "Microsoft.ContainerService/managedClusters/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
```

## Error Handling and Status Codes

### Salt Security API
- **Success:** HTTP 200-299 (treated as successful)
- **Failure:** HTTP 400+ (logged as warnings, deployment continues)
- **Network Errors:** Logged with curl exit codes
- **Timeout:** No explicit timeout configured

### Azure CLI  
- **Success:** Exit code 0
- **Failure:** Non-zero exit codes with JSON error responses
- **Retry Logic:** Implemented for role assignment operations
- **Resource Conflicts:** Handled with unique nonce-based naming

## Integration Status Summary
- **Salt Security API**: ✅ Fully implemented with comprehensive error handling
- **Azure CLI**: ✅ Fully implemented with retry logic and validation
- **Multi-subscription support**: ✅ Parallel processing with individual status reporting
- **Logging integration**: ✅ All API calls logged with request/response details
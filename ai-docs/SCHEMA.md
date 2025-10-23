# External Data Schema - Current Implementation

## Overview
External API data models and Azure resource schemas used by the Salt Security cloud-connect deployment system.

## Salt Security API Data Models

### Deployment Status Request Schema
```json
{
  "accountId": {
    "type": "string",
    "description": "Azure subscription ID",
    "required": true,
    "format": "uuid",
    "example": "12345678-1234-1234-1234-123456789abc"
  },
  "stackId": {
    "type": "string", 
    "description": "Unique deployment identifier (8-character nonce)",
    "required": true,
    "pattern": "^[a-f0-9]{8}$",
    "example": "a1b2c3d4"
  },
  "region": {
    "type": "string",
    "description": "Azure region (always 'Global')",
    "required": true,
    "enum": ["Global"],
    "example": "Global"
  },
  "errorMessage": {
    "type": "string",
    "description": "Error details if deployment failed",
    "required": false,
    "example": "Role assignment failed: insufficient permissions"
  },
  "createdBy": {
    "type": "string",
    "description": "Username who initiated deployment", 
    "required": true,
    "example": "user@example.com"
  },
  "deploymentStatus": {
    "type": "string",
    "description": "Current deployment status",
    "required": true,
    "enum": ["Initiated", "Succeeded", "Failed", "Unknown"],
    "example": "Succeeded"
  },
  "installationId": {
    "type": "string",
    "description": "UUID for installation tracking",
    "required": true,
    "format": "uuid",
    "example": "87654321-4321-4321-4321-210987654321"
  },
  "attemptId": {
    "type": "string",
    "description": "UUID for attempt tracking", 
    "required": true,
    "format": "uuid",
    "example": "11111111-2222-3333-4444-555555555555"
  },
  "connectionFields": {
    "type": "object",
    "description": "Azure connection credentials",
    "required": true,
    "properties": {
      "clientId": {
        "type": "string",
        "description": "Azure AD application ID",
        "format": "uuid"
      },
      "tenantId": {
        "type": "string", 
        "description": "Azure AD tenant ID",
        "format": "uuid"
      },
      "clientSecret": {
        "type": "string",
        "description": "Azure AD application secret",
        "format": "password"
      },
      "subscriptionId": {
        "type": "string",
        "description": "Azure subscription ID", 
        "format": "uuid"
      }
    }
  }
}
```

## Azure CLI Response Schemas

### Azure AD Application Schema
```json
{
  "appId": "string - Application ID (Client ID)",
  "id": "string - Object ID", 
  "displayName": "string - Application display name",
  "identifierUris": "array - Application identifier URIs",
  "homepage": "string - Application homepage URL",
  "availableToOtherTenants": "boolean - Multi-tenant availability"
}
```

### Service Principal Schema  
```json
{
  "appId": "string - Application ID",
  "id": "string - Object ID",
  "displayName": "string - Service principal display name",
  "servicePrincipalNames": "array - Service principal names",
  "servicePrincipalType": "string - Type of service principal"
}
```

### Azure Subscription Schema
```json
{
  "id": "string - Subscription ID",
  "subscriptionId": "string - Subscription ID (duplicate)",
  "tenantId": "string - Tenant ID", 
  "name": "string - Subscription name",
  "user": {
    "name": "string - User email",
    "type": "string - User type"
  },
  "state": "string - Subscription state",
  "isDefault": "boolean - Default subscription flag"
}
```

## Azure Role Definition Schema

### Custom Role Definition
```json
{
  "Name": "string - Role name with nonce suffix",
  "Description": "string - Role description",
  "Actions": [
    "Microsoft.ApiManagement/*/read",
    "Microsoft.ContainerService/managedClusters/read", 
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "string - Subscription scope path"
  ]
}
```

### Role Assignment Schema
```json
{
  "id": "string - Assignment ID",
  "name": "string - Assignment name", 
  "properties": {
    "roleDefinitionId": "string - Role definition ID",
    "principalId": "string - Principal object ID",
    "principalType": "string - Principal type (ServicePrincipal)",
    "scope": "string - Assignment scope"
  }
}
```

## Script Configuration Schema

### Command Line Parameters
```bash
# Required Parameters
--subscription-id="string - Azure subscription ID"
--salt-host="string - Salt Security API host URL" 
--bearer-token="string - Salt Security API bearer token"
--installation-id="string - Installation UUID"
--attempt-id="string - Attempt UUID"

# Optional Parameters  
--app-name="string - Custom Azure AD app name"
--role-name="string - Custom role name"
--management-group-id="string - Azure management group ID"
```

### Environment Variables Schema
```bash
# Azure CLI Configuration
AZURE_SUBSCRIPTION_ID="string - Default subscription ID"
AZURE_TENANT_ID="string - Default tenant ID" 
AZURE_CLIENT_ID="string - Service principal client ID"
AZURE_CLIENT_SECRET="string - Service principal client secret"

# Salt Security Configuration  
SALT_HOST="string - API host URL"
BEARER_TOKEN="string - API authentication token"
```

## Log File Schema

### Log Entry Format
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message content
```

**Log Levels:**
- `INFO` - General information and progress updates
- `WARNING` - Non-fatal issues and degraded functionality  
- `ERROR` - Fatal errors that prevent deployment completion

### Log File Naming Convention
```
{operation}-{nonce}-{timestamp}.log

Examples:
- management-group-deployment-a1b2c3d4-20231215-143022.log
- subscription-deletion-e5f6g7h8-20231215-150445.log
```

## Azure Resource Naming Schema

### Application Naming Pattern
```
Default: SaltAppServicePrincipal-{nonce}
Custom: {app-name}-{nonce}
```

### Role Naming Pattern  
```
Default: SaltCustomAppRole-{nonce}
Custom: {role-name}-{nonce}
```

### Resource Tagging Schema
```json
{
  "CreatedBySalt": "string - Nonce identifier",
  "DeploymentDate": "string - ISO 8601 date",
  "SaltInstallation": "string - Installation ID"
}
```

## External Dependencies Schema

### Required Tools Validation
```json
{
  "az": {
    "command": "az --version",
    "required": true,
    "purpose": "Azure CLI for resource management"
  },
  "jq": {
    "command": "jq --version", 
    "required": true,
    "purpose": "JSON processing and parsing"
  },
  "curl": {
    "command": "curl --version",
    "required": true, 
    "purpose": "HTTP client for Salt Security API"
  },
  "uuidgen": {
    "command": "uuidgen",
    "required": true,
    "purpose": "UUID generation for nonce creation"
  }
}
```
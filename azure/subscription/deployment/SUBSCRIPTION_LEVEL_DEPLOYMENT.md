# Subscription Level Deployment Script

This script automates the creation and configuration of Azure authentication components required for Salt Security integration with your Azure subscription at the subscription level.

## Overview

The script creates a complete Azure authentication setup including:
- **Azure AD Application** - Application identity in Azure Active Directory
- **Client Secret** - Secure password for application authentication
- **Service Principal** - Security identity for automated access
- **Custom Role** - Specific permissions for API Management, Kubernetes, and Resource Groups
- **Role Assignment** - Grants permissions to the service principal
- **Salt Security Integration** - Reports deployment status to Salt Security host

## Prerequisites

### Required Tools
- `az` - Azure CLI (must be logged in)
- `jq` - JSON processor
- `curl` - HTTP client
- `uuidgen` - UUID generator

### Azure Permissions
- Subscription access to target Azure subscription
- Permissions to create Azure AD applications and service principals
- Ability to create custom roles and role assignments

## Usage

### Basic Usage
```bash
./subscription-level-deployment.sh \
  --subscription-id=12345678-1234-1234-1234-123456789012 \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-bearer-token \
  --installation-id=87654321-4321-4321-4321-210987654321 \
  --attempt-id=11111111-2222-3333-4444-555555555555
```

### With Optional Parameters
```bash
./subscription-level-deployment.sh \
  --subscription-id=12345678-1234-1234-1234-123456789012 \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-bearer-token \
  --installation-id=87654321-4321-4321-4321-210987654321 \
  --attempt-id=11111111-2222-3333-4444-555555555555 \
  --app-name=MyCustomApp \
  --role-name=MyCustomRole \
  --created-by="My Organization" \
  --auto-approve
```

### Help
```bash
./subscription-level-deployment.sh --help
```

## Parameters

### Required Parameters
| Parameter | Description | Format |
|-----------|-------------|---------|
| `--subscription-id` | Azure subscription ID | UUID format |
| `--salt-host` | Salt host URL for status updates (will be combined with endpoint path) | HTTP/HTTPS URL |
| `--bearer-token` | Authentication token for Salt host communication | String |
| `--installation-id` | Installation identifier | UUID format |
| `--attempt-id` | Deployment attempt identifier | UUID format |

### Optional Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `--app-name` | Azure AD application name | SaltAppServicePrincipal |
| `--role-name` | Custom role name | SaltCustomAppRole |
| `--created-by` | Creator identifier (quote values with spaces) | Salt Security |
| `--auto-approve` | Skip confirmation prompts | false |

## Interactive Prompts

If `--app-name` and `--role-name` are not provided as flags, the script will prompt for them interactively:
- Application Name (defaults to "SaltAppServicePrincipal")
- Custom Role Name (defaults to "SaltCustomAppRole")

## Permissions Created

The custom role includes these Azure permissions:
- `Microsoft.ApiManagement/*/read` - Read access to API Management services
- `Microsoft.ContainerService/managedClusters/read` - Read access to Kubernetes clusters
- `Microsoft.Resources/subscriptions/resourceGroups/read` - Read access to resource groups

## Resource Naming

All created resources include a unique 8-character nonce for uniqueness:
- Application: `{APP_NAME}-{nonce}`
- Role: `{ROLE_NAME}-{nonce}`
- All resources are tagged with: `CreatedBySalt-{nonce}`

## Logging

The script creates a detailed log file: `subscription-level-deployment-{nonce}-{timestamp}.log`

Log levels include:
- **INFO** - General information and progress
- **WARNING** - Non-critical issues
- **ERROR** - Critical failures

## Error Handling & Cleanup

### Automatic Cleanup
On failure or interruption (Ctrl+C), the script automatically cleans up **only resources created during this run** in reverse order:
1. Role assignments (for the custom role created this run)
2. Custom role definitions (only if created this run)  
3. Service principal (only if created this run)
4. Azure AD application (only if created this run)
5. Temporary files (custom-role.json)

**Note**: The script tracks which resources were created during the current execution and only cleans up those resources, not pre-existing ones.

### Signal Handling
- **SIGINT** (Ctrl+C) - Graceful cleanup and exit
- **SIGTERM** - Graceful cleanup and exit
- **EXIT** - Always runs cleanup function

## Exit Codes

- **0** - Success
- **1** - General error or validation failure
- **130** - Interrupted by user (SIGINT)
- **143** - Terminated (SIGTERM)

## Output

### Success Output
```
=== Service Principal Setup Complete ===
Subscription ID: 12345678-1234-1234-1234-123456789012
Application ID (Client ID): abcdefgh-1234-5678-9012-ijklmnopqrst
Tenant ID: 87654321-4321-4321-4321-210987654321
Service Principal Object ID: 11111111-2222-3333-4444-555555555555
Custom Role ID: /subscriptions/.../roleDefinitions/...
Client Secret: [REDACTED]
```

### Important Notes
- **Save the client secret immediately** - it cannot be retrieved again
- The script changes your Azure CLI context during service principal verification
- Run `az login` again after script completion if you need to use Azure CLI
- On successful deployment, created resources are kept (not cleaned up)

## Security Considerations

- Client secrets are generated with 2-year expiration
- All resources are properly tagged for identification
- Secrets are not logged to console (only to secure log file)
- Backend communication uses bearer token authentication
- Resources are scoped to specific subscription only

## Service Principal Verification

After successful resource creation, the script performs authentication verification:
- Tests service principal login using created credentials
- Retries up to 10 times with 30-second intervals
- **Important**: This temporarily changes your Azure CLI login context
- You must run `az login` again after script completion

## Backend Status Updates

The script sends three status updates to the Salt host:
1. **"Initiated"** - When deployment begins
2. **"Succeeded"/"Failed"** - Based on final outcome  
3. **"Failed"** - On interruption (SIGINT/SIGTERM)

Requests are sent to the full URL constructed by combining the Salt host with the endpoint path `v1/cloud-connect/scan/azure`.

Status updates include connection details (client ID, tenant ID, client secret, subscription ID).

## Troubleshooting

### Common Issues

1. **Azure CLI not logged in**
   ```bash
   az login
   ```

2. **Insufficient permissions**
   - Verify you have Contributor or Owner role on the subscription
   - Ensure you can create Azure AD applications

3. **Service principal verification fails**
   - Azure AD propagation can take time (up to 5 minutes)
   - Script retries up to 10 times with 30-second intervals
   - If verification fails after all retries, deployment is considered failed

4. **Resource already exists**
   - Script uses unique nonce to prevent conflicts
   - If conflicts occur, check for previous failed deployments

### Debug Mode
Check the detailed log file for complete error information and API responses.

## Version

**Script Version**: 2.0 - Uses named flags instead of positional arguments
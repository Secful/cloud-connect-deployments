# Subscription Level Deletion Script

This script automates the identification and deletion of Azure resources created by the Salt Security deployment script. It safely removes Azure authentication components from your Azure subscription at the subscription level.

## Overview

The script discovers and deletes Azure resources created during deployment including:
- **Azure AD Application** - Application identity in Azure Active Directory
- **Client Secret** - Automatically deleted with the application
- **Service Principal** - Security identity for automated access  
- **Custom Role** - Salt Security specific permissions
- **Role Assignments** - Permissions granted to the service principal
- **Salt Security Integration** - Notifies Salt Security host of deletion status

## Prerequisites

### Required Tools
- `az` - Azure CLI (must be logged in)
- `jq` - JSON processor
- `curl` - HTTP client

### Azure Permissions
- Subscription access to target Azure subscription
- Permissions to delete Azure AD applications and service principals
- Ability to delete custom roles and role assignments

## Usage

### Basic Usage
```bash
./subscription-level-deletion.sh \
  --subscription-id=12345678-1234-1234-1234-123456789012 \
  --nonce=a1b2c3d4 \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-bearer-token
```

### With Optional Parameters
```bash
./subscription-level-deletion.sh \
  --subscription-id=12345678-1234-1234-1234-123456789012 \
  --nonce=a1b2c3d4 \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-bearer-token \
  --auto-approve
```

### Dry Run Mode
```bash
./subscription-level-deletion.sh \
  --subscription-id=12345678-1234-1234-1234-123456789012 \
  --nonce=a1b2c3d4 \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-bearer-token \
  --dry-run
```

### Help
```bash
./subscription-level-deletion.sh --help
```

## Parameters

### Required Parameters
| Parameter | Description | Format |
|-----------|-------------|---------|
| `--subscription-id` | Azure subscription ID | UUID format |
| `--nonce` | 8-character hexadecimal nonce from deployment | Hex string (e.g., a1b2c3d4) |
| `--salt-host` | Salt host URL for status updates (will be combined with endpoint path) | HTTP/HTTPS URL |
| `--bearer-token` | Authentication token for Salt host communication | String |

### Optional Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `--auto-approve` | Skip confirmation prompts | false |
| `--dry-run` | Identify resources without deleting them | false |

## Resource Discovery

The script discovers resources by searching for the unique nonce suffix:
- **Azure AD Applications**: Searches for applications with display names containing `-{nonce}`
- **Service Principals**: Located via associated Azure AD application
- **Custom Roles**: Searches for roles with names containing `-{nonce}`
- **Tag Verification**: Confirms resources have expected `CreatedBySalt-{nonce}` tag

### Discovery Process
1. Validates Azure CLI authentication and subscription access
2. Initial confirmation prompt (unless `--auto-approve` is used)
3. Searches for Azure AD applications with nonce suffix
4. Locates associated service principal using application ID
5. Searches for custom roles with nonce suffix
6. Summarizes all discovered resources
7. Final confirmation prompt before deletion (unless `--auto-approve` is used)

## Deletion Process

Resources are deleted in proper dependency order to avoid conflicts:

1. **Role Assignments** - Removes explicit role assignments (if any exist)
2. **Custom Role Definition** - Deletes the custom role
3. **Service Principal** - Removes the service principal
4. **Azure AD Application** - Deletes the application and its client secrets

### Safety Features
- **Nonce Validation**: Only deletes resources matching the exact nonce
- **Tag Verification**: Warns if resources lack expected Salt Security tags
- **Dry Run Mode**: Identifies resources without performing deletions
- **Dual Confirmation System**: Two confirmation prompts - before discovery and after seeing exactly what will be deleted (unless `--auto-approve` is used)

## Logging

The script creates a detailed log file: `subscription-level-deletion-{nonce}-{timestamp}.log`

Log levels include:
- **INFO** - General information and progress
- **WARNING** - Non-critical issues or missing resources
- **ERROR** - Critical failures during deletion

## Exit Codes

- **0** - Success (all discovered resources deleted)
- **1** - Error (validation failure, resource discovery failed, or deletion errors)

## Output

### Success Output
```
=== DELETION COMPLETED SUCCESSFULLY ===
All discovered resources with nonce 'a1b2c3d4' have been deleted.

Resources deleted:
✅ Azure AD Application: SaltAppServicePrincipal-a1b2c3d4 (app-id)
✅ Service Principal: object-id
✅ Custom Role: SaltCustomAppRole-a1b2c3d4 (role-id)
```

### Dry Run Output  
```
DRY RUN MODE - No resources will actually be deleted

Resources to be deleted:
   Azure AD Application: SaltAppServicePrincipal-a1b2c3d4 (app-id)
   Service Principal: object-id  
   Custom Role: SaltCustomAppRole-a1b2c3d4 (role-id)

Total resources to be deleted: 3
```

## Interactive Prompts

Unless `--auto-approve` is specified, the script provides two confirmation prompts for enhanced safety:

### Initial Confirmation (Before Resource Discovery)
```
Do you want to proceed with the deletion? (y/n):
```

### Final Confirmation (After Resource Discovery)
After discovering resources, the script shows exactly what will be deleted and asks for final confirmation:
```
Do you want to proceed with deleting the discovered resources? (y/n):
```

**Response options for both prompts:**
- **y** - Proceeds to next step or deletion
- **n** - Cancels deletion with "Deletion cancelled by user" message

**Auto-Approve Behavior:**
When `--auto-approve` is used, both confirmation prompts are automatically bypassed, and the script proceeds directly through resource discovery to deletion.

## Backend Status Updates

The script sends deletion status to the Salt Security host:
- **DELETE request** sent to `{salt-host}/v1/cloud-connect/organizations/accounts/azure/{subscription-id}`
- **Authorization** using bearer token
- **Status**: "Succeeded" or "Failed" based on deletion outcome
- **Graceful handling** of Salt host communication failures

Requests are sent to the full URL constructed by combining the Salt host with the endpoint path `v1/cloud-connect/organizations/accounts/azure` and the subscription ID.

Backend communication failures do not prevent Azure resource deletion from completing.

## Security Considerations

- Resources are only deleted if they match the exact nonce pattern
- Tag verification helps prevent accidental deletion of non-Salt resources
- Backend communication uses secure bearer token authentication
- Dry run mode allows safe resource identification
- Detailed logging provides audit trail of all operations

## Error Handling

### Common Scenarios

1. **No Resources Found**
   - Warning message indicates resources may already be deleted or nonce is incorrect
   - Script exits with code 1

2. **Partial Resource Discovery**
   - Script reports missing resources as "Not found (nothing to delete)"
   - Continues with deletion of discovered resources

3. **Deletion Failures**
   - Script continues with remaining resources despite individual failures
   - Final status indicates "completed with errors"
   - Exit code 1 returned

4. **Backend Communication Failures**
   - Warning logged but Azure deletion continues
   - Resources are still deleted successfully

## Troubleshooting

### Common Issues

1. **Azure CLI not logged in**
   ```bash
   az login
   ```

2. **Insufficient permissions**
   - Verify you have Contributor or Owner role on the subscription
   - Ensure you can delete Azure AD applications

3. **Invalid nonce format**
   - Nonce must be exactly 8 hexadecimal characters
   - Check deployment logs for correct nonce value

4. **Resources not found**
   - Verify nonce is correct from deployment logs
   - Resources may have been manually deleted
   - Check subscription context is correct

### Debug Mode
Check the detailed log file for complete error information and API responses.

## Version

**Script Version**: 1.0 - Uses named flags and supports dry-run mode
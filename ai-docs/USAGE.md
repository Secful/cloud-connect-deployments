# Usage Guide

## Overview
Shell script-based deployment automation for Salt Security cloud connectivity integration with Azure subscriptions and management groups.

## Command Line Interface

### Subscription-Level Deployment
```bash
./azure/subscription/deployment/subscription-level-deployment.sh \
  --subscription-id=12345678-1234-1234-1234-123456789abc \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-salt-api-token \
  --installation-id=87654321-4321-4321-4321-210987654321 \
  --attempt-id=11111111-2222-3333-4444-555555555555 \
  [--app-name=CustomAppName] \
  [--role-name=CustomRoleName]
```

### Management Group-Level Deployment
```bash
./azure/management-group/deployment/management-group-level-deployment.sh \
  --management-group-id=your-management-group-id \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-salt-api-token \
  --installation-id=87654321-4321-4321-4321-210987654321 \
  --attempt-id=11111111-2222-3333-4444-555555555555 \
  [--app-name=CustomAppName] \
  [--role-name=CustomRoleName]
```

### Resource Deletion
```bash
# Subscription-level deletion
./azure/subscription/deletion/subscription-level-deletion.sh \
  --subscription-id=12345678-1234-1234-1234-123456789abc \
  --nonce=a1b2c3d4 \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-salt-api-token

# Management group-level deletion  
./azure/management-group/deletion/management-group-deletion.sh \
  --management-group-id=your-management-group-id \
  --nonce=a1b2c3d4 \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=your-salt-api-token
```

## Configuration

### Prerequisites
1. **Azure CLI Authentication**
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Required Tools Installation**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install jq curl uuid-runtime
   
   # macOS
   brew install jq curl
   ```

3. **Salt Security API Access**
   - Obtain bearer token from Salt Security platform
   - Verify access to target Salt Security endpoint (US/EU/Global)

### Parameter Configuration
- **Required Parameters**: Always needed for script execution
- **Optional Parameters**: Have sensible defaults but can be customized
- **Salt Security Integration**: Can be disabled by omitting `--salt-host` and `--bearer-token`

## Examples

### Basic Azure Subscription Integration
```bash
#!/bin/bash
# Basic deployment with minimal parameters
./azure/subscription/deployment/subscription-level-deployment.sh \
  --subscription-id=12345678-1234-1234-1234-123456789abc \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9... \
  --installation-id=87654321-4321-4321-4321-210987654321 \
  --attempt-id=11111111-2222-3333-4444-555555555555
```

### Custom Resource Naming
```bash
#!/bin/bash  
# Deployment with custom application and role names
./azure/subscription/deployment/subscription-level-deployment.sh \
  --subscription-id=12345678-1234-1234-1234-123456789abc \
  --salt-host=https://api.saltsecurity.com \
  --bearer-token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9... \
  --installation-id=87654321-4321-4321-4321-210987654321 \
  --attempt-id=11111111-2222-3333-4444-555555555555 \
  --app-name=MyCompanySaltApp \
  --role-name=MyCompanySaltRole
```

### Multi-Subscription Management Group Deployment
```bash
#!/bin/bash
# Deploy across all subscriptions in a management group
./azure/management-group/deployment/management-group-level-deployment.sh \
  --management-group-id=mg-production-workloads \
  --salt-host=https://api.us.saltsecurity.io \
  --bearer-token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9... \
  --installation-id=87654321-4321-4321-4321-210987654321 \
  --attempt-id=11111111-2222-3333-4444-555555555555
```

### Offline/Local-Only Deployment
```bash  
#!/bin/bash
# Deploy without Salt Security integration (local Azure resources only)
./azure/subscription/deployment/subscription-level-deployment.sh \
  --subscription-id=12345678-1234-1234-1234-123456789abc
  # Note: No salt-host or bearer-token parameters
```

## Output and Logging

### Console Output
- **Color-coded status messages**: Green (success), Red (error), Yellow (warning)
- **Progress indicators**: Step-by-step deployment progress
- **Resource information**: Created resource IDs and names
- **Important warnings**: Security notes and manual action requirements

### Log Files
- **Location**: Current working directory
- **Naming**: `{operation}-{nonce}-{timestamp}.log`
- **Content**: Complete operation history with timestamps
- **Format**: `[YYYY-MM-DD HH:MM:SS] [LEVEL] Message`

### Success Indicators
- **Exit Code 0**: Successful deployment
- **Resource Creation**: Azure AD app, service principal, custom role, role assignment
- **Salt Integration**: Successful API communication and status reporting
- **Credentials**: Client secret generated and transmitted to Salt Security

### Error Handling
- **Parameter Validation**: Early exit with usage help for missing parameters  
- **Dependency Checks**: Tool availability verification before execution
- **Azure Errors**: Detailed error messages with remediation suggestions
- **API Failures**: Graceful degradation with warning messages
- **Rollback**: Automatic cleanup of partially created resources on failure
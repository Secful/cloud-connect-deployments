# Manual Test Plan for Azure Deployment Script

## Overview

This manual test plan provides step-by-step instructions for manually validating the Azure deployment script functionality across all critical scenarios.

**Target Script**: `subscription-level-deployment.sh`  
**Test Environment**: Azure Cloud Shell (recommended) or local environment with Azure CLI  
**Prerequisites**: Active Azure subscription with appropriate permissions  

⚠️ **Important**: Use a dedicated test Azure subscription, never production environments.

## Test Environment Setup

### Prerequisites Checklist
- [ ] Azure CLI installed and accessible (`az --version`)
- [ ] jq utility available (`jq --version`) 
- [ ] curl available (`curl --version`)
- [ ] uuidgen utility available (`uuidgen`)
- [ ] Test Azure subscription access
- [ ] Sufficient permissions for creating Azure AD apps, service principals, and custom roles

### Script Usage
The script now uses named flags for all parameters:
```bash
./subscription-level-deployment.sh --subscription-id=<id> --salt-host=<url> --bearer-token=<token> --installation-id=<id> --attempt-id=<id> [--app-name=<name>] [--role-name=<name>] [--created-by=<name>] [--auto-approve] [--help]
```

**Required flags:**
- `--subscription-id=<uuid>` - Azure subscription ID
- `--salt-host=<url>` - Salt host URL (will be combined with endpoint path)
- `--bearer-token=<token>` - Authentication bearer token
- `--installation-id=<uuid>` - Installation identifier
- `--attempt-id=<uuid>` - Attempt identifier

**Optional flags:**
- `--app-name=<name>` - Application name (defaults to interactive prompt)
- `--role-name=<name>` - Custom role name (defaults to interactive prompt)  
- `--created-by=<name>` - Created by identifier (defaults to "Salt Security")
- `--auto-approve` - Skip confirmation prompts
- `--help` - Show usage information

### Command Line Examples
```bash
# Using flags (recommended approach):
./subscription-level-deployment.sh \
  --subscription-id="your-test-subscription-id" \
  --salt-host="https://api.test.com/webhook" \
  --bearer-token="test-token-123" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve

# With optional parameters:
./subscription-level-deployment.sh \
  --subscription-id="your-test-subscription-id" \
  --salt-host="https://api.test.com/webhook" \
  --bearer-token="test-token-123" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --app-name="ManualTestApp" \
  --role-name="ManualTestRole" \
  --created-by="Manual Test User" \
  --auto-approve

# Interactive mode (without --auto-approve, prompts for app/role names):
./subscription-level-deployment.sh \
  --subscription-id="your-test-subscription-id" \
  --salt-host="https://api.test.com/webhook" \
  --bearer-token="test-token-123" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)"

# Get help:
./subscription-level-deployment.sh --help
```

### Environment Variables (Still Supported)
Environment variables are still supported as fallbacks when flags are not provided:

```bash
export SUBSCRIPTION_ID="your-test-subscription-id"
export SALT_HOST="https://api.test.com/webhook"
export BEARER_TOKEN="test-token-123"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="ManualTestApp"                   # Optional
export ROLE_NAME="ManualTestRole"                 # Optional
export CREATED_BY="Manual Test User"              # Optional

# Then run with flags taking precedence:
./subscription-level-deployment.sh --auto-approve
```

## Test Categories and Scenarios

### 1. Dependencies & Environment Tests

#### DEP-001: Missing Azure CLI ✅
**Objective**: Verify behavior when `az` command is not available.

**Steps**:

1. Temporarily rename or move the `az` command (check actual location first with `which az`):
   - Common locations: `/usr/bin/az`, `/opt/homebrew/bin/az`, `/usr/local/bin/az`
   - Example: `sudo mv /opt/homebrew/bin/az /opt/homebrew/bin/az.bak`
2. Run the deployment script: `./subscription-level-deployment.sh --auto-approve`
3. Observe the error message

**Expected Results**:
- Script exits with code 1
- Error message: "Required command 'az' not found"
- Script does not proceed past dependency check

**Cleanup**: Restore the original command (adjust path as needed):
   - Example: `sudo mv /opt/homebrew/bin/az.bak /opt/homebrew/bin/az`

#### DEP-002: Missing jq Utility
**Objective**: Test behavior when jq is not available.

**Steps**:
1. Temporarily make jq unavailable (check actual location first with `which jq`):
   - If jq is in `/usr/bin/jq` (system protected): Temporarily modify PATH: `export PATH=$(echo $PATH | sed 's|/usr/bin:||g')`
   - If jq is in `/opt/homebrew/bin/jq`: `sudo mv /opt/homebrew/bin/jq /opt/homebrew/bin/jq.bak`
   - If jq is in `/usr/local/bin/jq`: `sudo mv /usr/local/bin/jq /usr/local/bin/jq.bak`
2. Run: `./subscription-level-deployment.sh --auto-approve`
3. Check error handling

**Expected Results**:
- Script exits with error
- Clear message about missing jq dependency
- No partial execution

**Cleanup**: Restore access to jq:
   - If you modified PATH: Reset it with `export PATH="/usr/bin:$PATH"` or start a new terminal session
   - If you moved a file: `sudo mv /opt/homebrew/bin/jq.bak /opt/homebrew/bin/jq` (adjust path as needed)

#### DEP-003: Not Logged into Azure CLI ✅
**Objective**: Verify authentication check works correctly.

**Steps**:
1. Log out of Azure: `az logout`
2. Run: `./subscription-level-deployment.sh --auto-approve`
3. Verify error handling

**Expected Results**:
- Script exits with code 1
- Error message: "Not logged into Azure CLI"
- Suggestion to run `az login`
- No Azure resource creation attempts

**Cleanup**: `az login` and set appropriate subscription

#### DEP-004: Missing curl Utility
**Objective**: Test behavior when curl is not available for backend communication.

**Steps**:
1. Temporarily make curl unavailable (check actual location first with `which curl`):
   - If curl is in `/usr/bin/curl` (system protected): Temporarily modify PATH: `export PATH=$(echo $PATH | sed 's|/usr/bin:||g')`
   - If curl is in `/opt/homebrew/bin/curl`: `sudo mv /opt/homebrew/bin/curl /opt/homebrew/bin/curl.bak`
   - If curl is in `/usr/local/bin/curl`: `sudo mv /usr/local/bin/curl /usr/local/bin/curl.bak`
2. Run: `./subscription-level-deployment.sh --auto-approve`
3. Check error handling

**Expected Results**:
- Script exits with error during dependency check
- Clear message about missing curl dependency
- No partial execution

**Cleanup**: Restore access to curl:
   - If you modified PATH: Reset it with `export PATH="/usr/bin:$PATH"` or start a new terminal session
   - If you moved a file: `sudo mv /opt/homebrew/bin/curl.bak /opt/homebrew/bin/curl` (adjust path as needed)

#### DEP-005: Missing uuidgen Utility
**Objective**: Test behavior when uuidgen is not available for nonce generation.

**Steps**:
1. Temporarily make uuidgen unavailable (check actual location first with `which uuidgen`):
   - If uuidgen is in `/usr/bin/uuidgen`: Temporarily modify PATH: `export PATH=$(echo $PATH | sed 's|/usr/bin:||g')`
   - If uuidgen is in `/opt/homebrew/bin/uuidgen`: `sudo mv /opt/homebrew/bin/uuidgen /opt/homebrew/bin/uuidgen.bak`
2. Run: `./subscription-level-deployment.sh --auto-approve`
3. Check error handling

**Expected Results**:
- Script exits with error during dependency check
- Clear message about missing uuidgen dependency
- No partial execution

**Cleanup**: Restore access to uuidgen:
   - If you modified PATH: Reset it with `export PATH="/usr/bin:$PATH"` or start a new terminal session
   - If you moved a file: `sudo mv /opt/homebrew/bin/uuidgen.bak /opt/homebrew/bin/uuidgen` (adjust path as needed)

### 2. Input Validation Tests

#### INP-001: Invalid Subscription ID Format ✅
**Objective**: Test subscription ID validation.

**Test Cases**:
```bash
# Test each invalid format:
export SUBSCRIPTION_ID="invalid-uuid"
./subscription-level-deployment.sh --auto-approve

export SUBSCRIPTION_ID="12345"
./subscription-level-deployment.sh --auto-approve

export SUBSCRIPTION_ID=""
./subscription-level-deployment.sh --auto-approve
```

**Expected Results** (for each case):
- Script exits with code 1
- Error: "Invalid subscription ID format"
- No authentication attempts

#### INP-002: Invalid Application Name ✅
**Objective**: Test application name validation.

**Test Cases**:
```bash
# Test various invalid names:
export APP_NAME=""
export APP_NAME="App Name With Spaces"
export APP_NAME="App@Invalid#Characters"
export APP_NAME="App|With|Pipes"
```

**Expected Results**:
- Script exits with validation error
- Clear error message about invalid app name format
- No Azure resources created

#### INP-003: Invalid Role Name ✅
**Objective**: Test custom role name validation.

**Test Cases**:
```bash
# Test invalid role names:
export ROLE_NAME=""
export ROLE_NAME="Role Name With Spaces"
export ROLE_NAME="Role@Invalid!Characters"
```

**Expected Results**:
- Validation error before resource creation
- Clear error message about role name format
- Script exits cleanly

#### INP-004: Missing Required Parameters ✅
**Objective**: Test validation of all mandatory parameters.

**Test Cases**:
```bash
# Test missing subscription ID:
./subscription-level-deployment.sh \
  --salt-host="https://api.test.com" \
  --bearer-token="test-token" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve

# Test missing backend URL:
./subscription-level-deployment.sh \
  --subscription-id="$(uuidgen)" \
  --bearer-token="test-token" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve

# Test missing bearer token:
./subscription-level-deployment.sh \
  --subscription-id="$(uuidgen)" \
  --salt-host="https://api.test.com" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve

# Test missing installation ID:
./subscription-level-deployment.sh \
  --subscription-id="$(uuidgen)" \
  --salt-host="https://api.test.com" \
  --bearer-token="test-token" \
  --attempt-id="$(uuidgen)" \
  --auto-approve

# Test missing attempt ID:
./subscription-level-deployment.sh \
  --subscription-id="$(uuidgen)" \
  --salt-host="https://api.test.com" \
  --bearer-token="test-token" \
  --installation-id="$(uuidgen)" \
  --auto-approve

# Test empty parameters (passed as empty values):
./subscription-level-deployment.sh \
  --subscription-id="" \
  --salt-host="https://api.test.com" \
  --bearer-token="token" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve

./subscription-level-deployment.sh \
  --subscription-id="$(uuidgen)" \
  --salt-host="" \
  --bearer-token="token" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve
```

**Expected Results**:
- Script exits with validation error for each missing parameter
- Error: "Missing required parameters: --subscription-id --salt-host" (for missing flags)
- Error: "All required parameters must have non-empty values" (for empty flag values)
- No authentication or resource creation attempts

#### INP-005: Invalid Backend URL Format ✅
**Objective**: Test backend URL validation.

**Test Cases**:
```bash
# Test invalid URL formats:
export SALT_HOST="invalid-url"
export SALT_HOST="ftp://invalid.protocol.com"
export SALT_HOST="api.test.com"  # Missing protocol
```

**Expected Results**:
- Script exits with validation error
- Error: "Invalid backend URL format"
- Error: "Backend URL must start with http:// or https://"

#### INP-006: Invalid UUID Format ✅
**Objective**: Test UUID validation for installation and attempt IDs.

**Test Cases**:
```bash
# Test invalid installation ID:
export INSTALLATION_ID="invalid-uuid"
./subscription-level-deployment.sh --auto-approve

# Test invalid attempt ID:
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="12345-invalid"
./subscription-level-deployment.sh --auto-approve
```

**Expected Results**:
- Script exits with validation error
- Error: "Invalid installation ID format" or "Invalid attempt ID format"
- Expected format message displayed

### 3. Authentication & Permissions Tests

#### AUTH-001: Insufficient Permissions
**Objective**: Test with a user lacking sufficient permissions.

**Prerequisites - Check Current Permissions**:
```bash
# Method 1: Check current user identity and role assignments
CURRENT_USER=$(az account show --query user.name -o tsv 2>/dev/null)
CURRENT_USER_ID=$(az account show --query user.name -o tsv 2>/dev/null)

if [ -n "$CURRENT_USER" ]; then
    echo "Current user: $CURRENT_USER"
    # Try different approaches for role assignment listing
    az role assignment list --assignee "$CURRENT_USER" --scope /subscriptions/$SUBSCRIPTION_ID 2>/dev/null || \
    az role assignment list --assignee "$CURRENT_USER_ID" --scope /subscriptions/$SUBSCRIPTION_ID 2>/dev/null || \
    az role assignment list --all --query "[?principalName=='$CURRENT_USER']" --scope /subscriptions/$SUBSCRIPTION_ID 2>/dev/null || \
    echo "❌ Could not retrieve role assignments (this may indicate limited permissions)"
else
    echo "❌ Could not retrieve current user identity"
fi

# Method 2: Test specific permissions needed by the script
echo "Testing Azure AD application creation permissions..."
az ad app create --display-name "PermissionTest-$(date +%s)" --dry-run 2>/dev/null && echo "✅ Can create AD apps" || echo "❌ Cannot create AD apps"

echo "Testing custom role creation permissions..."
az role definition list --scope /subscriptions/$SUBSCRIPTION_ID --query "[0]" >/dev/null 2>&1 && echo "✅ Can read role definitions" || echo "❌ Cannot read role definitions"

echo "Testing role assignment permissions..."
az role assignment list --scope /subscriptions/$SUBSCRIPTION_ID --query "[0]" >/dev/null 2>&1 && echo "✅ Can read role assignments" || echo "❌ Cannot read role assignments"

# Method 3: Check subscription-level permissions
echo "Testing subscription access..."
az account show --subscription $SUBSCRIPTION_ID >/dev/null 2>&1 && echo "✅ Can access subscription" || echo "❌ Cannot access subscription"
```

**Setup - Create Limited User (Optional)**:
If you want to test with truly limited permissions, you need to either:
1. **Use a different Azure account** with limited permissions, OR
2. **Create a test user** (requires Global Administrator rights):
```bash
# Create test user (requires admin rights)
az ad user create --display-name "TestLimitedUser" --password "TempPassword123!" --user-principal-name "testuser@yourdomain.onmicrosoft.com"

# Assign only Reader role
az role assignment create --assignee "testuser@yourdomain.onmicrosoft.com" --role "Reader" --scope "/subscriptions/$SUBSCRIPTION_ID"
```

**Steps**:
1. **Check current permissions** using commands above
2. If you have full permissions, this test is **informational only** - you cannot easily downgrade your own permissions
3. Run: `./subscription-level-deployment.sh --auto-approve`
4. **OR** if testing with limited user: 
   - `az logout` 
   - `az login` (use limited user credentials)
   - Run the script
5. Observe permission errors

**Expected Results**:
- If you have sufficient permissions: Script succeeds (test passes by default)
- If you have insufficient permissions: 
  - Script fails during resource creation
  - Error messages like "insufficient privileges" or "authorization failed"
  - Partial resources may be created (verify cleanup)

**Note**: This test is primarily **documentation** of expected behavior rather than easily reproducible, unless you have access to multiple Azure accounts with different permission levels.

#### AUTH-002: Invalid Subscription ID ✅
**Objective**: Test with non-existent subscription.

**Steps**:
1. Set: `export SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"`
2. Run the script
3. Verify error handling

**Expected Results**:
- Error during subscription access
- Script exits with appropriate error code
- No resource creation attempts

### 4. Resource Creation Tests

#### RES-001: Successful Full Deployment (Happy Path) ✅
**Objective**: Test complete successful deployment workflow.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"  # Test endpoint
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="TestSuccessApp"
export ROLE_NAME="TestSuccessRole"
```

**Steps**:
1. Ensure clean environment (no existing resources with same names)
2. Run: `./subscription-level-deployment.sh --auto-approve`
3. Monitor output for all deployment phases

**Expected Results**:
- Script exits with code 0
- All phases complete successfully:
  - Azure authentication setup
  - Creating Azure AD application
  - Creating client secret
  - Creating service principal
  - Retrieving tenant ID
  - Creating custom role
  - Assigning custom role
  - Service principal verification
  - Backend status updates (if configured)

**Output Verification**:
- Application ID displayed
- Tenant ID displayed  
- Service Principal Object ID displayed
- Custom Role ID displayed
- Client Secret displayed (masked)
- "Service Principal Setup Complete" message

**Manual Verification**:
```bash
# Verify resources were created
az ad app list --display-name "TestSuccessApp"
az ad sp list --display-name "TestSuccessApp"
az role definition list --name "TestSuccessRole" --custom-role-only
```

#### RES-002: Resource Name Uniqueness Verification ✅
**Objective**: Verify that resources are created with unique names using nonce suffixes.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="TestApp"
export ROLE_NAME="TestRole"
```

**Steps**:
1. Run the script first time: `./subscription-level-deployment.sh --auto-approve`
2. Note the nonce used in resource names (from output or log)
3. Run the script second time: `./subscription-level-deployment.sh --auto-approve`
4. Verify both deployments succeed without conflicts

**Expected Results**:
- First run creates resources with names like `TestApp-a1b2c3d4`, `TestRole-a1b2c3d4`
- Second run creates resources with different nonce like `TestApp-e5f6g7h8`, `TestRole-e5f6g7h8`
- Both deployments succeed independently
- No name conflicts occur
- Each deployment uses a unique 8-character hex nonce

#### RES-003: Partial Failure Scenario ✅
**Objective**: Test cleanup when deployment fails mid-process.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="TestApp"
export ROLE_NAME="TestRole"
```

**Steps**:
1. Run script and interrupt during service principal creation (Ctrl+C)
2. Verify partial cleanup occurs
3. Check for orphaned resources

**Expected Results**:
- Script handles interrupt signal
- Cleanup process executes
- Partial resources are cleaned up
- Appropriate cleanup message: "Successfully deleted the created resources" or "Cleanup completed (no Azure resources were created)"

### 5. Error Handling & Cleanup Tests

#### ERR-001: SIGINT Cleanup (Ctrl+C) ✅
**Objective**: Test cleanup behavior when interrupted.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Press Ctrl+C after application creation starts
3. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT signal
- Displays "Received interrupt signal" message
- Executes cleanup routine
- Deletes created resources (if any were created)
- Shows appropriate cleanup completion message
- Exits with code 130

**Verification**:
```bash
# Check no orphaned resources remain
az ad app list --display-name "TestApp"
az ad sp list --display-name "TestApp"  
az role definition list --name "TestRole" --custom-role-only
```

#### ERR-001a: Interrupt During Dependency Check ✅
**Objective**: Test interrupt behavior during initial dependency validation.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Press Ctrl+C immediately during "Checking required dependencies..." message
3. Observe behavior

**Expected Results**:
- Script catches SIGINT signal immediately
- Shows "Received interrupt signal" message
- Cleanup function runs but finds no Azure resources to clean
- Shows "Cleanup completed (no Azure resources were created). Check log file: [filename]"
- Log file contains interrupt details
- Exits with code 130

#### ERR-001b: Interrupt During Azure Authentication ✅
**Objective**: Test interrupt behavior during Azure CLI authentication check.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Press Ctrl+C during "Checking Azure CLI authentication..." phase
3. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT during auth check
- Shows interrupt message
- Cleanup runs but no Azure resources exist yet
- Shows "Cleanup completed (no Azure resources were created). Check log file: [filename]"
- Exits with code 130

#### ERR-001c: Interrupt During Azure AD Application Creation ✅
**Objective**: Test interrupt behavior during application creation phase.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="InterruptTestApp"
export ROLE_NAME="InterruptTestRole"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Wait for "AZURE AD APPLICATION SETUP" section to appear
3. Press Ctrl+C during "Creating Azure AD application" phase
4. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT during app creation
- Cleanup function checks for and deletes any created Azure AD application
- Shows "Successfully deleted the created resources. Check log file: [filename]" (GREEN with ✅)
- Log shows specific resources that were cleaned up
- Exits with code 130

**Verification**:
```bash
# Verify no orphaned application exists
az ad app list --display-name "InterruptTestApp*"
```

#### ERR-001d: Interrupt During Client Secret Creation ✅
**Objective**: Test interrupt behavior during client secret creation phase.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="InterruptSecretApp"
export ROLE_NAME="InterruptSecretRole"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Wait for Azure AD application to be created successfully
3. Press Ctrl+C during "Creating client secret..." phase
4. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT during secret creation
- Cleanup deletes the Azure AD application (created before interrupt)
- Shows "Successfully deleted the created resources. Check log file: [filename]" (GREEN with ✅)
- No service principal or role resources created yet
- Exits with code 130

**Verification**:
```bash
# Verify application was cleaned up
az ad app list --display-name "InterruptSecretApp*"
```

#### ERR-001e: Interrupt During Service Principal Creation ✅
**Objective**: Test interrupt behavior during service principal creation phase.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="InterruptSPApp"
export ROLE_NAME="InterruptSPRole"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Wait for "SERVICE PRINCIPAL CREATION" section to appear
3. Press Ctrl+C during "Creating service principal..." phase
4. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT during service principal creation
- Cleanup deletes Azure AD application and any created service principal
- Shows "Successfully deleted the created resources. Check log file: [filename]" (GREEN with ✅)
- Log shows specific cleanup actions taken
- Exits with code 130

**Verification**:
```bash
# Verify all resources cleaned up
az ad app list --display-name "InterruptSPApp*"
az ad sp list --display-name "InterruptSPApp*"
```

#### ERR-001f: Interrupt During Custom Role Creation ✅
**Objective**: Test interrupt behavior during custom role creation phase.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="InterruptRoleApp"
export ROLE_NAME="InterruptRoleRole"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Wait for "PERMISSION CONFIGURATION" section to appear
3. Press Ctrl+C during "Creating custom role..." phase
4. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT during role creation
- Cleanup deletes service principal and Azure AD application
- Temporary role definition file (custom-role.json) is removed
- Shows "Successfully deleted the created resources. Check log file: [filename]" (GREEN with ✅)
- Exits with code 130

**Verification**:
```bash
# Verify all resources cleaned up
az ad app list --display-name "InterruptRoleApp*"
az ad sp list --display-name "InterruptRoleApp*"
az role definition list --name "InterruptRoleRole*" --custom-role-only
ls custom-role.json  # Should not exist
```

#### ERR-001g: Interrupt During Role Assignment ✅
**Objective**: Test interrupt behavior during role assignment phase.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="InterruptAssignApp"
export ROLE_NAME="InterruptAssignRole"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Wait for custom role to be created successfully
3. Press Ctrl+C during "Assigning custom role to service principal..." phase
4. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT during role assignment
- Cleanup deletes all created resources in proper order:
  1. Role assignments (if any were created)
  2. Custom role definition
  3. Service principal
  4. Azure AD application
- Shows "Successfully deleted the created resources. Check log file: [filename]" (GREEN with ✅)
- Exits with code 130

**Verification**:
```bash
# Verify complete cleanup
az ad app list --display-name "InterruptAssignApp*"
az ad sp list --display-name "InterruptAssignApp*"
az role definition list --name "InterruptAssignRole*" --custom-role-only
az role assignment list --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[?contains(principalName, 'InterruptAssignApp')]"
```

#### ERR-001h: Interrupt During Service Principal Verification ✅
**Objective**: Test interrupt behavior during final service principal verification phase.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="InterruptVerifyApp"
export ROLE_NAME="InterruptVerifyRole"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve`
2. Wait for role assignment to complete successfully
3. Press Ctrl+C during "Verifying service principal authentication readiness..." phase
4. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT during verification
- All Azure resources (app, SP, role, assignments) have been created
- Cleanup deletes ALL created resources in proper order
- Shows "Successfully deleted the created resources. Check log file: [filename]" (GREEN with ✅)
- Exits with code 130

**Verification**:
```bash
# Verify complete cleanup of fully deployed resources
az ad app list --display-name "InterruptVerifyApp*"
az ad sp list --display-name "InterruptVerifyApp*"
az role definition list --name "InterruptVerifyRole*" --custom-role-only
az role assignment list --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[?contains(principalName, 'InterruptVerifyApp')]"
```

**Important Notes for All Interrupt Tests**:
1. **Color Coding**: Interrupt cleanup shows GREEN messages with ✅ (indicating successful cleanup after intentional interruption)
2. **Log File Reference**: All cleanup completion messages include log file location
3. **No DEPLOYMENT SUMMARY**: Interrupted scripts skip the normal DEPLOYMENT SUMMARY section and show results only in cleanup messages
4. **Exit Code**: All interrupts should exit with code 130
5. **Resource Cleanup Order**: Resources are always cleaned in reverse order of creation (assignments → role → service principal → application)
6. **Safety Feature**: Script only deletes resources it created during the current execution, never existing resources from previous deployments

#### ERR-002: Service Principal Verification Timeout ✅
**Objective**: Test timeout handling during SP verification.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Run the script: `./subscription-level-deployment.sh --auto-approve`
2. Monitor the service principal verification phase
3. Check timeout handling (if SP takes too long to be ready)

**Expected Results**:
- Script waits for reasonable timeout period
- Either succeeds when SP is ready OR fails gracefully with timeout error
- Clear timeout message if verification fails

#### ERR-003: SIGTERM Cleanup
**Objective**: Test cleanup behavior when terminated with SIGTERM.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Start deployment: `./subscription-level-deployment.sh --auto-approve &`
2. Get the process ID: `ps aux | grep azure-deployment-script`
3. Send SIGTERM: `kill -TERM <pid>`
4. Verify cleanup behavior

**Expected Results**:
- Script handles SIGTERM signal
- Cleanup process executes
- Created resources are cleaned up
- Exits with appropriate code

#### ERR-004: Azure AD Application Creation Failure
**Objective**: Test error handling when Azure AD app creation fails.

**Note**: This test requires deliberately causing Azure AD failures, which is difficult to reproduce reliably. This is primarily for documentation.

**Potential Scenarios**:
- Quota limits reached for applications
- Invalid application names that pass validation but fail at Azure level
- Temporary Azure AD service issues

**Expected Results**:
- Clear error messages about application creation failure
- Proper cleanup of any partial resources
- Script exits with appropriate error code

#### ERR-005: Custom Role Creation Permission Denied
**Objective**: Test error handling when custom role creation fails due to permissions.

**Note**: This requires specific Azure RBAC setup that denies custom role creation.

**Setup (Advanced)**:
```bash
# This requires administrative access to create a user with limited permissions
# Create custom role that can create apps but NOT custom roles
```

**Expected Results**:
- Script fails during custom role creation
- Clear error message about insufficient permissions
- Cleanup of previously created resources (app, service principal)

#### ERR-006: Service Principal Creation Failure  
**Objective**: Test error handling when service principal creation fails.

**Note**: This is rare but can occur due to Azure AD quota limits or policy restrictions.

**Expected Results**:
- Clear error message about service principal creation failure
- Cleanup of Azure AD application
- Script exits with appropriate error code

#### ERR-007: Role Assignment Failure
**Objective**: Test error handling when role assignment fails after multiple retries.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Note**: This scenario is difficult to reproduce but can occur due to Azure propagation delays or permission issues.

**Expected Results**:
- Script retries role assignment multiple times
- Eventually fails with clear error message
- Cleanup of all created resources
- Script exits with appropriate error code

#### ERR-008: Network Connectivity Issues During Azure Operations
**Objective**: Test behavior during network interruptions affecting Azure CLI commands.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Start script deployment
2. Simulate network interruption (disconnect WiFi/ethernet during execution)
3. Observe error handling

**Expected Results**:
- Azure CLI commands fail with network errors
- Script handles network failures gracefully
- Clear error messages about connectivity issues
- Proper cleanup attempts when network is restored

#### ERR-009: Cleanup Failure Scenarios
**Objective**: Test behavior when cleanup operations themselves fail.

**Setup**:
1. Run successful deployment first to create resources
2. Modify permissions to prevent deletion of some resources
3. Trigger cleanup (via Ctrl+C or script failure)

**Expected Results**:
- Script attempts cleanup of all resources
- Reports which cleanup operations failed
- Provides manual cleanup instructions
- Does not hang indefinitely on failed cleanup operations

#### ERR-010: Safety Test - Existing Resource Protection ✅
**Objective**: Test that script never deletes existing Azure resources it didn't create.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="SafetyTestApp"
export ROLE_NAME="SafetyTestRole"
```

**Steps**:
1. **Pre-create Azure resources manually** with the same base name (without nonce):
   ```bash
   # Create an existing application with the same base name
   az ad app create --display-name "SafetyTestApp-existing" --sign-in-audience AzureADMyOrg
   
   # Create an existing custom role with the same base name
   az role definition create --role-definition '{
     "Name": "SafetyTestRole-existing",
     "Description": "Existing role for safety test",
     "Actions": ["Microsoft.Resources/subscriptions/resourceGroups/read"],
     "AssignableScopes": ["/subscriptions/'$SUBSCRIPTION_ID'"]
   }'
   ```
2. **Run deployment script** (which will create resources with different nonces):
   ```bash
   ./subscription-level-deployment.sh --auto-approve
   ```
3. **Interrupt script** during role assignment or verification phase (Ctrl+C)
4. **Verify cleanup behavior** - check that existing resources remain untouched

**Expected Results**:
- Script creates new resources with unique nonces (e.g., `SafetyTestApp-a1b2c3d4`, `SafetyTestRole-a1b2c3d4`)
- When interrupted, cleanup **only deletes resources created during current run**
- Pre-existing resources (`SafetyTestApp-existing`, `SafetyTestRole-existing`) remain **untouched**
- Cleanup messages show only current-run resources being deleted

**Verification**:
```bash
# Verify existing resources are still there
az ad app list --display-name "SafetyTestApp-existing"
az role definition list --name "SafetyTestRole-existing" --custom-role-only

# Verify script-created resources are cleaned up
az ad app list --display-name "SafetyTestApp-*" --query "[?displayName!='SafetyTestApp-existing']"
az role definition list --custom-role-only --query "[?roleName | contains(@, 'SafetyTestRole') && roleName!='SafetyTestRole-existing']"
```

**Manual Cleanup**:
```bash
# Clean up the pre-created test resources
az ad app delete --id $(az ad app list --display-name "SafetyTestApp-existing" --query "[0].id" -o tsv)
az role definition delete --name "SafetyTestRole-existing" --scope "/subscriptions/$SUBSCRIPTION_ID"
```

**Safety Notes**:
- This test confirms the critical safety feature: script tracks what it creates and only cleans up its own resources
- Even with similar names, the script never touches resources created by other processes/deployments
- The `role_created_this_run` tracking flag prevents accidental deletion of existing infrastructure

### 6. Backend Integration Tests

#### BCK-001: Successful Backend Communication ✅
**Objective**: Test status updates to Salt Security backend.

**Setup**:
```bash
export SALT_HOST="https://httpbin.org"  # Test endpoint that echoes requests (will be combined with endpoint path)
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Run full deployment with backend configuration
2. Monitor network requests (if possible)
3. Verify backend status updates

**Expected Results**:
- Multiple status updates sent during deployment:
  - "Initiated" status at start
  - "Succeeded" status at completion
- Requests sent to full URL: `https://httpbin.org/v1/cloud-connect/scan/azure`
- Successful HTTP responses logged
- "Successfully sent status 'X' to backend" messages

#### BCK-002: Backend URL Unreachable ✅
**Objective**: Test handling of network failures.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://nonexistent.invalid.domain/webhook"
export BEARER_TOKEN="test-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Run deployment with unreachable backend URL
2. Observe error handling

**Expected Results**:
- Deployment continues despite backend failures
- Warning messages about backend communication failures
- Core Azure resource creation still succeeds
- Script completes successfully

#### BCK-003: Invalid Bearer Token ✅
**Objective**: Test authentication failures with backend.

**Setup**:
```bash
export SALT_HOST="https://httpbin.org/status/401"  # Returns 401
export BEARER_TOKEN="invalid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Expected Results**:
- Backend returns authentication error
- Script logs warning but continues
- Azure deployment still completes successfully

#### BCK-004: Empty Bearer Token ✅
**Objective**: Test validation when bearer token is empty.

**Setup**:
```bash
# Test with empty bearer token flag
./subscription-level-deployment.sh \
  --subscription-id="$(uuidgen)" \
  --salt-host="https://httpbin.org/post" \
  --bearer-token="" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve

# OR test with empty environment variable
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN=""
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
./subscription-level-deployment.sh --auto-approve
```

**Expected Results**:
- Script exits during validation phase  
- Error: "Missing required parameters: --bearer-token" (if flag missing) OR "All required parameters must have non-empty values" (if flag empty)
- No Azure resource creation attempts

### 7. Edge Cases and Boundary Tests

#### EDGE-001: Very Long Resource Names ✅
**Objective**: Test Azure naming limits.

**Setup**:
```bash
export APP_NAME="VeryLongApplicationNameThatTestsAzureNamingLimitsButStillWithinReasonableBounds"
export ROLE_NAME="VeryLongCustomRoleNameThatTestsAzureNamingLimitsButStillWithinReasonableBounds"
```

**Expected Results**:
- Names should be accepted if within Azure limits
- Resources created successfully with long names

#### EDGE-002: Special Characters in Names ✅
**Objective**: Test allowed special characters.

**Setup**:
```bash
export APP_NAME="Test-App_With-Underscores123"
export ROLE_NAME="Test_Role-With-Hyphens_456"
```

**Expected Results**:
- Valid special characters (hyphens, underscores) accepted
- Resources created with special character names

#### EDGE-003: Minimum Length Names ✅
**Objective**: Test minimum name requirements.

**Setup**:
```bash
export APP_NAME="A"
export ROLE_NAME="B"
```

**Expected Results**:
- Single character names should be accepted (if valid per Azure requirements)
- Or clear validation error if below minimum

### 8. Environment & Configuration Tests

#### ENV-001: Environment Variable vs Flag Precedence
**Objective**: Test that command line flags take precedence over environment variables.

**Setup**:
```bash
# Set environment variables
export SUBSCRIPTION_ID="env-subscription-id"
export SALT_HOST="https://env.test.com/webhook"
export BEARER_TOKEN="env-bearer-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="EnvApp"
export ROLE_NAME="EnvRole"
```

**Test Cases**:
```bash
# Test that command line flags override environment variables
./subscription-level-deployment.sh \
  --subscription-id="cli-subscription-id" \
  --salt-host="https://cli.test.com" \
  --bearer-token="cli-bearer-token" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --app-name="CLIApp" \
  --role-name="CLIRole" \
  --created-by="CLI User" \
  --auto-approve
```

**Expected Results**:
- Script uses command line flag values, not environment variables
- Resources created with names "CLIApp" and "CLIRole" (with nonce suffixes)
- Log shows flag parameters being used

#### ENV-002: Mixed Parameter Sources
**Objective**: Test mixed usage of environment variables and command line flags.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export APP_NAME="MixedEnvApp"
export ROLE_NAME="MixedEnvRole"
```

**Test Cases**:
```bash
# Provide only mandatory parameters via flags, optional via environment
./subscription-level-deployment.sh \
  --subscription-id="your-valid-test-subscription-id" \
  --salt-host="https://httpbin.org/post" \
  --bearer-token="test-valid-token" \
  --installation-id="$(uuidgen)" \
  --attempt-id="$(uuidgen)" \
  --auto-approve
```

**Expected Results**:
- Script uses flag parameters for mandatory fields
- Script uses environment variables for APP_NAME and ROLE_NAME
- Resources created with "MixedEnvApp" and "MixedEnvRole" names

### 9. Interactive Mode Tests

#### INT-001: Interactive Mode Without Auto-Approve
**Objective**: Test interactive prompts when --auto-approve is not used.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
# Deliberately leave APP_NAME and ROLE_NAME unset
unset APP_NAME
unset ROLE_NAME
```

**Steps**:
1. Run: `./subscription-level-deployment.sh` (without --auto-approve)
2. When prompted for APP_NAME, provide: "InteractiveApp"
3. When prompted for ROLE_NAME, provide: "InteractiveRole"
4. When prompted "Do you want to proceed? (y/n):", type "y"

**Expected Results**:
- Script prompts for missing APP_NAME with default suggestion
- Script prompts for missing ROLE_NAME with default suggestion
- Script prompts for deployment confirmation
- Resources created with provided names (plus nonce suffixes)
- Deployment proceeds successfully

#### INT-002: Interactive Mode - User Cancellation
**Objective**: Test user cancellation during interactive mode.

**Steps**:
1. Run: `./subscription-level-deployment.sh`
2. Provide inputs for APP_NAME and ROLE_NAME when prompted
3. When prompted "Do you want to proceed? (y/n):", type "n"

**Expected Results**:
- Script displays "Setup cancelled by user."
- Script exits with code 0
- No Azure resources created
- No backend communication attempted

#### INT-003: Interactive Mode - Default Value Acceptance
**Objective**: Test using default values in interactive mode.

**Steps**:
1. Run: `./subscription-level-deployment.sh`
2. Press Enter (accept defaults) for APP_NAME and ROLE_NAME prompts
3. Type "y" when prompted to proceed

**Expected Results**:
- Script uses default values ("SaltAppServicePrincipal", "SaltCustomAppRole")
- Resources created with default names (plus nonce suffixes)
- Deployment completes successfully

### 10. Logging & Output Tests

#### LOG-001: Log File Creation and Content
**Objective**: Verify log file is created and contains expected information.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Note current directory files: `ls azure-deployment-*.log`
2. Run: `./subscription-level-deployment.sh --auto-approve`
3. Check for new log file: `ls azure-deployment-*.log`
4. Examine log content: `cat azure-deployment-[newest-file].log`

**Expected Results**:
- New log file created with pattern: `azure-deployment-[nonce]-[timestamp].log`
- Log file contains all script output with timestamps
- Log includes deployment phases, resource IDs, and status updates
- Log shows both INFO and ERROR level messages
- Log includes nonce and execution timestamp

#### LOG-002: Log Content During Errors
**Objective**: Verify error scenarios are properly logged.

**Setup**:
```bash
export SUBSCRIPTION_ID="invalid-uuid-format"
export SALT_HOST="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Run: `./subscription-level-deployment.sh --auto-approve`
2. Check log file content for error details

**Expected Results**:
- Error messages logged with ERROR level
- Validation failure details in log
- Script exit reason clearly documented
- Timestamps show when error occurred

### 11. Network & Connectivity Tests

#### NET-001: Azure Service Unavailability
**Objective**: Test behavior when Azure services are unreachable.

**Note**: This test is difficult to reproduce reliably as it requires Azure service outages.

**Simulated Setup**:
```bash
# Temporarily block Azure endpoints (requires root access)
# Add entries to /etc/hosts to redirect Azure APIs to non-existent addresses
# 127.0.0.1 management.azure.com
# 127.0.0.1 graph.microsoft.com
```

**Expected Results**:
- Azure CLI commands fail with network/DNS errors
- Script handles Azure service failures gracefully
- Clear error messages about service unavailability
- Script exits with appropriate error code

#### NET-002: DNS Resolution Failures
**Objective**: Test behavior when DNS resolution fails for Azure services.

**Simulated Setup**:
```bash
# Temporarily modify DNS settings to break Azure domain resolution
# This requires system-level changes and is primarily for documentation
```

**Expected Results**:
- DNS resolution errors for Azure domains
- Azure CLI commands fail appropriately
- Script reports DNS-related errors
- No resource creation attempts

## Test Execution Tracking

Use this checklist to track test execution:

### Dependencies Tests
- [✅] DEP-001: Missing Azure CLI
- [ ] DEP-002: Missing jq utility  
- [✅] DEP-003: Not logged into Azure CLI
- [ ] DEP-004: Missing curl utility
- [ ] DEP-005: Missing uuidgen utility

### Input Validation Tests
- [✅] INP-001: Invalid subscription ID format
- [✅] INP-002: Invalid application name
- [✅] INP-003: Invalid role name
- [✅] INP-004: Missing required parameters
- [✅] INP-005: Invalid backend URL format
- [✅] INP-006: Invalid UUID format

### Authentication Tests  
- [ ] AUTH-001: Insufficient permissions
- [✅] AUTH-002: Invalid subscription ID

### Resource Creation Tests
- [✅] RES-001: Successful full deployment
- [✅] RES-002: Resource name uniqueness verification
- [✅] RES-003: Partial failure scenario

### Error Handling Tests
- [✅] ERR-001: SIGINT cleanup
- [ ] ERR-001a: Interrupt during dependency check
- [ ] ERR-001b: Interrupt during Azure authentication
- [ ] ERR-001c: Interrupt during Azure AD application creation
- [ ] ERR-001d: Interrupt during client secret creation
- [ ] ERR-001e: Interrupt during service principal creation
- [ ] ERR-001f: Interrupt during custom role creation
- [ ] ERR-001g: Interrupt during role assignment
- [ ] ERR-001h: Interrupt during service principal verification
- [✅] ERR-002: Service principal verification timeout
- [ ] ERR-003: SIGTERM cleanup
- [ ] ERR-004: Azure AD application creation failure
- [ ] ERR-005: Custom role creation permission denied
- [ ] ERR-006: Service principal creation failure
- [ ] ERR-007: Role assignment failure
- [ ] ERR-008: Network connectivity issues during Azure operations
- [ ] ERR-009: Cleanup failure scenarios
- [ ] ERR-010: Safety test - existing resource protection

### Backend Integration Tests
- [✅] BCK-001: Successful backend communication
- [✅] BCK-002: Backend URL unreachable  
- [✅] BCK-003: Invalid bearer token
- [✅] BCK-004: Empty bearer token

### Edge Case Tests
- [✅] EDGE-001: Very long resource names
- [✅] EDGE-002: Special characters in names
- [✅] EDGE-003: Minimum length names

### Environment & Configuration Tests
- [ ] ENV-001: Environment variable vs parameter precedence
- [ ] ENV-002: Mixed parameter sources

### Interactive Mode Tests
- [ ] INT-001: Interactive mode without auto-approve
- [ ] INT-002: Interactive mode - user cancellation
- [ ] INT-003: Interactive mode - default value acceptance

### Logging & Output Tests
- [ ] LOG-001: Log file creation and content
- [ ] LOG-002: Log content during errors

### Network & Connectivity Tests
- [ ] NET-001: Azure service unavailability
- [ ] NET-002: DNS resolution failures

## Test Data Reference

### Valid Test Data
```json
{
  "subscription_id": "550e8400-e29b-41d4-a716-446655440000",
  "app_name": "TestApplication",
  "role_name": "TestCustomRole",
  "salt_host": "https://httpbin.org",
  "bearer_token": "valid-test-token-123",
  "installation_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "attempt_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
}
```

### Invalid Test Data Examples
```json
{
  "invalid_subscription_ids": [
    "invalid-uuid",
    "12345", 
    "",
    "550e8400-e29b-41d4-a716",
    "550e8400xe29bx41d4xa716x446655440000"
  ],
  "invalid_app_names": [
    "",
    "App Name With Spaces",
    "App@Invalid#Characters",
    "App|With|Pipes"
  ],
  "invalid_role_names": [
    "",
    "Role Name With Spaces",
    "Role@Invalid!Characters"
  ],
  "invalid_backend_urls": [
    "",
    "invalid-url",
    "ftp://invalid.protocol.com",
    "api.test.com"
  ],
  "invalid_uuids": [
    "invalid-uuid",
    "12345-invalid",
    "",
    "550e8400-e29b-41d4-a716",
    "550e8400xe29bx41d4xa716x446655440000"
  ],
  "invalid_bearer_tokens": [
    ""
  ]
}
```

## Cleanup Procedures

After each test, ensure proper cleanup:

### Manual Cleanup Commands
```bash
# Clean up applications
az ad app list --display-name "TestApp" --query "[].id" -o tsv | xargs -I {} az ad app delete --id {}

# Clean up service principals  
az ad sp list --display-name "TestApp" --query "[].id" -o tsv | xargs -I {} az ad sp delete --id {}

# Clean up custom roles
az role definition delete --name "TestRole"

# Verify cleanup
az ad app list --display-name "TestApp" 
az ad sp list --display-name "TestApp"
az role definition list --name "TestRole" --custom-role-only
```

### Automated Cleanup
Use the provided cleanup utility:
```bash
# Clean up resources with specific tag
# Manual cleanup using Azure CLI commands
# Delete test resources by nonce pattern
```

## Test Environment Considerations

### Azure Cloud Shell
- Session timeouts may affect long-running tests
- Network connectivity variations
- Temporary storage limitations

### Local Environment
- Ensure Azure CLI is properly authenticated
- Verify all dependencies are installed
- Consider network proxy settings

### Subscription Considerations  
- Use dedicated test subscription
- Verify sufficient resource quotas
- Ensure appropriate permissions
- Monitor costs during testing

## Troubleshooting Guide

### Common Issues

**Azure CLI Not Logged In**
```bash
# Solution
az login
az account set --subscription "your-test-subscription-id"
```

**Permission Denied Errors**
- Verify account has Contributor role on subscription
- Check Azure AD permissions for application creation
- Ensure custom role creation permissions

**Resource Already Exists**
- Use unique names with timestamps or UUIDs
- Clean up resources from previous test runs
- Check hidden/soft-deleted resources

**Backend Communication Failures**
- Verify network connectivity
- Check firewall/proxy settings  
- Validate bearer token format
- Test with simple endpoints like httpbin.org

**Service Principal Verification Timeout**
- Azure AD propagation can take time
- Wait longer or retry
- Check Azure AD service health

## Security Considerations

### Test Data Security
- Never use production credentials in tests
- Use mock tokens and test-specific identifiers
- Clean up test resources promptly
- Monitor for accidentally committed secrets

### Test Isolation
- Use unique identifiers for each test run
- Avoid resource name conflicts
- Properly scope permissions to test subscription
- Isolate test environment from production

---

**Test Plan Version**: 2.1  
**Last Updated**: 2025-10-05  
**Script Version**: Updated for subscription-level deployment - all parameters now use --flag=value syntax instead of positional arguments  
**Manual Testing**: Comprehensive validation procedures  
**Estimated Execution Time**: 4-6 hours for full test suite
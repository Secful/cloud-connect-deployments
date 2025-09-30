# Manual Test Plan for Azure Deployment Script

## Overview

This manual test plan is derived from the comprehensive automated test suite in `azure/tests/`. It provides step-by-step instructions for manually validating the Azure deployment script functionality across all critical scenarios.

**Target Script**: `azure-deployment-script.sh`  
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
The script accepts parameters in this order:
```bash
./azure-deployment-script.sh <subscription_id> <backend_url> <bearer_token> <installation_id> <attempt_id> [app_name] [role_name] [created_by] --auto-approve
```

### Environment Variables (Recommended Approach)
For consistent testing, set these environment variables:

```bash
export SUBSCRIPTION_ID="your-test-subscription-id"
export BACKEND_URL="https://api.test.com/webhook"  # Required
export BEARER_TOKEN="test-token-123"              # Required
export INSTALLATION_ID="$(uuidgen)"               # Required
export ATTEMPT_ID="$(uuidgen)"                    # Required
export APP_NAME="ManualTestApp"                   # Optional (has interactive prompt with default)
export ROLE_NAME="ManualTestRole"                 # Optional (has interactive prompt with default)
export CREATED_BY="Manual Test User"              # Optional (has default)
```

### Command Line Examples
```bash
# Using environment variables (recommended):
./azure-deployment-script.sh --auto-approve

# Using command line parameters:
./azure-deployment-script.sh "subscription-id" "https://api.test.com" "bearer-token" "$(uuidgen)" "$(uuidgen)" --auto-approve

# Mixed approach (mandatory params on command line, optional via environment):
export APP_NAME="MyTestApp"
./azure-deployment-script.sh "subscription-id" "https://api.test.com" "bearer-token" "$(uuidgen)" "$(uuidgen)" --auto-approve
```

## Test Categories and Scenarios

### 1. Dependencies & Environment Tests

#### DEP-001: Missing Azure CLI ✅
**Objective**: Verify behavior when `az` command is not available.

**Steps**:

1. Temporarily rename or move the `az` command (check actual location first with `which az`):
   - Common locations: `/usr/bin/az`, `/opt/homebrew/bin/az`, `/usr/local/bin/az`
   - Example: `sudo mv /opt/homebrew/bin/az /opt/homebrew/bin/az.bak`
2. Run the deployment script: `./azure-deployment-script.sh --auto-approve`
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
2. Run: `./azure-deployment-script.sh --auto-approve`
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
2. Run: `./azure-deployment-script.sh --auto-approve`
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
2. Run: `./azure-deployment-script.sh --auto-approve`
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
2. Run: `./azure-deployment-script.sh --auto-approve`
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
./azure-deployment-script.sh --auto-approve

export SUBSCRIPTION_ID="12345"
./azure-deployment-script.sh --auto-approve

export SUBSCRIPTION_ID=""
./azure-deployment-script.sh --auto-approve
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
# Test missing backend URL:
unset BACKEND_URL
./azure-deployment-script.sh --auto-approve

# Test missing bearer token:
export BACKEND_URL="https://api.test.com/webhook"
unset BEARER_TOKEN
./azure-deployment-script.sh --auto-approve

# Test missing installation ID:
export BEARER_TOKEN="test-token"
unset INSTALLATION_ID
./azure-deployment-script.sh --auto-approve

# Test missing attempt ID:
export INSTALLATION_ID="$(uuidgen)"
unset ATTEMPT_ID
./azure-deployment-script.sh --auto-approve

# Test empty parameters (passed as empty strings):
./azure-deployment-script.sh "" "https://api.test.com" "token" "$(uuidgen)" "$(uuidgen)" --auto-approve
./azure-deployment-script.sh "$(uuidgen)" "" "token" "$(uuidgen)" "$(uuidgen)" --auto-approve
./azure-deployment-script.sh "$(uuidgen)" "https://api.test.com" "" "$(uuidgen)" "$(uuidgen)" --auto-approve
```

**Expected Results**:
- Script exits with validation error for each missing parameter
- Error: "Missing required parameters. Expected 5 mandatory parameters, got X" (for insufficient parameters)
- Error: "Parameter X is empty. All mandatory parameters must have values." (for empty strings)
- No authentication or resource creation attempts

#### INP-005: Invalid Backend URL Format ✅
**Objective**: Test backend URL validation.

**Test Cases**:
```bash
# Test invalid URL formats:
export BACKEND_URL="invalid-url"
export BACKEND_URL="ftp://invalid.protocol.com"
export BACKEND_URL="api.test.com"  # Missing protocol
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
./azure-deployment-script.sh --auto-approve

# Test invalid attempt ID:
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="12345-invalid"
./azure-deployment-script.sh --auto-approve
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
3. Run: `./azure-deployment-script.sh --auto-approve`
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
export BACKEND_URL="https://httpbin.org/post"  # Test endpoint
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="TestSuccessApp"
export ROLE_NAME="TestSuccessRole"
```

**Steps**:
1. Ensure clean environment (no existing resources with same names)
2. Run: `./azure-deployment-script.sh --auto-approve`
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
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="TestApp"
export ROLE_NAME="TestRole"
```

**Steps**:
1. Run the script first time: `./azure-deployment-script.sh --auto-approve`
2. Note the nonce used in resource names (from output or log)
3. Run the script second time: `./azure-deployment-script.sh --auto-approve`
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
export BACKEND_URL="https://httpbin.org/post"
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
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Start deployment: `./azure-deployment-script.sh --auto-approve`
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

#### ERR-002: Service Principal Verification Timeout ✅
**Objective**: Test timeout handling during SP verification.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Run the script: `./azure-deployment-script.sh --auto-approve`
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
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Start deployment: `./azure-deployment-script.sh --auto-approve &`
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
export BACKEND_URL="https://httpbin.org/post"
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
export BACKEND_URL="https://httpbin.org/post"
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

### 6. Backend Integration Tests

#### BCK-001: Successful Backend Communication ✅
**Objective**: Test status updates to Salt Security backend.

**Setup**:
```bash
export BACKEND_URL="https://httpbin.org/post"  # Test endpoint that echoes requests
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
- Successful HTTP responses logged
- "Successfully sent status 'X' to backend" messages

#### BCK-002: Backend URL Unreachable ✅
**Objective**: Test handling of network failures.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export BACKEND_URL="https://nonexistent.invalid.domain/webhook"
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
export BACKEND_URL="https://httpbin.org/status/401"  # Returns 401
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
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN=""
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Expected Results**:
- Script exits during validation phase  
- Error: "Parameter 3 is empty. All mandatory parameters must have values."
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

#### ENV-001: Environment Variable vs Parameter Precedence
**Objective**: Test that command line parameters take precedence over environment variables.

**Setup**:
```bash
# Set environment variables
export SUBSCRIPTION_ID="env-subscription-id"
export BACKEND_URL="https://env.test.com/webhook"
export BEARER_TOKEN="env-bearer-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
export APP_NAME="EnvApp"
export ROLE_NAME="EnvRole"
```

**Test Cases**:
```bash
# Test that command line parameters override environment variables
./azure-deployment-script.sh "cli-subscription-id" "https://cli.test.com" "cli-bearer-token" "$(uuidgen)" "$(uuidgen)" "CLIApp" "CLIRole" "CLI User" --auto-approve
```

**Expected Results**:
- Script uses command line parameters, not environment variables
- Resources created with names "CLIApp" and "CLIRole" (with nonce suffixes)
- Log shows CLI parameters being used

#### ENV-002: Mixed Parameter Sources
**Objective**: Test mixed usage of environment variables and command line parameters.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export APP_NAME="MixedEnvApp"
export ROLE_NAME="MixedEnvRole"
```

**Test Cases**:
```bash
# Provide only mandatory parameters via CLI, optional via environment
./azure-deployment-script.sh "$(uuidgen)" "$(uuidgen)" --auto-approve
```

**Expected Results**:
- Script uses CLI parameters for mandatory fields
- Script uses environment variables for APP_NAME and ROLE_NAME
- Resources created with "MixedEnvApp" and "MixedEnvRole" names

### 9. Interactive Mode Tests

#### INT-001: Interactive Mode Without Auto-Approve
**Objective**: Test interactive prompts when --auto-approve is not used.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
# Deliberately leave APP_NAME and ROLE_NAME unset
unset APP_NAME
unset ROLE_NAME
```

**Steps**:
1. Run: `./azure-deployment-script.sh` (without --auto-approve)
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
1. Run: `./azure-deployment-script.sh`
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
1. Run: `./azure-deployment-script.sh`
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
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Note current directory files: `ls azure-deployment-*.log`
2. Run: `./azure-deployment-script.sh --auto-approve`
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
export BACKEND_URL="https://httpbin.org/post"
export BEARER_TOKEN="test-valid-token"
export INSTALLATION_ID="$(uuidgen)"
export ATTEMPT_ID="$(uuidgen)"
```

**Steps**:
1. Run: `./azure-deployment-script.sh --auto-approve`
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
- [✅] ERR-002: Service principal verification timeout
- [ ] ERR-003: SIGTERM cleanup
- [ ] ERR-004: Azure AD application creation failure
- [ ] ERR-005: Custom role creation permission denied
- [ ] ERR-006: Service principal creation failure
- [ ] ERR-007: Role assignment failure
- [ ] ERR-008: Network connectivity issues during Azure operations
- [ ] ERR-009: Cleanup failure scenarios

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
  "backend_url": "https://httpbin.org/post",
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
./azure/tests/utils/azure-verifier.sh --tag "CreatedBySalt-test" --cleanup
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

**Test Plan Version**: 1.0  
**Last Updated**: 2025-01-09  
**Script Version**: Updated parameter order - mandatory parameters first (subscription_id, backend_url, bearer_token, installation_id, attempt_id), then optional parameters (app_name, role_name, created_by)  
**Based on Automated Tests**: azure/tests/ directory  
**Estimated Execution Time**: 4-6 hours for full test suite
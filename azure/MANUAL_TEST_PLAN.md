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

### Environment Variables
For consistent testing, set these environment variables:

```bash
export SUBSCRIPTION_ID="your-test-subscription-id"
export APP_NAME="ManualTestApp"
export ROLE_NAME="ManualTestRole"
export BACKEND_URL="https://api.test.com/webhook"  # Optional
export BEARER_TOKEN="test-token-123"              # Optional
export CREATED_BY="Manual Test User"              # Optional
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

### 2. Input Validation Tests

#### INP-001: Invalid Subscription ID Format
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

#### INP-002: Invalid Application Name
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

#### INP-003: Invalid Role Name
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

### 3. Authentication & Permissions Tests

#### AUTH-001: Insufficient Permissions
**Objective**: Test with a user lacking sufficient permissions.

**Steps**:
1. Use an account with only Reader permissions on the subscription
2. Run: `./azure-deployment-script.sh --auto-approve`
3. Observe permission errors

**Expected Results**:
- Script fails during resource creation
- Clear error messages about insufficient permissions
- Partial resources may be created (verify cleanup)

#### AUTH-002: Invalid Subscription ID
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

#### RES-001: Successful Full Deployment (Happy Path)
**Objective**: Test complete successful deployment workflow.

**Setup**:
```bash
export SUBSCRIPTION_ID="your-valid-test-subscription-id"
export APP_NAME="TestSuccessApp"
export ROLE_NAME="TestSuccessRole"
export BACKEND_URL="https://httpbin.org/post"  # Test endpoint
export BEARER_TOKEN="test-valid-token"
```

**Steps**:
1. Ensure clean environment (no existing resources with same names)
2. Run: `./azure-deployment-script.sh --auto-approve`
3. Monitor output for all deployment phases

**Expected Results**:
- Script exits with code 0
- All phases complete successfully:
  - ✅ Azure authentication setup
  - ✅ Creating Azure AD application
  - ✅ Creating client secret
  - ✅ Creating service principal
  - ✅ Retrieving tenant ID
  - ✅ Creating custom role
  - ✅ Assigning custom role
  - ✅ Service principal verification
  - ✅ Backend status updates (if configured)

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

#### RES-002: Duplicate Application Name
**Objective**: Test handling of existing application names.

**Steps**:
1. Create an application: `az ad app create --display-name "DuplicateTestApp"`
2. Set: `export APP_NAME="DuplicateTestApp"`
3. Run the script
4. Observe conflict handling

**Expected Results**:
- Script detects existing application
- Either fails gracefully with clear error OR continues with existing app (depending on implementation)
- No duplicate resources created

#### RES-003: Partial Failure Scenario
**Objective**: Test cleanup when deployment fails mid-process.

**Steps**:
1. Set valid parameters
2. Run script and interrupt during service principal creation (Ctrl+C)
3. Verify partial cleanup occurs
4. Check for orphaned resources

**Expected Results**:
- Script handles interrupt signal
- Cleanup process executes
- Partial resources are cleaned up
- Clear messages about cleanup actions

### 5. Error Handling & Cleanup Tests

#### ERR-001: SIGINT Cleanup (Ctrl+C)
**Objective**: Test cleanup behavior when interrupted.

**Steps**:
1. Start deployment with valid parameters
2. Press Ctrl+C after application creation starts
3. Verify cleanup behavior

**Expected Results**:
- Script catches SIGINT signal
- Displays "Received interrupt signal" message
- Executes cleanup routine
- Deletes created resources
- Exits with code 130

**Verification**:
```bash
# Check no orphaned resources remain
az ad app list --display-name "TestApp"
az ad sp list --display-name "TestApp"  
az role definition list --name "TestRole" --custom-role-only
```

#### ERR-002: Service Principal Verification Timeout
**Objective**: Test timeout handling during SP verification.

**Steps**:
1. Use parameters that may cause slow SP propagation
2. Monitor the service principal verification phase
3. Check timeout handling (if SP takes too long to be ready)

**Expected Results**:
- Script waits for reasonable timeout period
- Either succeeds when SP is ready OR fails gracefully with timeout error
- Clear timeout message if verification fails

### 6. Backend Integration Tests

#### BCK-001: Successful Backend Communication
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

#### BCK-002: Backend URL Unreachable
**Objective**: Test handling of network failures.

**Setup**:
```bash
export BACKEND_URL="https://nonexistent.invalid.domain/webhook"
export BEARER_TOKEN="test-token"
```

**Steps**:
1. Run deployment with unreachable backend URL
2. Observe error handling

**Expected Results**:
- Deployment continues despite backend failures
- Warning messages about backend communication failures
- Core Azure resource creation still succeeds
- Script completes successfully

#### BCK-003: Invalid Bearer Token
**Objective**: Test authentication failures with backend.

**Setup**:
```bash
export BACKEND_URL="https://httpbin.org/status/401"  # Returns 401
export BEARER_TOKEN="invalid-token"
```

**Expected Results**:
- Backend returns authentication error
- Script logs warning but continues
- Azure deployment still completes successfully

### 7. Edge Cases and Boundary Tests

#### EDGE-001: Very Long Resource Names
**Objective**: Test Azure naming limits.

**Setup**:
```bash
export APP_NAME="VeryLongApplicationNameThatTestsAzureNamingLimitsButStillWithinReasonableBounds"
export ROLE_NAME="VeryLongCustomRoleNameThatTestsAzureNamingLimitsButStillWithinReasonableBounds"
```

**Expected Results**:
- Names should be accepted if within Azure limits
- Resources created successfully with long names

#### EDGE-002: Special Characters in Names
**Objective**: Test allowed special characters.

**Setup**:
```bash
export APP_NAME="Test-App_With-Underscores123"
export ROLE_NAME="Test_Role-With-Hyphens_456"
```

**Expected Results**:
- Valid special characters (hyphens, underscores) accepted
- Resources created with special character names

#### EDGE-003: Minimum Length Names
**Objective**: Test minimum name requirements.

**Setup**:
```bash
export APP_NAME="A"
export ROLE_NAME="B"
```

**Expected Results**:
- Single character names should be accepted (if valid per Azure requirements)
- Or clear validation error if below minimum

## Test Execution Tracking

Use this checklist to track test execution:

### Dependencies Tests
- [ ] DEP-001: Missing Azure CLI
- [ ] DEP-002: Missing jq utility  
- [ ] DEP-003: Not logged into Azure CLI

### Input Validation Tests
- [ ] INP-001: Invalid subscription ID format
- [ ] INP-002: Invalid application name
- [ ] INP-003: Invalid role name

### Authentication Tests  
- [ ] AUTH-001: Insufficient permissions
- [ ] AUTH-002: Invalid subscription ID

### Resource Creation Tests
- [ ] RES-001: Successful full deployment
- [ ] RES-002: Duplicate application name
- [ ] RES-003: Partial failure scenario

### Error Handling Tests
- [ ] ERR-001: SIGINT cleanup
- [ ] ERR-002: Service principal verification timeout

### Backend Integration Tests
- [ ] BCK-001: Successful backend communication
- [ ] BCK-002: Backend URL unreachable  
- [ ] BCK-003: Invalid bearer token

### Edge Case Tests
- [ ] EDGE-001: Very long resource names
- [ ] EDGE-002: Special characters in names
- [ ] EDGE-003: Minimum length names

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
**Based on Automated Tests**: azure/tests/ directory  
**Estimated Execution Time**: 4-6 hours for full test suite
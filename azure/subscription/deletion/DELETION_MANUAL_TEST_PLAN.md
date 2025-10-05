# Manual Test Plan for Azure Deletion Script

## Overview

This manual test plan provides step-by-step instructions for manually validating the Azure deletion script functionality across all critical scenarios. It is designed to complement the deployment test plan and ensure proper cleanup of Azure resources.

**Target Script**: `subscription-level-deletion.sh`  
**Test Environment**: Azure Cloud Shell (recommended) or local environment with Azure CLI  
**Prerequisites**: Active Azure subscription with appropriate permissions and existing resources created by deployment script  

⚠️ **Important**: Use a dedicated test Azure subscription, never production environments.

## Test Environment Setup

### Prerequisites Checklist
- [ ] Azure CLI installed and accessible (`az --version`)
- [ ] jq utility available (`jq --version`) 
- [ ] curl available (`curl --version`)
- [ ] Test Azure subscription access
- [ ] Sufficient permissions for deleting Azure AD apps, service principals, and custom roles
- [ ] Existing test resources created by deployment script (with known nonce)

### Script Usage
The script uses named flags for all parameters:

```bash
./subscription-level-deletion.sh --subscription-id=<id> --nonce=<nonce> --salt-host=<url> --bearer-token=<token> [--auto-approve] [--dry-run] [--help]
```

**Required parameters:**
- `--subscription-id=<uuid>` - Azure subscription ID
- `--nonce=<nonce>` - 8-character hexadecimal nonce from deployment
- `--salt-host=<url>` - Salt host URL for status updates (will be combined with endpoint path)
- `--bearer-token=<token>` - Authentication bearer token

**Optional parameters:**
- `--auto-approve` - Skip confirmation prompts
- `--dry-run` - Identify resources without deleting them
- `--help` - Show usage information

### Environment Variables (Legacy)
For consistent testing, these can still be used but flags take precedence:

```bash
export SUBSCRIPTION_ID="your-test-subscription-id"
export NONCE="a1b2c3d4"  # 8-character hex string from deployment
export SALT_HOST="https://api.test.com"  # Required (will be combined with endpoint path)
export BEARER_TOKEN="test-token-123"              # Required
```

## Test Categories and Scenarios

### 1. Dependencies & Environment Tests

#### DEP-001: Missing Azure CLI ✅
**Objective**: Verify behavior when `az` command is not available.

**Steps**:

1. Temporarily rename or move the `az` command (check actual location first with `which az`)
2. Run the deletion script: `./subscription-level-deletion.sh --auto-approve`
3. Observe the error message

**Expected Results**:
- Script exits with code 1
- Error message: "Required command 'az' not found"
- Script does not proceed past dependency check

**Cleanup**: Restore the original command

#### DEP-002: Missing jq Utility
**Objective**: Test behavior when jq is not available.

**Steps**:
1. Temporarily make jq unavailable
2. Run: `./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="$NONCE" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve`
3. Check error handling

**Expected Results**:
- Script exits with error
- Clear message about missing jq dependency
- No partial execution

**Cleanup**: Restore access to jq

#### DEP-003: Not Logged into Azure CLI ✅
**Objective**: Verify authentication check works correctly.

**Steps**:
1. Log out of Azure: `az logout`
2. Run: `./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="$NONCE" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve`
3. Verify error handling

**Expected Results**:
- Script exits with code 1
- Error message: "Not logged into Azure CLI"
- Suggestion to run `az login`
- No Azure resource deletion attempts

**Cleanup**: `az login` and set appropriate subscription

### 2. Input Validation Tests

#### INP-001: Invalid Subscription ID Format
**Objective**: Test subscription ID validation.

**Test Cases**:
```bash
# Test each invalid format:
./subscription-level-deletion.sh --subscription-id="invalid-uuid" --nonce="a1b2c3d4" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve
./subscription-level-deletion.sh --subscription-id="12345" --nonce="a1b2c3d4" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve
./subscription-level-deletion.sh --subscription-id="" --nonce="a1b2c3d4" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve
```

**Expected Results** (for each case):
- Script exits with code 1
- Error: "Invalid subscription ID format"
- No authentication attempts

#### INP-002: Invalid Nonce Format
**Objective**: Test nonce format validation.

**Test Cases**:
```bash
# Test various invalid nonces:
./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve
./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="invalid-nonce" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve
./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="12345" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve
./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="a1b2c3d4e5" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve  # Too long
```

**Expected Results**:
- Script exits with validation error
- Error: "Invalid nonce format: Expected 8-character hexadecimal string"
- No Azure resources discovery attempted

#### INP-003: Missing Required Parameters
**Objective**: Test behavior when required parameters are missing.

**Test Cases**:
```bash
# Test missing parameters:
./subscription-level-deletion.sh  # No parameters
./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID"  # Missing other required parameters
./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="$NONCE"  # Missing backend-url and bearer-token
./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="$NONCE" --salt-host="$SALT_HOST"  # Missing bearer-token
```

**Expected Results**:
- Script exits with usage error
- Clear usage message with examples
- Script exits cleanly

### 3. Authentication & Permissions Tests

#### AUTH-001: Insufficient Permissions
**Objective**: Test with a user lacking sufficient permissions.

**Steps**:
1. Use an account with only Reader permissions on the subscription
2. Run: `./subscription-level-deletion.sh --subscription-id="$SUBSCRIPTION_ID" --nonce="$NONCE" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN" --auto-approve`
3. Observe permission errors

**Expected Results**:
- Script may proceed through discovery phase
- Deletion operations fail with permission errors
- Clear error messages about insufficient permissions

#### AUTH-002: Invalid Subscription ID
**Objective**: Test with non-existent subscription.

**Steps**:
1. Run: `./subscription-level-deletion.sh --subscription-id="00000000-0000-0000-0000-000000000000" --nonce="$NONCE" --salt-host="$SALT_HOST" --bearer-token="$BEARER_TOKEN"`
2. Verify error handling

**Expected Results**:
- Error during subscription access
- Script exits with appropriate error code
- No resource discovery attempts

### 4. Resource Discovery Tests

#### RDS-001: Successful Resource Discovery (Happy Path)
**Objective**: Test discovery of existing resources by nonce.

**Setup**:
First create resources using deployment script:
```bash
./subscription-level-deployment.sh --auto-approve
# Note the nonce from the output or log file
```

**Steps**:
1. Run deletion script with correct nonce: `./subscription-level-deletion.sh $SUBSCRIPTION_ID $NONCE --dry-run`
2. Monitor discovery output

**Expected Results**:
- Script successfully discovers all created resources:
  - ✅ Azure AD Application with nonce suffix
  - ✅ Service Principal with matching App ID
  - ✅ Custom Role with nonce suffix
- Resources have expected tags "CreatedBySalt-{nonce}"
- Discovery summary shows all resources found
- Dry-run mode exits without deletion

#### RDS-002: No Resources Found
**Objective**: Test behavior when no resources match the nonce.

**Steps**:
1. Use a nonce that doesn't correspond to any existing resources
2. Run: `./subscription-level-deletion.sh $SUBSCRIPTION_ID "00000000" --dry-run`
3. Verify handling of empty results

**Expected Results**:
- Warning message: "No resources found with nonce '00000000'"
- Suggestion that resources may already be deleted or nonce is incorrect
- Script exits with code 1
- No deletion attempts

#### RDS-003: Partial Resources Found
**Objective**: Test discovery when only some resources exist.

**Setup**:
1. Create resources with deployment script
2. Manually delete some resources (e.g., only the custom role)

**Steps**:
1. Run deletion script with dry-run mode
2. Observe partial discovery results

**Expected Results**:
- Script discovers existing resources
- Reports missing resources as "Not found"
- Discovery summary shows mixed results
- Script continues to deletion phase (if not dry-run)

### 5. Resource Deletion Tests

#### DEL-001: Successful Full Deletion (Happy Path)
**Objective**: Test complete successful deletion workflow.

**Setup**:
```bash
# First create resources
./subscription-level-deployment.sh --auto-approve
# Note the nonce and use it for deletion
export TEST_NONCE="from-deployment-output"
```

**Steps**:
1. Run: `./subscription-level-deletion.sh $SUBSCRIPTION_ID $TEST_NONCE --auto-approve`
2. Monitor output for all deletion phases

**Expected Results**:
- Script exits with code 0
- All phases complete successfully in proper order:
  - ✅ Resource discovery
  - ✅ Role assignments deletion
  - ✅ Custom role definition deletion  
  - ✅ Service principal deletion
  - ✅ Azure AD application deletion
- "All discovered resources deleted successfully" message
- Backend notification sent (if configured)

**Verification**:
```bash
# Verify resources were deleted
az ad app list --display-name "*-${TEST_NONCE}"
az ad sp list --display-name "*-${TEST_NONCE}"
az role definition list --name "*-${TEST_NONCE}" --custom-role-only
```

#### DEL-002: Deletion Order Verification
**Objective**: Verify resources are deleted in proper dependency order.

**Steps**:
1. Create resources with deployment script
2. Run deletion script with detailed logging
3. Monitor the order of deletion operations

**Expected Results**:
- Deletion order is correct:
  1. Role assignments (if any)
  2. Custom role definition
  3. Service principal
  4. Azure AD application
- Each step completes before the next begins
- Proper dependency handling prevents errors

#### DEL-003: Partial Deletion Failure
**Objective**: Test behavior when some deletions fail.

**Setup**:
1. Create test resources
2. Modify permissions to prevent deletion of one resource type

**Steps**:
1. Run deletion script
2. Observe error handling

**Expected Results**:
- Script continues with other deletions despite failures
- Clear error messages for failed operations
- Final status indicates "completed with errors"
- Backend notification indicates failure
- Script exits with code 1

### 6. Error Handling & Cleanup Tests

#### ERR-001: SIGINT Handling (Ctrl+C)
**Objective**: Test behavior when interrupted during deletion.

**Steps**:
1. Start deletion with valid parameters
2. Press Ctrl+C during resource discovery or deletion
3. Verify interrupt handling

**Expected Results**:
- Script catches SIGINT signal
- Graceful shutdown without corrupting resources
- Clear message about interruption
- No partial state corruption

#### ERR-002: Azure API Failures
**Objective**: Test handling of Azure service failures.

**Steps**:
1. Run deletion during Azure service degradation (if possible)
2. Or simulate by modifying Azure CLI behavior
3. Verify error resilience

**Expected Results**:
- Clear error messages for API failures
- Appropriate retry logic (where applicable)
- Graceful failure handling
- Proper error reporting

### 7. Backend Integration Tests

#### BCK-001: Successful Backend Notification
**Objective**: Test deletion status updates to backend.

**Setup**:
```bash
export SALT_HOST="https://httpbin.org"  # Test endpoint (will be combined with endpoint path)
export BEARER_TOKEN="test-valid-token"
```

**Steps**:
1. Run full deletion with backend configuration
2. Monitor network requests (if possible)
3. Verify backend notifications

**Expected Results**:
- DELETE request sent to full URL: `{salt-host}/v1/cloud-connect/organizations/accounts/azure/{subscription-id}`
- Successful HTTP response logged
- "Successfully sent deletion request to backend" message

#### BCK-002: Backend URL Unreachable
**Objective**: Test handling of network failures.

**Setup**:
```bash
export SALT_HOST="https://nonexistent.invalid.domain"
export BEARER_TOKEN="test-token"
```

**Steps**:
1. Run deletion with unreachable backend URL
2. Observe error handling

**Expected Results**:
- Resource deletion continues despite backend failures
- Warning messages about backend communication failures
- Core Azure resource deletion still succeeds
- Script completes successfully

#### BCK-003: Invalid Bearer Token
**Objective**: Test authentication failures with backend.

**Setup**:
```bash
export SALT_HOST="https://httpbin.org"  # Base URL (endpoint path will be appended)
export BEARER_TOKEN="invalid-token"
```

**Expected Results**:
- Backend returns authentication error
- Script logs warning but continues
- Azure deletion still completes successfully

### 8. Special Mode Tests

#### MODE-001: Dry-Run Mode
**Objective**: Test dry-run functionality.

**Steps**:
1. Create resources with deployment script
2. Run: `./subscription-level-deletion.sh $SUBSCRIPTION_ID $NONCE --dry-run`
3. Verify no actual deletions occur

**Expected Results**:
- Resource discovery completes normally
- "DRY RUN MODE" messages displayed
- Script exits after discovery phase
- No actual resource deletions performed
- Resources remain intact after script completion

#### MODE-002: Auto-Approve Mode
**Objective**: Test automatic approval functionality.

**Steps**:
1. Run deletion script with `--auto-approve` flag
2. Verify no interactive prompts

**Expected Results**:
- Script proceeds without user confirmation
- "Auto-approve mode enabled" message
- No interactive prompts for deletion confirmation
- Deletion proceeds automatically

#### MODE-003: Interactive Mode (Dual Confirmation System)
**Objective**: Test user confirmation prompts with dual confirmation system.

**Steps**:
1. Run script without `--auto-approve` flag
2. Test both confirmation prompts:
   - Initial confirmation before resource discovery
   - Final confirmation after resource discovery
3. Test both "y" and "n" responses for each prompt

**Expected Results**:
- **First prompt**: "Do you want to proceed with the deletion? (y/n):"
  - "y" response proceeds to resource discovery
  - "n" response cancels with "Deletion cancelled by user" message
- **Second prompt**: "Do you want to proceed with deleting the discovered resources? (y/n):"
  - Only appears after successful resource discovery
  - Shows exactly what resources will be deleted
  - "y" response proceeds with actual deletion
  - "n" response cancels with "Deletion cancelled by user" message
- Both prompts are skipped when `--auto-approve` is used

#### MODE-004: Dual Confirmation Edge Cases
**Objective**: Test edge cases in the dual confirmation system.

**Test Case A - Cancel at First Prompt**:
1. Run script without `--auto-approve`
2. Answer "n" to first prompt
3. Verify no resource discovery occurs

**Test Case B - Cancel at Second Prompt**:
1. Run script without `--auto-approve`
2. Answer "y" to first prompt
3. Let resource discovery complete
4. Answer "n" to second prompt
5. Verify no resources are deleted

**Test Case C - Auto-Approve Bypasses Both**:
1. Run script with `--auto-approve`
2. Verify no prompts appear
3. Verify script proceeds directly through both discovery and deletion

**Expected Results**:
- **Case A**: Script exits after first "n", no Azure API calls made
- **Case B**: Resources discovered but not deleted, script exits gracefully
- **Case C**: Both confirmations bypassed, script proceeds automatically

### 9. Edge Cases and Boundary Tests

#### EDGE-001: Malformed Nonce in Resource Names
**Objective**: Test handling of resources with unexpected naming.

**Setup**:
1. Manually create resources with similar but incorrect naming patterns
2. Run deletion with correct nonce

**Expected Results**:
- Script only deletes resources with exact nonce match
- Resources with similar names are not affected
- Precise pattern matching prevents accidental deletions

#### EDGE-002: Resources Without Expected Tags
**Objective**: Test deletion of resources missing Salt-specific tags.

**Setup**:
1. Create resources using deployment script
2. Manually remove tags from some resources
3. Run deletion script

**Expected Results**:
- Script warns about missing tags
- Deletion may proceed with caution warnings
- User is alerted to potential non-Salt resources

#### EDGE-003: Already Deleted Resources
**Objective**: Test handling of resources deleted by other means.

**Setup**:
1. Create resources with deployment script
2. Manually delete some resources via Azure portal/CLI
3. Run deletion script

**Expected Results**:
- Script handles missing resources gracefully
- Clear messages about resources already deleted
- No errors for attempting to delete non-existent resources
- Script completes successfully

## Test Execution Tracking

Use this checklist to track test execution:

### Dependencies Tests
- [ ] DEP-001: Missing Azure CLI
- [ ] DEP-002: Missing jq utility  
- [ ] DEP-003: Not logged into Azure CLI

### Input Validation Tests
- [ ] INP-001: Invalid subscription ID format
- [ ] INP-002: Invalid nonce format
- [ ] INP-003: Missing required parameters

### Authentication Tests  
- [ ] AUTH-001: Insufficient permissions
- [ ] AUTH-002: Invalid subscription ID

### Resource Discovery Tests
- [ ] RDS-001: Successful resource discovery
- [ ] RDS-002: No resources found
- [ ] RDS-003: Partial resources found

### Resource Deletion Tests
- [ ] DEL-001: Successful full deletion
- [ ] DEL-002: Deletion order verification
- [ ] DEL-003: Partial deletion failure

### Error Handling Tests
- [ ] ERR-001: SIGINT handling
- [ ] ERR-002: Azure API failures

### Backend Integration Tests
- [ ] BCK-001: Successful backend notification
- [ ] BCK-002: Backend URL unreachable  
- [ ] BCK-003: Invalid bearer token

### Special Mode Tests
- [ ] MODE-001: Dry-run mode
- [ ] MODE-002: Auto-approve mode
- [ ] MODE-003: Interactive mode (dual confirmation)
- [ ] MODE-004: Dual confirmation edge cases

### Edge Case Tests
- [ ] EDGE-001: Malformed nonce in resource names
- [ ] EDGE-002: Resources without expected tags
- [ ] EDGE-003: Already deleted resources

## Test Data Reference

### Valid Test Data
```json
{
  "subscription_id": "550e8400-e29b-41d4-a716-446655440000",
  "nonce": "a1b2c3d4",
  "salt_host": "https://httpbin.org",
  "bearer_token": "valid-test-token-123"
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
  "invalid_nonces": [
    "",
    "invalid-nonce",
    "12345",
    "a1b2c3d4e5",
    "ABCD1234",
    "g1h2i3j4"
  ]
}
```

## Cleanup Procedures

After each test, ensure proper cleanup:

### Manual Cleanup Commands
```bash
# Clean up any remaining test resources by tag
az ad app list --query "[?contains(displayName, 'Test')].[appId,displayName]" -o table
az ad app list --query "[?contains(displayName, 'Test')].appId" -o tsv | xargs -I {} az ad app delete --id {}

# Clean up service principals  
az ad sp list --query "[?contains(displayName, 'Test')].[id,displayName]" -o table
az ad sp list --query "[?contains(displayName, 'Test')].id" -o tsv | xargs -I {} az ad sp delete --id {}

# Clean up custom roles
az role definition list --custom-role-only --query "[?contains(roleName, 'Test')].[id,roleName]" -o table
az role definition list --custom-role-only --query "[?contains(roleName, 'Test')].roleName" -o tsv | xargs -I {} az role definition delete --name "{}"

# Verify cleanup
az ad app list --query "[?contains(displayName, 'Test')]" 
az ad sp list --query "[?contains(displayName, 'Test')]"
az role definition list --custom-role-only --query "[?contains(roleName, 'Test')]"
```

### Test Resource Creation for Testing Deletion
```bash
# Create test resources for deletion testing
export TEST_NONCE=$(openssl rand -hex 4)
export APP_NAME="TestDeletionApp"
export ROLE_NAME="TestDeletionRole"

# Run deployment to create resources
./subscription-level-deployment.sh --auto-approve

# Use the nonce from deployment log for deletion testing
```

## Test Environment Considerations

### Azure Cloud Shell
- Session timeouts may affect long-running tests
- Network connectivity variations
- Temporary storage limitations
- Built-in Azure CLI authentication

### Local Environment
- Ensure Azure CLI is properly authenticated
- Verify all dependencies are installed
- Consider network proxy settings
- Multiple Azure CLI profiles may cause confusion

### Subscription Considerations  
- Use dedicated test subscription
- Verify sufficient resource quotas
- Ensure appropriate permissions for both creation and deletion
- Monitor costs during testing
- Be aware of Azure AD tenant limitations

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
- Check Azure AD permissions for application/role deletion
- Ensure sufficient privileges for the specific resource types

**Resource Not Found Errors**
- Verify nonce is correct (check deployment logs)
- Resources may have been deleted by other means
- Check subscription context is correct
- Verify resource naming patterns

**Backend Communication Failures**
- Verify network connectivity
- Check firewall/proxy settings  
- Validate bearer token format and permissions
- Test with simple endpoints like httpbin.org

**Nonce Format Errors**
- Nonce must be exactly 8 hexadecimal characters
- Check deployment logs for correct nonce value
- Ensure lowercase format (script converts automatically)

### Recovery Procedures

**Partial Deletion State**
```bash
# If script was interrupted, manually verify remaining resources
az ad app list --query "[?contains(displayName, '-$NONCE')]"
az ad sp list --query "[?contains(displayName, '-$NONCE')]" 
az role definition list --name "*-$NONCE" --custom-role-only

# Clean up remaining resources manually
# Use the Manual Cleanup Commands above
```

**Test Environment Reset**
```bash
# Clean up all test resources (use with caution)
./azure/tests/utils/azure-verifier.sh --cleanup-all-test-resources
```

## Security Considerations

### Test Data Security
- Never use production credentials in tests
- Use mock tokens and test-specific identifiers  
- Clean up test resources promptly
- Monitor for accidentally committed secrets
- Rotate test bearer tokens regularly

### Test Isolation
- Use unique nonces for each test run
- Avoid resource name conflicts between tests
- Properly scope permissions to test subscription
- Isolate test environment from production
- Use separate Azure AD tenant for testing if possible

### Deletion Safety
- Always verify resource ownership before deletion
- Use dry-run mode when in doubt
- Check resource tags to confirm Salt origin
- Maintain audit logs of all deletion operations
- Have rollback procedures for critical mistakes

---

**Test Plan Version**: 1.0  
**Last Updated**: 2025-01-09  
**Target Script**: `subscription-level-deletion.sh`  
**Estimated Execution Time**: 3-4 hours for full test suite  
**Dependencies**: Requires existing resources created by `azure-deployment-script.sh`
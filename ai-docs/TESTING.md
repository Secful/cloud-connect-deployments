# Testing

## Test Strategy
Manual test plan-based validation focusing on Azure resource creation/deletion workflows and Salt Security API integration. Testing emphasizes real Azure environment validation with comprehensive logging.

## Running Tests

### Manual Test Execution
```bash
# Run subscription-level deployment test plan
# Follow procedures in azure/subscription/deployment/DEPLOYMENT_MANUAL_TEST_PLAN.md

# Run subscription-level deletion test plan  
# Follow procedures in azure/subscription/deletion/DELETION_MANUAL_TEST_PLAN.md

# Run management-group deployment test plan
# Follow procedures in azure/management-group/deployment/DEPLOYMENT_MANUAL_TEST_PLAN.md

# Run management-group deletion test plan
# Follow procedures in azure/management-group/deletion/DELETION_MANUAL_TEST_PLAN.md
```

### Script Validation
```bash
# Syntax validation
bash -n azure/subscription/deployment/subscription-level-deployment.sh

# Parameter validation testing
./azure/subscription/deployment/subscription-level-deployment.sh --help

# Dependency checking
./azure/subscription/deployment/subscription-level-deployment.sh --check-dependencies
```

## Test Coverage
Manual test plans cover:
- **Parameter Validation**: All required and optional parameters
- **Dependency Verification**: Azure CLI, jq, curl, uuidgen availability
- **Azure Resource Creation**: AD apps, service principals, custom roles, role assignments
- **Salt Security Integration**: API communication, status reporting, error handling
- **Error Scenarios**: Invalid parameters, network failures, permission issues
- **Resource Cleanup**: Complete deletion of created resources
- **Multi-subscription Scenarios**: Parallel processing validation

## Writing Tests
Manual test plans follow standardized format:

```markdown
## Test Case: [Description]
**Objective**: Clear test goal
**Prerequisites**: Required setup and permissions
**Steps**:
1. Specific action with expected parameters
2. Verification step with expected outcomes  
3. Cleanup or rollback procedures

**Expected Results**: 
- Specific success criteria
- Log file validation points
- Azure resource verification steps

**Actual Results**: [To be filled during test execution]
**Status**: [Pass/Fail/Blocked]
```

## Test Data
- **Test Subscription IDs**: Use non-production Azure subscriptions
- **Test Management Groups**: Isolated management group hierarchies  
- **Test Salt Host**: Development/staging Salt Security environments
- **Test Credentials**: Time-limited test bearer tokens
- **Unique Identifiers**: Generated nonce values for resource isolation

## Test Environment Requirements
- **Azure Permissions**: 
  - Azure AD application creation rights
  - Custom role definition permissions
  - Role assignment capabilities at subscription scope
- **Azure CLI**: Authenticated session with target subscription access
- **Salt Security Access**: Valid bearer token for test environment
- **Network Connectivity**: Outbound HTTPS access to Azure and Salt Security APIs
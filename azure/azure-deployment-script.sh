#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[1;95m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

# Logging system - INFO, WARNING, ERROR levels only

# Generate unique nonce for resource names and log file (last 8 characters of UUID)
full_uuid=$(uuidgen | tr '[:upper:]' '[:lower:]')
full_nonce=${full_uuid##*-}
nonce=${full_nonce: -8}

# Create log file with timestamp and nonce
LOG_TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="azure-deployment-${nonce}-${LOG_TIMESTAMP}.log"

# Initialize log file
echo "=== Azure Deployment Script Log ===" > "$LOG_FILE"
echo "Timestamp: $(date)" >> "$LOG_FILE"
echo "Nonce: $nonce" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local color="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Always write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Write to console with color
    if [ -n "$color" ]; then
        echo -e "${color}${message}${NC}"
    else
        echo -e "$message"
    fi
}

log_info() {
    log_message "INFO" "$1" "$2"
}

log_error() {
    log_message "ERROR" "$1" "${RED}"
}

log_warning() {
    log_message "WARNING" "$1" "${YELLOW}"
}

# ============================================================================
# FUNCTION DEFINITIONS
# ============================================================================

# Function to check required dependencies
check_dependencies() {
    log_info "Checking required dependencies..." "${CYAN}"
    for cmd in az jq curl uuidgen; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' not found" >&2
            log_error "Please install $cmd and try again" >&2
            exit 1
        fi
    done
    log_info "✅ All dependencies found" "${GREEN}"
    log_info ""
}

# Function to handle cleanup on script exit/interruption
cleanup() {
    local exit_code=$?
    
    # Only cleanup Azure resources on failure or interruption (not on success)
    if [ $exit_code -ne 0 ] || [ "$error_occurred" = "true" ]; then
        log_info ""
        log_warning "Deployment failed/interrupted - cleaning up created resources..."
        
        # Delete resources in reverse order of creation to avoid dependency issues
        # Step 1: Delete role assignments first (required before role definition can be deleted)
        if [ -n "$sp_object_id" ] && ([ -n "$role_definition_id" ] || [ -n "$ROLE_NAME_WITH_NONCE" ]); then
            log_info ""
            log_info "Checking for role assignments to delete..." "${YELLOW}"
            
            # Get the role ID if we don't have it yet (race condition case)
            local cleanup_role_id="$role_definition_id"
            if [ -z "$cleanup_role_id" ] && [ -n "$ROLE_NAME_WITH_NONCE" ]; then
                if role_list_result=$(az role definition list --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[?roleName=='$ROLE_NAME_WITH_NONCE']" 2>&1); then
                    if [ "$role_list_result" != "[]" ] && [ -n "$role_list_result" ]; then
                        cleanup_role_id=$(echo "$role_list_result" | jq -r '.[0].id // empty' 2>/dev/null)
                    fi
                fi
            fi
            
            if [ -n "$cleanup_role_id" ]; then
                # Get role assignments for the service principal with the custom role
                if assignments=$(az role assignment list \
                    --assignee "$sp_object_id" \
                    --role "$cleanup_role_id" \
                    --scope "/subscriptions/$SUBSCRIPTION_ID" \
                    --query "[].{id:id}" -o json 2>/dev/null); then
                    
                    if [ "$assignments" != "[]" ] && [ -n "$assignments" ]; then
                        assignment_count=$(echo "$assignments" | jq length)
                        log_info "Found $assignment_count role assignment(s) to delete" "${YELLOW}"
                        
                        # Delete each role assignment
                        echo "$assignments" | jq -r '.[].id' | while read -r assignment_id; do
                            if [ -n "$assignment_id" ]; then
                                log_info "Deleting role assignment: $assignment_id" "${YELLOW}"
                                if az role assignment delete --ids "$assignment_id" >/dev/null 2>&1; then
                                    log_info "Role assignment deleted successfully" "${GREEN}"
                                else
                                    log_warning "Failed to delete role assignment: $assignment_id"
                                fi
                            fi
                        done
                    else
                        log_info "No role assignments found (this is normal)" "${GREEN}"
                    fi
                else
                    log_warning "Could not check for role assignments"
                fi
            fi
        fi
        
        # Step 2: Delete custom role definition (now that assignments are gone)
        log_info "Checking if custom role exists: $ROLE_NAME_WITH_NONCE" "${YELLOW}"
        if [ -n "$role_definition_id" ]; then
            log_info "Found! Deleting custom role definition..." "${YELLOW}"
            if role_delete_result=$(az role definition delete --name "$ROLE_NAME_WITH_NONCE" --scope "/subscriptions/$SUBSCRIPTION_ID" 2>&1); then
                log_info "Custom role definition deleted successfully" "${GREEN}"
            else
                log_warning "Custom role definition deletion failed: $role_delete_result"
            fi
        elif [ -n "$ROLE_NAME_WITH_NONCE" ]; then
            # Fallback: check if role exists by name and delete it (handles race conditions)
            # Use role definition list to find the role by name pattern, then extract ID
            if role_list_result=$(az role definition list --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[?roleName=='$ROLE_NAME_WITH_NONCE']" 2>&1); then
                if [ "$role_list_result" != "[]" ] && [ -n "$role_list_result" ]; then
                    role_definition_id=$(echo "$role_list_result" | jq -r '.[0].id // empty' 2>/dev/null)
                    if [ -n "$role_definition_id" ] && [ "$role_definition_id" != "null" ]; then
                        log_info "Found! Deleting custom role definition..." "${YELLOW}"
                        log_info "Role ID: $role_definition_id" "${YELLOW}"
                        if delete_result=$(az role definition delete --name "$ROLE_NAME_WITH_NONCE" --scope "/subscriptions/$SUBSCRIPTION_ID" 2>&1); then
                            log_info "Role deleted successfully" "${GREEN}"
                        else
                            log_warning "Role deletion failed: $delete_result"
                        fi
                    else
                        log_info "Role found in list but could not extract ID" "${YELLOW}"
                    fi
                else
                    log_info "Role not found in role definition list - skipping role cleanup" "${YELLOW}"
                fi
            else
                log_info "Failed to list role definitions. CLI result: $role_list_result" "${YELLOW}"
                log_info "This might be due to Azure propagation delays or subscription context issues" "${YELLOW}"
            fi
        else
            log_info "No custom role information available - skipping role cleanup" "${YELLOW}"
        fi
        
        # Step 3: Delete service principal
        log_info ""
        log_info "Checking if service principal exists..." "${YELLOW}"
        if [ -n "$sp_object_id" ]; then
            log_info "Found! Deleting service principal..." "${YELLOW}"
            if sp_delete_result=$(az ad sp delete --id "$sp_object_id" 2>&1); then
                log_info "Service principal deleted successfully" "${GREEN}"
            else
                log_warning "Service principal deletion failed: $sp_delete_result"
            fi
        else
            log_info "No service principal information available - skipping service principal cleanup" "${YELLOW}"
        fi
        
        # Step 4: Delete Azure AD application
        log_info ""
        log_info "Checking if Azure AD application exists..." "${YELLOW}"
        if [ -n "$app_id" ]; then
            log_info "Found! Deleting Azure AD application (and client secret)..." "${YELLOW}"
            if app_delete_result=$(az ad app delete --id "$app_id" 2>&1); then
                log_info "Azure AD application deleted successfully" "${GREEN}"
            else
                log_warning "Azure AD application deletion failed: $app_delete_result"
            fi
        else
            log_info "No Azure AD application information available - skipping application cleanup" "${YELLOW}"
        fi
        
        # Send failure notification to backend only for interruptions (not normal script errors)
        if [ $exit_code -eq 130 ] || [ $exit_code -eq 143 ]; then
            log_info ""
            log_info "Notifying backend of script interruption..." "${YELLOW}"
            send_backend_status "Failed" "Script interrupted or terminated unexpectedly" 2>/dev/null || true
        fi
        
        # Show appropriate cleanup completion message
        if [ -n "$role_definition_id" ] || [ -n "$sp_object_id" ] || [ -n "$app_id" ]; then
            log_info "✅ Successfully deleted the created resources" "${GREEN}"
        else
            log_info "✅ Cleanup completed (no Azure resources were created)" "${GREEN}"
        fi
    else
        log_info ""
        log_info "Deployment completed successfully - keeping created resources" "${GREEN}"
    fi
    
    # Always remove temporary role definition file
    if [ -f custom-role.json ]; then
        rm -f custom-role.json
        log_info "Removed temporary role definition file" "${YELLOW}"
    fi
}

# Function to check Azure CLI authentication
check_azure_auth() {
    log_info "Checking Azure CLI authentication..." "${CYAN}"
    
    # Check if user is logged in
    if ! az account show &>/dev/null; then
        log_error "Not logged into Azure CLI" >&2
        log_error "Please run 'az login' first and try again" >&2
        exit 1
    fi
    
    # Check if we can access the target subscription
    if ! az account show --subscription "$SUBSCRIPTION_ID" &>/dev/null; then
        log_error "Cannot access subscription '$SUBSCRIPTION_ID'" >&2
        log_error "Please verify:" >&2
        log_error "  1. The subscription ID is correct and exists" >&2
        log_error "  2. You have access to this subscription" >&2
        log_error "  3. Try running: az account set --subscription $SUBSCRIPTION_ID" >&2
        log_error "     (This sets your Azure CLI context to use this subscription)" >&2
        log_error "  4. Or list available subscriptions: az account list --output table" >&2
        log_error "     (This shows all subscriptions you have access to)" >&2
        exit 1
    fi
    
    # Set the subscription as current
    az account set --subscription "$SUBSCRIPTION_ID" &>/dev/null
    current_sub=$(az account show --query name -o tsv 2>/dev/null)
    log_info "✅ Authenticated to Azure subscription: $current_sub" "${GREEN}"
    log_info ""
}

# Helper function to validate UUID format
validate_uuid() {
    local var_name="$1"
    local var_value="$2"
    
    # Check if value is empty
    if [ -z "$var_value" ]; then
        log_error "Missing required param: $var_name" >&2
        exit 1
    fi
    
    if [[ ! "$var_value" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        log_error "Invalid $var_name format: $var_value" >&2
        log_error "Expected UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
        exit 1
    fi
}

# Helper function to validate name format (alphanumeric, hyphens, underscores)
validate_name() {
    local var_name="$1"
    local var_value="$2"
    
    # Check if value is empty
    if [ -z "$var_value" ]; then
        log_error "Missing required param: $var_name" >&2
        exit 1
    fi
    
    if [[ ! "$var_value" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ "$var_value" =~ [[:space:]] ]]; then
        log_error "Invalid $var_name format: $var_value" >&2
        log_error "$var_name should only contain letters, numbers, hyphens, and underscores" >&2
        exit 1
    fi
}

# Helper function to validate URL format (optional parameter)
validate_url() {
    local var_name="$1"
    local var_value="$2"
    
    # Check if value is empty
    if [ -z "$var_value" ]; then
        log_error "Missing required param: $var_name" >&2
        exit 1
    fi
    
    if [[ ! "$var_value" =~ ^https?:// ]]; then
        log_error "Invalid $var_name format: $var_value" >&2
        log_error "$var_name must start with http:// or https://" >&2
        exit 1
    fi
}

# Function to validate input parameters
validate_inputs() {
    log_info "Validating input parameters..." "${CYAN}"
    
    # Validate parameters in the same order as they are assigned (positions 0-7)
    
    # Position 0: Subscription ID (UUID format)
    validate_uuid "subscription ID" "$SUBSCRIPTION_ID"
    
    # Position 1: Backend URL format
    validate_url "backend URL" "$BACKEND_URL"
    
    # Position 2: Bearer token (required)
    if [ -z "$BEARER_TOKEN" ]; then
        log_error "Missing required param: BEARER_TOKEN" >&2
        exit 1
    fi
    
    # Position 3: Installation ID (UUID format)
    validate_uuid "installation ID" "$INSTALLATION_ID"
    
    # Position 4: Attempt ID (UUID format)
    validate_uuid "attempt ID" "$ATTEMPT_ID"
    
    # Position 5: App name (alphanumeric, hyphens, underscores)
    validate_name "app name" "$APP_NAME"
    
    # Position 6: Role name (alphanumeric, hyphens, underscores)
    validate_name "role name" "$ROLE_NAME"
    
    # Position 7: Created by (no validation needed - has default)
    
    log_info "✅ All input parameters validated" "${GREEN}"
    log_info ""
}

# Function to handle errors
handle_error() {
    error_occurred=true
    error_message="$1"
    log_error "$error_message" >&2
    log_info ""
}

# Function to send deployment status to Salt Security backend
send_backend_status() {
    local deployment_status="$1"
    local error_message="$2"
    
    # Skip if backend URL or token not provided
    if [ -z "$BACKEND_URL" ] || [ -z "$BEARER_TOKEN" ]; then
        log_warning "⚠️ Skipping backend status update - Backend URL or Bearer Token not provided"
        return 0
    fi
    
    log_info "Sending deployment status to Salt Security backend: $deployment_status" "${CYAN}${BOLD}"
    
    backend_payload=$(cat <<EOF
{
  "accountId": "$SUBSCRIPTION_ID",
  "stackId": "$nonce",
  "region": "Global",
  "errorMessage": "$error_message",
  "createdBy": "$CREATED_BY",
  "deploymentStatus": "$deployment_status",
  "installationId": "$INSTALLATION_ID",
  "attemptId": "$ATTEMPT_ID",
  "connectionFields": {
    "clientId": "$app_id",
    "tenantId": "$tenant_id",
    "clientSecret": "$client_secret",
    "subscriptionId": "$SUBSCRIPTION_ID"
  }
}
EOF
)

    if response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        -d "$backend_payload" \
        "$BACKEND_URL" 2>&1); then

        http_code=$(echo "$response" | tail -n 1)
        response_body=$(echo "$response" | sed '$d')

        if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
            log_info "✅ Successfully sent status '$deployment_status' to backend (HTTP $http_code)" "${GREEN}"
            if [ -n "$response_body" ]; then
                log_info "Backend response: $response_body"
                log_info ""
            fi
            return 0
        else
            log_warning "⚠️ Backend webhook returned HTTP $http_code"
            log_warning "Response: $response_body"
            log_info ""
            return 1
        fi
    else
        log_warning "⚠️ Failed to send status to backend webhook"
        log_info ""
        return 1
    fi
}

# Function to verify service principal is ready for authentication
verify_sp_ready() {
    local max_attempts=10
    local attempt=1
    
    log_info "Verifying service principal authentication readiness..." "${CYAN}${BOLD}"
    log_info "Note: This will change your Azure CLI login context. You will need to run 'az login' again after the script completes if you want to run this script again or use other Azure CLI commands." "${MAGENTA}"
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Testing service principal authentication (attempt $attempt/$max_attempts)..." "${YELLOW}"
        
        if az login --service-principal -u "$app_id" -p "$client_secret" --tenant "$tenant_id" >/dev/null 2>&1; then
            log_info "✅ Service principal is ready for authentication" "${GREEN}"
            log_info ""
            az logout >/dev/null 2>&1
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_info "⏳ Service principal not ready yet, waiting 30 seconds..." "${YELLOW}"
            sleep 30
        fi
        ((attempt++))
    done
    
    log_error "❌ Service principal authentication failed after $max_attempts attempts"
    return 1
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

# Log script start
log_info ""
log_info "Azure Deployment Script starting..." "${GREEN}${BOLD}"
log_info "Log file: $LOG_FILE" "${CYAN}"
log_info ""

# Check dependencies before proceeding
check_dependencies

# Set up signal handling for cleanup
trap cleanup EXIT
trap 'echo -e "\n${YELLOW}Received interrupt signal, cleaning up...${NC}"; exit 130' INT TERM

# Check for non-interactive flag and filter arguments
AUTO_APPROVE=false
filtered_args=()
for arg in "$@"; do
    case $arg in
        --auto-approve)
            AUTO_APPROVE=true
            ;;
        *)
            filtered_args+=("$arg")
            ;;
    esac
done

# Check if we have enough mandatory parameters
if [ ${#filtered_args[@]} -lt 5 ]; then
    log_error "Missing required parameters. Expected 5 mandatory parameters, got ${#filtered_args[@]}" >&2
    log_error "Usage: $0 <subscription_id> <backend_url> <bearer_token> <installation_id> <attempt_id> [app_name] [role_name] [created_by] [--auto-approve]" >&2
    exit 1
fi

# Assign mandatory parameters first (positions 0-4)
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-${filtered_args[0]}}"
BACKEND_URL="${BACKEND_URL:-${filtered_args[1]}}"
BEARER_TOKEN="${BEARER_TOKEN:-${filtered_args[2]}}"
INSTALLATION_ID="${INSTALLATION_ID:-${filtered_args[3]}}"
ATTEMPT_ID="${ATTEMPT_ID:-${filtered_args[4]}}"

# Interactive prompts for APP_NAME and ROLE_NAME if not provided (positions 5-6)
if [ -z "$APP_NAME" ] && [ ${#filtered_args[@]} -le 5 ]; then
    default_app_name="SaltAppServicePrincipal"
    echo -n "Enter APP_NAME (default: $default_app_name): "
    read user_app_name
    APP_NAME="${user_app_name:-$default_app_name}"
else
    APP_NAME="${APP_NAME:-${filtered_args[5]:-SaltAppServicePrincipal}}"
fi

if [ -z "$ROLE_NAME" ] && [ ${#filtered_args[@]} -le 6 ]; then
    default_role_name="SaltCustomAppRole"
    echo -n "Enter ROLE_NAME (default: $default_role_name): "
    read user_role_name
    ROLE_NAME="${user_role_name:-$default_role_name}"
else
    ROLE_NAME="${ROLE_NAME:-${filtered_args[6]:-SaltCustomAppRole}}"
fi

CREATED_BY="${CREATED_BY:-${filtered_args[7]:-Salt Security}}"

log_info ""
log_info "╔══════════════════════════════════════════════════════════════════════════════════╗" "${BLUE}${BOLD}"
log_info "║                          AZURE AUTHENTICATION SETUP                              ║" "${BLUE}${BOLD}"
log_info "╚══════════════════════════════════════════════════════════════════════════════════╝" "${BLUE}${BOLD}"
log_info ""
log_info "This script will create and configure Azure authentication components in your subscription for automated access:" "${CYAN}"
log_info ""
log_info "• App Registration - Creates your application identity in Azure AD" "${YELLOW}"
log_info "• Client Secret - Generates a secure password for your application" "${YELLOW}"
log_info "• Service Principal - Creates a security identity that can be assigned permissions" "${YELLOW}"
log_info "• Custom Role - Defines specific permissions for API Management, Kubernetes, and Resource Groups" "${YELLOW}"
log_info "• Role Assignment - Grants the custom role permissions to your service principal" "${YELLOW}"
log_info "• Salt Security Integration - Securely sends deployment status to Salt Security" "${YELLOW}"
log_info ""
log_info "Target Subscription: $SUBSCRIPTION_ID" "${MAGENTA}${BOLD}"
log_info "Application Name: $APP_NAME" "${MAGENTA}${BOLD}"
log_info "Custom Role Name: $ROLE_NAME" "${MAGENTA}${BOLD}"
log_info ""
log_info "Ready to begin setup..." "${CYAN}${BOLD}"
log_info ""

if [ "$AUTO_APPROVE" = true ]; then
    log_info "Auto-approve mode enabled - Starting Azure authentication setup..." "${GREEN}${BOLD}"
    log_info ""
else
    echo -e "${YELLOW}Do you want to proceed? (y/n): ${NC}\c"
    read -r response
    log_info ""

    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Starting Azure authentication setup..." "${GREEN}${BOLD}"
        log_info ""
    else
        log_info "Setup cancelled by user." "${YELLOW}"
        exit 0
    fi
fi

# Initialize variables for error handling
app_id=""
client_secret=""
sp_object_id=""
role_definition_id=""
tenant_id=""
backend_sent=false
error_occurred=false
error_message=""

# Create resource tag and append nonce to resource names for uniqueness (nonce already generated at script start)
resource_tag="CreatedBySalt-${nonce}"
APP_NAME_WITH_NONCE="${APP_NAME}-${nonce}"
ROLE_NAME_WITH_NONCE="${ROLE_NAME}-${nonce}"

log_info "Resources will be tagged with: $resource_tag" "${CYAN}${BOLD}"
log_info "Resource names will include nonce: ${nonce}" "${CYAN}${BOLD}"
log_info ""

# Validate input parameters
validate_inputs

# Check Azure CLI authentication before starting deployment
check_azure_auth

# Send initial "Initiated" status to backend
send_backend_status "Initiated" ""

log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "                    AZURE AD APPLICATION SETUP" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

# 1. Create Azure AD Application
log_info "Creating Azure AD application (app registration): $APP_NAME_WITH_NONCE" "${CYAN}${BOLD}"

# Check if app already exists (should be rare with nonce, but check anyway)
if existing_app=$(az ad app list --display-name "$APP_NAME_WITH_NONCE" --query "[0]" 2>/dev/null) && [ "$existing_app" != "null" ] && [ -n "$existing_app" ]; then
    existing_app_id=$(echo "$existing_app" | jq -r '.appId')
    handle_error "Application '$APP_NAME_WITH_NONCE' already exists (ID: $existing_app_id). Please choose a different name or delete the existing application first."
elif app_result=$(az ad app create --display-name "$APP_NAME_WITH_NONCE" --sign-in-audience AzureADMyOrg 2>&1); then
    # Extract JSON part (skip any WARNING lines)
    json_part=$(echo "$app_result" | sed -n '/^{/,$p')
    if echo "$json_part" | jq . >/dev/null 2>&1; then
        app_id=$(echo "$json_part" | jq -r '.appId')
        app_object_id=$(echo "$json_part" | jq -r '.id')
        log_info "Application created - App ID: $app_id" "${GREEN}"
        
        # Tag the application
        log_info "Tagging application with: $resource_tag" "${CYAN}"
        if az ad app update --id "$app_id" --set tags="[\"$resource_tag\"]" >/dev/null 2>&1; then
            log_info "✅ Application tagged successfully" "${GREEN}"
            log_info ""
        else
            log_warning "⚠️ Failed to tag application (non-critical)"
            log_info ""
        fi
    else
        handle_error "Failed to parse application creation result: $app_result"
    fi
else
    handle_error "Failed to create Azure AD application: $app_result"
fi

# 2. Create client secret
if [ "$error_occurred" = false ]; then
    log_info "Creating client secret..." "${CYAN}${BOLD}"
    if secret_result=$(az ad app credential reset --id "$app_id" --years 2 2>&1); then
        # Extract JSON part (skip any WARNING lines)
        json_part=$(echo "$secret_result" | sed -n '/^{/,$p')
        if echo "$json_part" | jq . >/dev/null 2>&1; then
            client_secret=$(echo "$json_part" | jq -r '.password')
            log_info "Client secret created" "${GREEN}"
        else
            handle_error "Failed to parse client secret result: $secret_result"
        fi
    else
        handle_error "Failed to create client secret: $secret_result"
    fi
fi

log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "                    SERVICE PRINCIPAL CREATION" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

# 3. Create service principal
if [ "$error_occurred" = false ]; then
    log_info "Creating service principal..." "${CYAN}${BOLD}"
    
    # Check if service principal already exists for this app
    if existing_sp=$(az ad sp show --id "$app_id" --query "{id: id, appId: appId}" 2>/dev/null) && [ -n "$existing_sp" ]; then
        existing_sp_id=$(echo "$existing_sp" | jq -r '.id')
        handle_error "Service principal for application '$app_id' already exists (Object ID: $existing_sp_id). Please delete the existing service principal first."
    elif sp_result=$(az ad sp create --id "$app_id" 2>&1); then
        # Extract JSON part (skip any WARNING lines)
        json_part=$(echo "$sp_result" | sed -n '/^{/,$p')
        if echo "$json_part" | jq . >/dev/null 2>&1; then
            sp_object_id=$(echo "$json_part" | jq -r '.id')
            log_info "Service principal created - Object ID: $sp_object_id" "${GREEN}"
            
            # Tag the service principal
            log_info "Tagging service principal with: $resource_tag" "${CYAN}"
            if az ad sp update --id "$sp_object_id" --set tags="[\"$resource_tag\"]" >/dev/null 2>&1; then
                log_info "✅ Service principal tagged successfully" "${GREEN}"
                log_info ""
            else
                log_warning "⚠️ Failed to tag service principal (non-critical)"
                log_info ""
            fi
        else
            handle_error "Failed to parse service principal result: $sp_result"
        fi
    else
        handle_error "Failed to create service principal: $sp_result"
    fi
fi

# 4. Get tenant ID
if [ "$error_occurred" = false ]; then
    log_info "Retrieving tenant ID..." "${CYAN}${BOLD}"
    if tenant_id=$(az account show --query tenantId -o tsv 2>&1); then
        log_info "Retrieved tenant ID: $tenant_id" "${GREEN}"
    else
        handle_error "Failed to get tenant ID: $tenant_id"
    fi
fi

log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "                    PERMISSION CONFIGURATION" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

# 5. Create custom role definition
if [ "$error_occurred" = false ]; then
    log_info "Creating custom role: $ROLE_NAME_WITH_NONCE" "${CYAN}${BOLD}"
    
    # Check if role already exists (should be rare with nonce, but check anyway)
    if existing_role=$(az role definition list --name "$ROLE_NAME_WITH_NONCE" --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[0]" 2>/dev/null) && [ "$existing_role" != "null" ] && [ -n "$existing_role" ]; then
        existing_role_id=$(echo "$existing_role" | jq -r '.id')
        handle_error "Custom role '$ROLE_NAME_WITH_NONCE' already exists (ID: $existing_role_id). Please choose a different name or delete the existing role first."
    else
        role_definition=$(cat <<EOF
{
  "Name": "$ROLE_NAME_WITH_NONCE",
  "Description": "Custom role for application with specific permissions",
  "Actions": [
    "Microsoft.ApiManagement/*/read",
    "Microsoft.ContainerService/managedClusters/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": ["/subscriptions/$SUBSCRIPTION_ID"]
}
EOF
)

        log_info "Creating temporary role definition file..." "${CYAN}"
        echo "$role_definition" > custom-role.json
        if role_result=$(az role definition create --role-definition custom-role.json 2>&1); then
            # Extract JSON part (skip any WARNING lines)
            json_part=$(echo "$role_result" | sed -n '/^{/,$p')
            if echo "$json_part" | jq . >/dev/null 2>&1; then
                role_definition_id=$(echo "$json_part" | jq -r '.id')
                log_info "Custom role created - Role ID: $role_definition_id" "${GREEN}"
                log_info ""
            else
                handle_error "Failed to parse role creation result: $role_result"
            fi
        else
            handle_error "Failed to create custom role: $role_result"
        fi
    fi
fi

# 6. Assign role to service principal (with retry logic)
if [ "$error_occurred" = false ]; then
    log_info "Assigning custom role to service principal..." "${CYAN}${BOLD}"
    retry_count=0
    max_retries=5

    while [ $retry_count -lt $max_retries ]; do
        if az role assignment create \
          --assignee "$sp_object_id" \
          --role "$role_definition_id" \
          --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null 2>&1; then
            log_info "Role assignment created" "${GREEN}"
            log_info ""
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_info "Role assignment failed, retrying in 10 seconds... (attempt $retry_count/$max_retries)" "${YELLOW}"
                sleep 10
            else
                handle_error "Failed to create role assignment after $max_retries attempts"
            fi
        fi
    done
fi

# 7. Salt Security Integration - Final status and verification
log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "         SALT SECURITY INTEGRATION - DEPLOYMENT STATUS" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

# Send final deployment status to backend
if [ "$error_occurred" = true ]; then
    send_backend_status "Failed" "$error_message"
else
    # Verify service principal is ready for authentication (if all resources created successfully)
    if [ -n "$app_id" ] && [ -n "$client_secret" ] && [ -n "$tenant_id" ]; then
        if ! verify_sp_ready; then
            handle_error "Service principal verification failed"
            send_backend_status "Failed" "$error_message"
        elif [ -n "$sp_object_id" ]; then
            send_backend_status "Succeeded" ""
        else
            send_backend_status "Unknown" "Deployment completed but some resources may not have been created properly"
        fi
    else
        send_backend_status "Unknown" "Deployment completed but some resources may not have been created properly"
    fi
fi

log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "                     DEPLOYMENT SUMMARY" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

# Output results
if [ "$error_occurred" = true ]; then
    log_error "=== DEPLOYMENT FAILED ==="
    log_error "Error: $error_message"
else
    log_info "=== Service Principal Setup Complete ===" "${YELLOW}${BOLD}"
    log_info "Subscription ID: $SUBSCRIPTION_ID"
    log_info "Application ID (Client ID): $app_id"
    log_info "Tenant ID: $tenant_id"
    log_info "Service Principal Object ID: $sp_object_id"
    log_info "Custom Role ID: $role_definition_id"
    log_info "Client Secret: $client_secret" "${MAGENTA}"
    log_warning "Save these values securely - the client secret cannot be retrieved again!"
    log_info ""
fi

# Log script completion
if [ "$error_occurred" = true ]; then
    log_error "Script completed with errors. Check the log file: $LOG_FILE"
else
    log_info "Script completed successfully. Log file: $LOG_FILE" "${GREEN}"
fi

# Exit with error code if deployment failed
if [ "$error_occurred" = true ]; then
    exit 1
fi
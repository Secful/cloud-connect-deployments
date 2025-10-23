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

# Constants
ENDPOINT="v1/cloud-connect/scan/azure"

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
LOG_FILE="subscription-level-deployment-${nonce}-${LOG_TIMESTAMP}.log"

# Initialize log file
echo "=== Subscription Level Deployment Script Log ===" > "$LOG_FILE"
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
    log_info "✅  All dependencies found" "${GREEN}"
    log_info ""
}

# Function to handle cleanup on script exit/interruption
cleanup() {
    local exit_code=$?
    
    # Determine if cleanup is due to error or interruption for color coding
    local is_interrupt=false
    if [ $exit_code -eq 130 ] || [ $exit_code -eq 143 ]; then
        is_interrupt=true
    fi
    
    # Only cleanup Azure resources on failure or interruption (not on success)
    if [ $exit_code -ne 0 ] || [ "$error_occurred" = "true" ]; then
        log_info ""
        log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
        log_info "                    CLEANUP - REMOVING RESOURCES" "${MAGENTA}${BOLD}"
        log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
        log_info ""
        log_warning "Deployment failed/interrupted - prompting for resource cleanup..."
        
        # Always ask user for confirmation before proceeding with deletion
        log_info ""
        log_info "Do you want to check and clean up any Azure resources that may have been created during this deployment? (y/n): " "${YELLOW}${BOLD}"
        read -r user_confirmation
        
        if [[ ! "$user_confirmation" =~ ^[Yy]$ ]]; then
            log_info "User chose not to proceed with resource deletion. Skipping cleanup. Check log file: $LOG_FILE" "${CYAN}${BOLD}"
            log_info ""
        else
            log_info "User chose to proceed with resource deletion. Starting cleanup..." "${CYAN}${BOLD}"
            log_info ""
            # Delete resources in reverse order of creation to avoid dependency issues
            # Step 1: Delete role assignments first (required before role definition can be deleted)
            log_info "Checking for role assignments related to roles created during this deployment..." "${YELLOW}"
            if [ "$role_created_this_run" = true ] && ([ -n "$role_definition_id" ] || [ -n "$ROLE_NAME_WITH_NONCE" ]); then
            
                # Get the role ID if we don't have it yet
                local cleanup_role_id="$role_definition_id"
                if [ -z "$cleanup_role_id" ] && [ -n "$ROLE_NAME_WITH_NONCE" ]; then
                    if role_list_result=$(az role definition list --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[?roleName=='$ROLE_NAME_WITH_NONCE']" 2>&1); then
                        if [ "$role_list_result" != "[]" ] && [ -n "$role_list_result" ]; then
                            cleanup_role_id=$(echo "$role_list_result" | jq -r '.[0].id // empty' 2>/dev/null)
                        fi
                    fi
                fi
                
                if [ -n "$cleanup_role_id" ]; then
                    # Get ALL role assignments for this role (not just for our service principal)
                    if assignments=$(az role assignment list \
                        --role "$cleanup_role_id" \
                        --scope "/subscriptions/$SUBSCRIPTION_ID" \
                        --query "[]" -o json 2>/dev/null); then
                        
                        if [ "$assignments" != "[]" ] && [ -n "$assignments" ]; then
                            assignment_count=$(echo "$assignments" | jq length)
                            log_info "Found $assignment_count role assignment(s) to delete:" "${YELLOW}"
                            
                            # List each role assignment before deletion
                            echo "$assignments" | jq -r '.[] | "  • Assignment ID: \(.id)"' | while read -r assignment_info; do
                                log_info "$assignment_info" "${YELLOW}"
                            done

                            # Delete each role assignment
                            echo "$assignments" | jq -r '.[].id' | while read -r assignment_id; do
                                if [ -n "$assignment_id" ]; then
                                    log_info "Deleting role assignment: $assignment_id" "${YELLOW}"
                                    if az role assignment delete --ids "$assignment_id" >/dev/null 2>&1; then
                                        if [ "$is_interrupt" = true ]; then
                                            log_info "✅  Role assignment deleted successfully" "${GREEN}"
                                        else
                                            log_info "Role assignment deleted successfully" "${YELLOW}"
                                        fi
                                    else
                                        log_warning "Failed to delete role assignment: $assignment_id"
                                    fi
                                fi
                            done
                        else
                            log_info "No role assignments found for this role - nothing to clean up" "${YELLOW}"
                        fi
                    else
                        log_warning "Could not check for role assignments"
                    fi
                fi
            else
                log_info "No custom role was created during this deployment - skipping role assignment cleanup" "${YELLOW}"
            fi
            
            # Step 2: Delete custom role (now that assignments are gone)
            log_info ""
            log_info "Checking if custom role was created during this deployment..." "${YELLOW}"
            if [ "$role_created_this_run" = true ] && [ -n "$role_definition_id" ]; then
                log_info "Custom role was created. Deleting custom role: $ROLE_NAME_WITH_NONCE" "${YELLOW}"
                if role_delete_result=$(az role definition delete --name "$ROLE_NAME_WITH_NONCE" --scope "/subscriptions/$SUBSCRIPTION_ID" 2>&1); then
                    if [ "$is_interrupt" = true ]; then
                        log_info "✅  Custom role deleted successfully" "${GREEN}"
                    else
                        log_info "Custom role deleted successfully" "${YELLOW}"
                    fi
                else
                    log_error "Custom role deletion failed: $role_delete_result"
                fi
            elif [ "$role_created_this_run" = true ] && [ -n "$ROLE_NAME_WITH_NONCE" ]; then
                # Fallback: check if role exists by name and delete it (handles race conditions)
                # Use role definition list to find the role by name pattern, then extract ID
                if role_list_result=$(az role definition list --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[?roleName=='$ROLE_NAME_WITH_NONCE']" 2>&1); then
                    if [ "$role_list_result" != "[]" ] && [ -n "$role_list_result" ]; then
                        role_definition_id=$(echo "$role_list_result" | jq -r '.[0].id // empty' 2>/dev/null)
                        if [ -n "$role_definition_id" ] && [ "$role_definition_id" != "null" ]; then
                            log_info "Custom role found. Deleting custom role: $ROLE_NAME_WITH_NONCE" "${YELLOW}"
                            log_info "Role ID: $role_definition_id" "${YELLOW}"
                            if delete_result=$(az role definition delete --name "$ROLE_NAME_WITH_NONCE" --scope "/subscriptions/$SUBSCRIPTION_ID" 2>&1); then
                                if [ "$is_interrupt" = true ]; then
                                    log_info "✅  Custom role deleted successfully" "${GREEN}"
                                else
                                    log_info "Custom role deleted successfully" "${YELLOW}"
                                fi
                            else
                                log_error "Custom role deletion failed: $delete_result"
                            fi
                        else
                            log_info "Custom role found in list but could not extract ID" "${YELLOW}"
                        fi
                    else
                        log_info "Custom role not found - skipping role cleanup" "${YELLOW}"
                    fi
                else
                    log_info "Failed to list custom roles. CLI result: $role_list_result" "${YELLOW}"
                    log_info "This might be due to Azure propagation delays or subscription context issues" "${YELLOW}"
                fi
            else
                log_info "No custom role was created during this deployment - skipping role cleanup" "${YELLOW}"
            fi
            
            # Always remove temporary role definition file after role cleanup attempt
            if [ -f custom-role.json ]; then
                rm -f custom-role.json
                log_info "Removed temporary role definition file" "${YELLOW}"
            fi
            
            # Step 3: Delete service principal
            log_info ""
            log_info "Checking if service principal was created during this deployment..." "${YELLOW}"
            if [ -n "$sp_object_id" ]; then
                log_info "Service principal was created. Deleting service principal for app: $APP_NAME_WITH_NONCE" "${YELLOW}"
                if sp_delete_result=$(az ad sp delete --id "$sp_object_id" 2>&1); then
                    if [ "$is_interrupt" = true ]; then
                        log_info "✅  Service principal deleted successfully" "${GREEN}"
                    else
                        log_info "Service principal deleted successfully" "${YELLOW}"
                    fi
                else
                    log_error "Service principal deletion failed: $sp_delete_result"
                fi
            else
                log_info "No service principal was created during this deployment - skipping service principal cleanup" "${YELLOW}"
            fi
            
            # Step 4: Delete Azure AD application
            log_info ""
            log_info "Checking if Azure AD application was created during this deployment..." "${YELLOW}"
            if [ -n "$app_id" ]; then
                log_info "Application was created. Deleting Azure AD application (and client secret): $APP_NAME_WITH_NONCE" "${YELLOW}"
                if app_delete_result=$(az ad app delete --id "$app_id" 2>&1); then
                    if [ "$is_interrupt" = true ]; then
                        log_info "✅  Azure AD application deleted successfully" "${GREEN}"
                    else
                        log_info "Azure AD application deleted successfully" "${YELLOW}"
                    fi
                else
                    log_error "Azure AD application deletion failed: $app_delete_result"
                fi
            else
                log_info "No Azure AD application was created during this deployment - skipping application cleanup" "${YELLOW}"
            fi
            
            # Send failure notification to backend only for interruptions (not normal script errors)
            if [ $exit_code -eq 130 ] || [ $exit_code -eq 143 ]; then
                log_info ""
                log_info "Notifying backend of script interruption..." "${YELLOW}"
                send_backend_status "Failed" "Script interrupted or terminated unexpectedly" 2>/dev/null || true
            fi
            
            # Show appropriate cleanup completion message
            if [ -n "$role_definition_id" ] || [ -n "$sp_object_id" ] || [ -n "$app_id" ]; then
                if [ "$is_interrupt" = true ]; then
                    log_info "✅  Successfully deleted the created resources. Check log file: $LOG_FILE" "${GREEN}"
                    log_info "Check log file: $LOG_FILE" "${NC}"
                else
                    log_info "Successfully deleted the created resources. Check log file: $LOG_FILE" "${YELLOW}"
                    log_info "Check log file: $LOG_FILE" "${NC}"
                fi
            else
                if [ "$is_interrupt" = true ]; then
                    log_info "✅  Cleanup completed (no Azure resources were created). Check log file: $LOG_FILE" "${GREEN}"
                    log_info "Check log file: $LOG_FILE" "${NC}"
                else
                    log_info "Cleanup completed (no Azure resources were created). Check log file: $LOG_FILE" "${YELLOW}"
                    log_info "Check log file: $LOG_FILE" "${NC}"
                fi
            fi
        fi
    else
        log_info ""
        log_info "Deployment completed successfully - keeping created resources. Check log file: $LOG_FILE" "${GREEN}"
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
    log_info "✅  Authenticated to Azure subscription: $current_sub" "${GREEN}"
    log_info ""
}

# Helper function to validate UUID format
validate_uuid() {
    local var_name="$1"
    local var_value="$2"
    
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
    
    if [[ ! "$var_value" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ "$var_value" =~ [[:space:]] ]]; then
        log_error "Invalid $var_name format: $var_value" >&2
        log_error "$var_name should only contain letters, numbers, hyphens, and underscores" >&2
        exit 1
    fi
}

# Helper function to validate URL format
validate_url() {
    local var_name="$1"
    local var_value="$2"
    
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
    validate_uuid "Subscription ID" "$SUBSCRIPTION_ID"
    
    # Position 1: Salt Host format
    validate_url "Salt host" "$SALT_HOST"
    
    # Position 2: Bearer token (no format validation needed)
    
    # Position 3: Installation ID (UUID format)
    validate_uuid "Installation ID" "$INSTALLATION_ID"
    
    # Position 4: Attempt ID (UUID format)
    validate_uuid "Attempt ID" "$ATTEMPT_ID"
    
    # Position 5: App name (alphanumeric, hyphens, underscores)
    validate_name "App name" "$APP_NAME"
    
    # Position 6: Role name (alphanumeric, hyphens, underscores)
    validate_name "Role name" "$ROLE_NAME"
    
    # Position 7: Created by (no validation needed - has default)
    
    log_info "✅  All input parameters validated" "${GREEN}"
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
    
    # Skip if Salt host or token not provided
    if [ -z "$SALT_HOST" ] || [ -z "$BEARER_TOKEN" ]; then
        log_warning "Skipping backend status update - Salt Host or Bearer Token not provided"
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

    # Construct the full URL with endpoint
    full_url="${SALT_HOST}/${ENDPOINT}"
    
    if response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        -d "$backend_payload" \
        "$full_url" 2>&1); then

        http_code=$(echo "$response" | tail -n 1)
        response_body=$(echo "$response" | sed '$d')

        if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
            log_info "✅  Successfully sent status '$deployment_status' to backend (HTTP $http_code)" "${GREEN}"
            if [ -n "$response_body" ]; then
                log_info "Backend response: $response_body"
                log_info ""
            fi
            return 0
        else
            log_warning "Backend webhook returned HTTP $http_code"
            log_warning "Response: $response_body"
            log_info ""
            return 1
        fi
    else
        log_warning "Failed to send status to backend webhook"
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
            log_info "Service principal is ready for authentication" "${GREEN}"
            log_info ""
            az logout >/dev/null 2>&1
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_info "Service principal not ready yet, waiting 30 seconds..." "${YELLOW}"
            sleep 30
        fi
        ((attempt++))
    done
    
    log_error "Service principal authentication failed after $max_attempts attempts"
    return 1
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

# Parse command line arguments first (before any logging or initialization)
AUTO_APPROVE=false

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required parameters:"
    echo "  --subscription-id=<id>     Azure subscription ID"
    echo "  --salt-host=<url>          Salt Host URL for status updates"
    echo "  --bearer-token=<token>     Authentication bearer token"
    echo "  --installation-id=<id>     Installation identifier"
    echo "  --attempt-id=<id>          Attempt identifier"
    echo ""
    echo "Optional parameters:"
    echo "  --app-name=<name>          Application name (default: SaltAppServicePrincipal)"
    echo "  --role-name=<name>         Custom role name (default: SaltCustomAppRole)"
    echo "  --created-by=\"<name>\"      The name of the person who executed this deployment script (use quotes for names that contain spaces, default: Salt Security)"
    echo "  --auto-approve             Skip confirmation prompts"
    echo "  --help                     Show this help message"
    echo ""
    echo "Notes:"
    echo "  • APP_NAME and ROLE_NAME can be provided interactively if not specified as flags"
    echo "  • Values containing spaces must be quoted (e.g., --created-by=\"John Doe\")"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --subscription-id=*)
            SUBSCRIPTION_ID="${1#*=}"
            shift
            ;;
        --salt-host=*)
            SALT_HOST="${1#*=}"
            shift
            ;;
        --bearer-token=*)
            BEARER_TOKEN="${1#*=}"
            shift
            ;;
        --installation-id=*)
            INSTALLATION_ID="${1#*=}"
            shift
            ;;
        --attempt-id=*)
            ATTEMPT_ID="${1#*=}"
            shift
            ;;
        --app-name=*)
            APP_NAME="${1#*=}"
            shift
            ;;
        --role-name=*)
            ROLE_NAME="${1#*=}"
            shift
            ;;
        --created-by=*)
            CREATED_BY="${1#*=}"
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Log script start (after argument parsing)
log_info ""
log_info "Azure Deployment Script starting..." "${GREEN}${BOLD}"
log_info "Log file: $LOG_FILE" "${CYAN}"
log_info ""

# Check dependencies before proceeding
check_dependencies

# Validate that all required parameters are provided
missing_params=()
if [ -z "$SUBSCRIPTION_ID" ]; then
    missing_params+=("--subscription-id")
fi
if [ -z "$SALT_HOST" ]; then
    missing_params+=("--salt-host")
fi
if [ -z "$BEARER_TOKEN" ]; then
    missing_params+=("--bearer-token")
fi
if [ -z "$INSTALLATION_ID" ]; then
    missing_params+=("--installation-id")
fi
if [ -z "$ATTEMPT_ID" ]; then
    missing_params+=("--attempt-id")
fi

if [ ${#missing_params[@]} -gt 0 ]; then
    log_error "Missing required parameters: ${missing_params[*]}" >&2
    show_help
    exit 1
fi


# Interactive prompts for APP_NAME and ROLE_NAME if not provided as flags
if [ -z "$APP_NAME" ]; then
    default_app_name="SaltAppServicePrincipal"
    echo -n "Enter Application Name (If none is provided, the following default will be used: $default_app_name): "
    read user_app_name
    APP_NAME="${user_app_name:-$default_app_name}"
fi

if [ -z "$ROLE_NAME" ]; then
    default_role_name="SaltCustomAppRole"
    echo -n "Enter Custom Role Name (If none is provided, the following default will be used: $default_role_name): "
    read user_role_name
    ROLE_NAME="${user_role_name:-$default_role_name}"
fi

# Set default value for CREATED_BY if not provided
CREATED_BY="${CREATED_BY:-Salt Security}"

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

# Set up signal handling for cleanup
trap cleanup EXIT
trap 'echo -e "\n${RED}${BOLD}Received interrupt signal, cleaning up...${NC}"; exit 130' INT TERM

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

# Track what resources were actually created during this script execution
role_created_this_run=false

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
if ! send_backend_status "Initiated" ""; then
    handle_error "Failed to notify backend of deployment initiation"
fi

# 1. Create Azure AD Application
if [ "$error_occurred" = false ]; then
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    AZURE AD APPLICATION SETUP" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
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
                log_info "✅  Application tagged successfully" "${GREEN}"
                log_info ""
            else
                log_warning "Failed to tag application (non-critical)"
                log_info ""
            fi
        else
            handle_error "Failed to parse application creation result: $app_result"
        fi
    else
        handle_error "Failed to create Azure AD application: $app_result"
    fi
fi

# 2. Create client secret
if [ "$error_occurred" = false ]; then
    log_info "Creating client secret..." "${CYAN}${BOLD}"
    if secret_result=$(az ad app credential reset --id "$app_id" --years 2 2>&1); then
        # Extract JSON part (skip any WARNING lines)
        json_part=$(echo "$secret_result" | sed -n '/^{/,$p')
        if echo "$json_part" | jq . >/dev/null 2>&1; then
            client_secret=$(echo "$json_part" | jq -r '.password')
            log_info "✅  Client secret created successfully" "${GREEN}"
        else
            handle_error "Failed to parse client secret result: $secret_result"
        fi
    else
        handle_error "Failed to create client secret: $secret_result"
    fi
fi

# 3. Create service principal
if [ "$error_occurred" = false ]; then
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    SERVICE PRINCIPAL CREATION" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
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
            log_info "✅  Service principal created successfully - Object ID: $sp_object_id" "${GREEN}"
            
            # Tag the service principal
            log_info "Tagging service principal with: $resource_tag" "${CYAN}"
            if az ad sp update --id "$sp_object_id" --set tags="[\"$resource_tag\"]" >/dev/null 2>&1; then
                log_info "✅  Service principal tagged successfully" "${GREEN}"
                log_info ""
            else
                log_warning "Failed to tag service principal (non-critical)"
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

# 5. Create custom role
if [ "$error_occurred" = false ]; then
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    PERMISSION CONFIGURATION" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
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
                role_created_this_run=true
                log_info "✅  Custom role created - Role ID: $role_definition_id" "${GREEN}"
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
        if error_output=$(az role assignment create \
          --assignee "$sp_object_id" \
          --role "$role_definition_id" \
          --scope "/subscriptions/$SUBSCRIPTION_ID" 2>&1); then
            log_info "✅  Role assignment created" "${GREEN}"
            log_info ""
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_info "Role assignment failed, retrying in 10 seconds... (attempt $retry_count/$max_retries)" "${YELLOW}"
                sleep 10
            else
                handle_error "Failed to create role assignment after $max_retries attempts"
                handle_error "Azure error: $error_output"
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
    if ! send_backend_status "Failed" "$error_message"; then
        error_message="$error_message (also failed to notify backend with status=Failed)"
    fi
else
    # Verify service principal is ready for authentication (if all resources created successfully)
    if [ -n "$app_id" ] && [ -n "$client_secret" ] && [ -n "$tenant_id" ]; then
        if ! verify_sp_ready; then
            handle_error "Service principal verification failed"
            if ! send_backend_status "Failed" "$error_message"; then
                error_message="$error_message (also failed to notify backend with status=Failed)"
            fi
        elif [ -n "$sp_object_id" ]; then
            if ! send_backend_status "Succeeded" ""; then
                handle_error "Deployment succeeded but failed to notify backend with status=Succeeded"
            fi
        else
            if ! send_backend_status "Unknown" "Deployment completed but some resources may not have been created properly"; then
                handle_error "Deployment status unknown and failed to notify backend"
            fi
        fi
    else
        if ! send_backend_status "Unknown" "Deployment completed but some resources may not have been created properly"; then
            handle_error "Deployment status unknown and failed to notify backend"
        fi
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
    log_info "✅  Script completed successfully. Log file: $LOG_FILE" "${GREEN}"
fi

# Exit with error code if deployment failed
if [ "$error_occurred" = true ]; then
    exit 1
fi
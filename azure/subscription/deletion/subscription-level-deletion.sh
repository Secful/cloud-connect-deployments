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
ENDPOINT="v1/cloud-connect/organizations/accounts/azure"

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

# Logging system - INFO, WARNING, ERROR levels only

# Generate unique nonce for resource names and log file (last 8 characters of UUID)
# Note: In deletion script, nonce is provided as parameter, but we keep same log file format
LOG_TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="" # Will be set after nonce parameter is validated

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local color="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file if it exists
    if [ -n "$LOG_FILE" ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
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
    for cmd in az jq curl; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' not found" >&2
            log_error "Please install $cmd and try again" >&2
            exit 1
        fi
    done
    log_info "✅ All dependencies found" "${GREEN}"
    log_info ""
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
    
    if [[ ! "$var_value" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        log_error "Invalid $var_name format: $var_value" >&2
        log_error "Expected UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
        exit 1
    fi
}

# Helper function to validate nonce format (8 character hex string)
validate_nonce() {
    local nonce="$1"
    
    if [[ ! "$nonce" =~ ^[0-9a-f]{8}$ ]]; then
        log_error "Invalid nonce format: $nonce" >&2
        log_error "Expected 8-character hexadecimal string (e.g., 'a1b2c3d4')" >&2
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
    
    # Validate subscription ID format (UUID)
    validate_uuid "Subscription ID" "$SUBSCRIPTION_ID"
    
    # Validate nonce format
    validate_nonce "$NONCE"
    
    # Validate Salt Host format (if provided)
    if [ -n "$SALT_HOST" ]; then
        validate_url "Salt Host" "$SALT_HOST"
    fi
    
    log_info "✅ All input parameters validated" "${GREEN}"
    log_info ""
}

# Function to handle errors
handle_error() {
    local error_message="$1"
    log_error "$error_message" >&2
    log_info ""
}

# Function to send deletion status to backend
send_backend_deletion() {
    local deletion_status="$1"
    local error_message="$2"
    
    # Skip if Salt host or token not provided
    if [ -z "$SALT_HOST" ] || [ -z "$BEARER_TOKEN" ]; then
        log_warning "Skipping backend deletion notification - Salt host or Bearer Token not provided"
        return 0
    fi
    
    log_info "Sending deletion notification to backend: $deletion_status" "${CYAN}${BOLD}"
    
    # Construct the full URL with endpoint and subscription ID suffix
    full_url="${SALT_HOST}/${ENDPOINT}/${SUBSCRIPTION_ID}"
    
    # Send DELETE request to backend (no body required)
    if response=$(curl -s -w "\\n%{http_code}" -X DELETE \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        "$full_url" 2>&1); then

        http_code=$(echo "$response" | tail -n 1)
        response_body=$(echo "$response" | sed '$d')

        if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
            log_info "✅ Successfully sent deletion request to backend (HTTP $http_code)" "${GREEN}"
            if [ -n "$response_body" ]; then
                log_info "Backend response: $response_body"
            fi
            log_info ""
            return 0
        else
            log_warning "Backend endpoint returned HTTP $http_code"
            if [ -n "$response_body" ]; then
                log_warning "Response: $response_body"
            fi
            log_info ""
            return 1
        fi
    else
        log_warning "Failed to send deletion request to backend endpoint"
        log_info ""
        return 1
    fi
}

# Function to discover resources by nonce
discover_resources() {
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    RESOURCE DISCOVERY" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
    
    log_info "Discovering resources with nonce: $NONCE" "${CYAN}${BOLD}"
    
    # Initialize resource tracking variables
    found_app_id=""
    found_app_name=""
    found_sp_object_id=""
    found_role_id=""
    found_role_name=""
    found_subscription_id=""
    
    # Get current subscription ID and verify it matches our target
    found_subscription_id=$(az account show --query id -o tsv 2>/dev/null)
    if [ -z "$found_subscription_id" ]; then
        handle_error "Failed to get current subscription ID"
        return 1
    fi
    
    log_info "Current subscription: $found_subscription_id" "${GREEN}"

    # Verify we're working in the correct subscription
    if [ "$found_subscription_id" != "$SUBSCRIPTION_ID" ]; then
        handle_error "Current subscription ($found_subscription_id) does not match target subscription ($SUBSCRIPTION_ID)"
        log_error "This should not happen as check_azure_auth() sets the subscription context"
        return 1
    fi


    # 1. Search for Azure AD Applications with nonce suffix
    log_info ""
    log_info "Searching for Azure AD applications with nonce suffix..." "${CYAN}"
    
    if apps_json=$(az ad app list --query "[?contains(displayName, '-$NONCE')]" 2>/dev/null); then
        if [ "$apps_json" != "[]" ] && [ -n "$apps_json" ]; then
            # Get the first matching app (there should only be one)
            found_app_id=$(echo "$apps_json" | jq -r '.[0].appId // empty')
            found_app_name=$(echo "$apps_json" | jq -r '.[0].displayName // empty')
            
            if [ -n "$found_app_id" ] && [ "$found_app_id" != "null" ]; then
                log_info "✅ Found Azure AD Application: $found_app_name (ID: $found_app_id)" "${GREEN}"
                
                # Verify it has the correct tag (if possible - tags might not be searchable)
                expected_tag="CreatedBySalt-${NONCE}"
                if app_details=$(az ad app show --id "$found_app_id" --query "tags" -o json 2>/dev/null); then
                    if echo "$app_details" | jq -e --arg tag "$expected_tag" 'index($tag)' >/dev/null 2>&1; then
                        log_info "   ✅ Confirmed: Application has expected tag '$expected_tag'" "${GREEN}"
                    else
                        log_warning "   Warning: Application does not have expected tag '$expected_tag'"
                        log_warning "   This might not be a Salt-created resource. Proceed with caution."
                    fi
                fi
                
                # 2. Find associated Service Principal
                log_info ""
                log_info "🔍 Searching for associated service principal..." "${CYAN}"
                if sp_json=$(az ad sp show --id "$found_app_id" --query "{id: id, appId: appId}" 2>/dev/null); then
                    found_sp_object_id=$(echo "$sp_json" | jq -r '.id // empty')
                    if [ -n "$found_sp_object_id" ] && [ "$found_sp_object_id" != "null" ]; then
                        log_info "✅ Found Service Principal: Object ID $found_sp_object_id" "${GREEN}"
                    fi
                else
                    log_warning "   No service principal found for application $found_app_id"
                fi
            else
                log_warning "   Application found but could not extract App ID"
            fi
        else
            log_warning "   No Azure AD applications found with nonce suffix '-$NONCE'"
        fi
    else
        log_error "Failed to search for Azure AD applications"
        return 1
    fi
    
    # 3. Search for Custom Role with nonce suffix
    log_info ""
    log_info "🔍 Searching for custom roles with nonce suffix..." "${CYAN}"
    
    if roles_json=$(az role definition list --scope "/subscriptions/$found_subscription_id" --query "[?contains(roleName, '-$NONCE')]" 2>/dev/null); then
        if [ "$roles_json" != "[]" ] && [ -n "$roles_json" ]; then
            # Get the first matching role (there should only be one)
            found_role_id=$(echo "$roles_json" | jq -r '.[0].id // empty')
            found_role_name=$(echo "$roles_json" | jq -r '.[0].roleName // empty')
            
            if [ -n "$found_role_id" ] && [ "$found_role_id" != "null" ]; then
                log_info "✅ Found Custom Role: $found_role_name (ID: $found_role_id)" "${GREEN}"
            else
                log_warning "   Role found but could not extract Role ID"
            fi
        else
            log_warning "   No custom roles found with nonce suffix '-$NONCE'"
        fi
    else
        log_error "Failed to search for custom roles"
        return 1
    fi
    
    # 4. Summary of discovered resources - show what will be deleted
    log_info ""
    log_info "Resources to be deleted:" "${CYAN}${BOLD}"
    
    resources_to_delete=0
    
    if [ -n "$found_app_id" ]; then
        log_info "   Azure AD Application: $found_app_name ($found_app_id)" "${RED}"
        resources_to_delete=$((resources_to_delete + 1))
    fi
    
    if [ -n "$found_sp_object_id" ]; then
        log_info "   Service Principal: $found_sp_object_id" "${RED}"
        resources_to_delete=$((resources_to_delete + 1))
    fi
    
    if [ -n "$found_role_id" ]; then
        log_info "   Custom Role: $found_role_name ($found_role_id)" "${RED}"
        resources_to_delete=$((resources_to_delete + 1))
    fi
    
    # Show what was not found (won't be deleted)
    if [ -z "$found_app_id" ]; then
        log_info "Azure AD Application: Not found (nothing to delete)" "${YELLOW}"
    fi
    
    if [ -z "$found_sp_object_id" ]; then
        log_info "Service Principal: Not found (nothing to delete)" "${YELLOW}"
    fi
    
    if [ -z "$found_role_id" ]; then
        log_info "Custom Role: Not found (nothing to delete)" "${YELLOW}"
    fi
    
    # Show total count
    log_info ""
    log_info "Total resources to be deleted: $resources_to_delete" "${MAGENTA}${BOLD}"
    
    # Check if any resources were found
    if [ "$resources_to_delete" -eq 0 ]; then
        log_warning ""
        log_warning "No resources found with nonce '$NONCE'"
        log_warning "Either the resources have already been deleted, or the nonce is incorrect."
        return 1
    fi
    
    log_info ""
    return 0
}

# Function to delete discovered resources in proper order
delete_resources() {
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    RESOURCE DELETION" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
    
    local deletion_errors=false
    
    log_info "Deleting resources in proper order to avoid dependency issues..." "${CYAN}${BOLD}"
    log_info ""
    
    # Step 1: Delete role assignments (if any exist)
    # Note: Role assignments are automatically deleted when the role definition is deleted,
    # but we'll check for any explicit assignments to be thorough
    if [ -n "$found_sp_object_id" ] && [ -n "$found_role_id" ]; then
        log_info "🗑️ Checking for role assignments to delete..." "${CYAN}"
        
        # Get role assignments for the service principal with the custom role
        if assignments=$(az role assignment list \
            --assignee "$found_sp_object_id" \
            --role "$found_role_id" \
            --scope "/subscriptions/$found_subscription_id" \
            --query "[].{id:id}" -o json 2>/dev/null); then
            
            if [ "$assignments" != "[]" ] && [ -n "$assignments" ]; then
                assignment_count=$(echo "$assignments" | jq length)
                log_info "Found $assignment_count role assignment(s) to delete" "${YELLOW}"
                
                # Delete each role assignment
                echo "$assignments" | jq -r '.[].id' | while read -r assignment_id; do
                    if [ -n "$assignment_id" ]; then
                        log_info "   Deleting role assignment: $assignment_id" "${YELLOW}"
                        if az role assignment delete --ids "$assignment_id" >/dev/null 2>&1; then
                            log_info "   ✅ Role assignment deleted successfully" "${GREEN}"
                        else
                            log_warning "   Failed to delete role assignment: $assignment_id"
                            deletion_errors=true
                        fi
                    fi
                done
            else
                log_info "No explicit role assignments found (this is normal)" "${GREEN}"
            fi
        else
            log_warning "Could not check for role assignments"
        fi
        log_info ""
    fi
    
    # Step 2: Delete custom role definition
    if [ -n "$found_role_id" ]; then
        log_info "🗑️ Deleting custom role definition..." "${CYAN}"
        log_info "   Role: $found_role_name" "${YELLOW}"
        log_info "   ID: $found_role_id" "${YELLOW}"
        
        if az role definition delete --name "$found_role_name" --scope "/subscriptions/$found_subscription_id" >/dev/null 2>&1; then
            log_info "   ✅ Custom role definition deleted successfully" "${GREEN}"
        else
            log_error "   Failed to delete custom role definition"
            deletion_errors=true
        fi
        log_info ""
    fi
    
    # Step 3: Delete service principal
    if [ -n "$found_sp_object_id" ]; then
        log_info "🗑️ Deleting service principal..." "${CYAN}"
        log_info "   Object ID: $found_sp_object_id" "${YELLOW}"
        
        if az ad sp delete --id "$found_sp_object_id" >/dev/null 2>&1; then
            log_info "   ✅ Service principal deleted successfully" "${GREEN}"
        else
            log_error "   Failed to delete service principal"
            deletion_errors=true
        fi
        log_info ""
    fi
    
    # Step 4: Delete Azure AD application (this also deletes client secrets)
    if [ -n "$found_app_id" ]; then
        log_info "🗑️ Deleting Azure AD application..." "${CYAN}"
        log_info "   Application: $found_app_name" "${YELLOW}"
        log_info "   ID: $found_app_id" "${YELLOW}"
        
        if az ad app delete --id "$found_app_id" >/dev/null 2>&1; then
            log_info "   ✅ Azure AD application deleted successfully" "${GREEN}"
            log_info "   (Client secrets were automatically deleted with the application)" "${GREEN}"
        else
            log_error "   Failed to delete Azure AD application"
            deletion_errors=true
        fi
        log_info ""
    fi
    
    # Return status based on whether any errors occurred
    if [ "$deletion_errors" = true ]; then
        log_error "Some resources could not be deleted. Check the log for details."
        return 1
    else
        log_info "✅ All discovered resources deleted successfully" "${GREEN}"
        return 0
    fi
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

# Parse command line arguments first (before any logging or initialization)
AUTO_APPROVE=false
DRY_RUN=false

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required parameters:"
    echo "  --subscription-id=<id>     Azure subscription ID"
    echo "  --nonce=<nonce>            8-character hexadecimal nonce from deployment"
    echo "  --salt-host=<url>          Salt Host URL for status updates"
    echo "  --bearer-token=<token>     Authentication bearer token"
    echo ""
    echo "Optional parameters:"
    echo "  --deleted-by=<name>        Deleted by identifier (default: Salt Security)"
    echo "  --auto-approve             Skip confirmation prompts"
    echo "  --dry-run                  Identify resources without deleting them"
    echo "  --help                     Show this help message"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --subscription-id=*)
            SUBSCRIPTION_ID="${1#*=}"
            shift
            ;;
        --nonce=*)
            NONCE="${1#*=}"
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
        --deleted-by=*)
            DELETED_BY="${1#*=}"
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Validate that all required parameters are provided
missing_params=()
if [ -z "$SUBSCRIPTION_ID" ]; then
    missing_params+=("--subscription-id")
fi
if [ -z "$NONCE" ]; then
    missing_params+=("--nonce")
fi
if [ -z "$SALT_HOST" ]; then
    missing_params+=("--salt-host")
fi
if [ -z "$BEARER_TOKEN" ]; then
    missing_params+=("--bearer-token")
fi

if [ ${#missing_params[@]} -gt 0 ]; then
    log_error "Error: Missing required parameters: ${missing_params[*]}" >&2
    show_help
    exit 1
fi

# Set default values for DELETED_BY if not provided
DELETED_BY="${DELETED_BY:-Salt Security}"

# Create log file with nonce now that we have it
LOG_FILE="subscription-level-deletion-${NONCE}-${LOG_TIMESTAMP}.log"
# Initialize log file
echo "=== Subscription Level Deletion Script Log ===" > "$LOG_FILE"
echo "Timestamp: $(date)" >> "$LOG_FILE"
echo "Nonce: $NONCE" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Now that logging is set up, check dependencies and log everything
check_dependencies

log_info ""
log_info "╔══════════════════════════════════════════════════════════════════════════════════╗" "${BLUE}${BOLD}"
log_info "║                          AZURE RESOURCE DELETION                                 ║" "${BLUE}${BOLD}"
log_info "╚══════════════════════════════════════════════════════════════════════════════════╝" "${BLUE}${BOLD}"
log_info ""
log_info "This script will identify and delete Azure resources created by deployment with nonce: ${NONCE}" "${CYAN}"
log_info ""
log_info "Resources to be deleted:" "${YELLOW}"
log_info "• Role assignments associated with the deployment" "${YELLOW}"
log_info "• Custom role definition" "${YELLOW}"
log_info "• Service principal" "${YELLOW}"
log_info "• Azure AD application" "${YELLOW}"
log_info ""

if [ "$DRY_RUN" = true ]; then
    log_info "DRY RUN MODE - No resources will actually be deleted" "${MAGENTA}${BOLD}"
    log_info ""
fi

log_info "Target Nonce: $NONCE" "${MAGENTA}${BOLD}"
log_info ""
log_info "Ready to begin deletion..." "${CYAN}${BOLD}"
log_info ""

# Check Azure CLI authentication
check_azure_auth

# Validate input parameters
validate_inputs

if [ "$AUTO_APPROVE" = true ]; then
    log_info "Auto-approve mode enabled - Starting Azure resource deletion..." "${GREEN}${BOLD}"
    log_info ""
elif [ "$DRY_RUN" = true ]; then
    log_info "Dry-run mode - Proceeding to identify resources..." "${GREEN}${BOLD}"
    log_info ""
else
    echo -e "${YELLOW}Do you want to proceed with the deletion? (y/n): ${NC}\\c"
    read -r response
    log_info ""

    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Starting Azure resource deletion..." "${GREEN}${BOLD}"
        log_info ""
    else
        log_info "Deletion cancelled by user." "${YELLOW}"
        exit 0
    fi
fi

# Discover resources by nonce
if ! discover_resources; then
    log_error "Resource discovery failed. Exiting."
    exit 1
fi

# If dry-run mode, exit after discovery
if [ "$DRY_RUN" = true ]; then
    log_info ""
    log_info "DRY RUN completed - No resources were deleted" "${GREEN}${BOLD}"
    log_info "Log file: $LOG_FILE" "${GREEN}"
    exit 0
fi

# Delete discovered resources
deletion_success=true
if ! delete_resources; then
    deletion_success=false
    log_error "Resource deletion completed with errors."
else
    log_info "✅ All resources deleted successfully"
fi

# 7. Salt Security Integration - Final status and verification
log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "         SALT SECURITY INTEGRATION - DELETION STATUS" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

if [ "$deletion_success" = false ]; then
    send_backend_deletion "Failed" "Some resources could not be deleted"
else
    send_backend_deletion "Succeeded" ""
fi

# Final summary
log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "                     DELETION SUMMARY" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

if [ "$deletion_success" = true ]; then
    log_info "=== DELETION COMPLETED SUCCESSFULLY ===" "${GREEN}${BOLD}"
    log_info "All discovered resources with nonce '$NONCE' have been deleted." "${GREEN}"
else
    log_error "=== DELETION COMPLETED WITH ERRORS ==="
    log_error "Some resources could not be deleted. Check the log for details."
fi

log_info ""
log_info "Log file: $LOG_FILE" "${CYAN}"
log_info ""

# Exit with error code if deletion failed
if [ "$deletion_success" = false ]; then
    exit 1
fi
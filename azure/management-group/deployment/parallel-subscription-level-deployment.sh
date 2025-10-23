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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBSCRIPTION_SCRIPT="${SCRIPT_DIR}/../../subscription/deployment/subscription-level-deployment.sh"

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

# Generate unique nonce for this management group deployment
full_uuid=$(uuidgen | tr '[:upper:]' '[:lower:]')
full_nonce=${full_uuid##*-}
nonce=${full_nonce: -8}

# Create log file with timestamp and nonce
LOG_TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="management-group-deployment-${nonce}-${LOG_TIMESTAMP}.log"
JOBLOG_FILE="mg-deployment-${nonce}-jobs.log"

# Initialize log file
echo "=== Management Group Deployment Script Log ===" > "$LOG_FILE"
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
    local missing_deps=()
    
    for cmd in az jq curl uuidgen parallel; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}" >&2
        log_error "Please install the missing dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "parallel")
                    log_error "  - Install GNU parallel: apt-get install parallel (Ubuntu/Debian) or brew install parallel (macOS)" >&2
                    ;;
                "az")
                    log_error "  - Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" >&2
                    ;;
                *)
                    log_error "  - Install $dep and try again" >&2
                    ;;
            esac
        done
        exit 1
    fi
    
    log_info "✅  All dependencies found" "${GREEN}"
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
    
    # Get current account info
    current_account=$(az account show --query name -o tsv 2>/dev/null)
    current_tenant=$(az account show --query tenantId -o tsv 2>/dev/null)
    log_info "✅  Authenticated to Azure tenant: $current_tenant" "${GREEN}"
    log_info "Current default subscription: $current_account" "${GREEN}"
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

# Helper function to validate management group ID format
validate_management_group_id() {
    local mg_id="$1"
    
    if [[ -z "$mg_id" ]] || [[ "$mg_id" =~ [[:space:]] ]]; then
        log_error "Invalid management group ID format: '$mg_id'" >&2
        log_error "Management group ID cannot be empty or contain spaces" >&2
        exit 1
    fi
}

# Function to validate input parameters
validate_inputs() {
    log_info "Validating input parameters..." "${CYAN}"
    
    # Validate management group IDs
    for mg_id in "${MANAGEMENT_GROUP_IDS[@]}"; do
        validate_management_group_id "$mg_id"
    done
    
    # Validate Salt Host format
    validate_url "Salt host" "$SALT_HOST"
    
    # Validate installation and attempt IDs (UUID format)
    validate_uuid "Installation ID" "$INSTALLATION_ID"
    validate_uuid "Attempt ID" "$ATTEMPT_ID"
    
    # Validate parallel jobs count
    if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [ "$PARALLEL_JOBS" -lt 1 ] || [ "$PARALLEL_JOBS" -gt 50 ]; then
        log_error "Invalid parallel jobs count: $PARALLEL_JOBS" >&2
        log_error "Parallel jobs must be a number between 1 and 50" >&2
        exit 1
    fi
    
    log_info "✅  All input parameters validated" "${GREEN}"
    log_info ""
}

# Function to discover subscriptions in management groups
discover_subscriptions() {
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    SUBSCRIPTION DISCOVERY" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
    
    local all_subscriptions=()
    local discovery_errors=false
    
    for mg_id in "${MANAGEMENT_GROUP_IDS[@]}"; do
        log_info "Discovering subscriptions in management group: $mg_id" "${CYAN}${BOLD}"
        
        # Get subscriptions from management group
        if subscriptions_json=$(az account management-group subscription list \
            --name "$mg_id" \
            --query "[].subscriptionId" -o json 2>/dev/null); then
            
            if [ "$subscriptions_json" != "[]" ] && [ -n "$subscriptions_json" ]; then
                # Parse subscription IDs
                while IFS= read -r subscription_id; do
                    if [ -n "$subscription_id" ] && [ "$subscription_id" != "null" ]; then
                        all_subscriptions+=("$subscription_id")
                        log_info "  Found subscription: $subscription_id" "${GREEN}"
                    fi
                done < <(echo "$subscriptions_json" | jq -r '.[]')
            else
                log_warning "No subscriptions found in management group: $mg_id"
            fi
        else
            log_error "Failed to access management group: $mg_id"
            log_error "Verify the management group exists and you have access"
            discovery_errors=true
        fi
        log_info ""
    done
    
    if [ "$discovery_errors" = true ]; then
        log_error "Errors occurred during subscription discovery"
        return 1
    fi
    
    if [ ${#all_subscriptions[@]} -eq 0 ]; then
        log_error "No subscriptions found in any of the specified management groups"
        return 1
    fi
    
    # Remove duplicates and store in global array
    DISCOVERED_SUBSCRIPTIONS=($(printf '%s\n' "${all_subscriptions[@]}" | sort -u))
    
    log_info "Discovery Summary:" "${CYAN}${BOLD}"
    log_info "Management Groups: ${#MANAGEMENT_GROUP_IDS[@]}" "${YELLOW}"
    log_info "Total Subscriptions Found: ${#DISCOVERED_SUBSCRIPTIONS[@]}" "${YELLOW}"
    log_info "Parallel Jobs: $PARALLEL_JOBS" "${YELLOW}"
    log_info ""
    
    # Show all discovered subscriptions
    log_info "Subscriptions to deploy:" "${CYAN}"
    for subscription_id in "${DISCOVERED_SUBSCRIPTIONS[@]}"; do
        log_info "  $subscription_id" "${YELLOW}"
    done
    log_info ""
    
    return 0
}

# Function to validate subscription access
validate_subscription_access() {
    log_info "Validating access to discovered subscriptions..." "${CYAN}${BOLD}"
    
    local accessible_subscriptions=()
    local access_errors=false
    
    for subscription_id in "${DISCOVERED_SUBSCRIPTIONS[@]}"; do
        if az account show --subscription "$subscription_id" &>/dev/null; then
            accessible_subscriptions+=("$subscription_id")
            log_info "  ✅  Access validated: $subscription_id" "${GREEN}"
        else
            log_warning "  ❌  No access to subscription: $subscription_id"
            access_errors=true
        fi
    done
    
    # Update the array with only accessible subscriptions
    DISCOVERED_SUBSCRIPTIONS=("${accessible_subscriptions[@]}")
    
    if [ ${#DISCOVERED_SUBSCRIPTIONS[@]} -eq 0 ]; then
        log_error "No accessible subscriptions found"
        return 1
    fi
    
    if [ "$access_errors" = true ]; then
        log_warning "Some subscriptions are not accessible and will be skipped"
    fi
    
    log_info ""
    log_info "Accessible subscriptions: ${#DISCOVERED_SUBSCRIPTIONS[@]}" "${GREEN}${BOLD}"
    log_info ""
    
    return 0
}

# Function to execute parallel deployment
execute_parallel_deployment() {
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    PARALLEL DEPLOYMENT EXECUTION" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
    
    log_info "Starting parallel deployment with GNU parallel..." "${CYAN}${BOLD}"
    log_info "Parallel jobs: $PARALLEL_JOBS" "${YELLOW}"
    log_info "Failure threshold: $FAIL_THRESHOLD" "${YELLOW}"
    log_info "Job log: $JOBLOG_FILE" "${YELLOW}"
    log_info ""
    
    # Verify subscription script exists
    if [ ! -f "$SUBSCRIPTION_SCRIPT" ]; then
        log_error "Subscription deployment script not found: $SUBSCRIPTION_SCRIPT"
        return 1
    fi
    
    if [ ! -x "$SUBSCRIPTION_SCRIPT" ]; then
        log_error "Subscription deployment script is not executable: $SUBSCRIPTION_SCRIPT"
        log_error "Run: chmod +x $SUBSCRIPTION_SCRIPT"
        return 1
    fi
    
    # Create joblog header if it doesn't exist
    if [ ! -f "$JOBLOG_FILE" ]; then
        echo "Seq,Host,Starttime,JobRuntime,Send,Receive,Exitval,Signal,Command" > "$JOBLOG_FILE"
    fi
    
    # Prepare parallel command
    local parallel_cmd="parallel"
    parallel_cmd="$parallel_cmd --jobs $PARALLEL_JOBS"
    parallel_cmd="$parallel_cmd --progress"
    parallel_cmd="$parallel_cmd --joblog $JOBLOG_FILE"
    parallel_cmd="$parallel_cmd --halt soon,fail=$FAIL_THRESHOLD"
    parallel_cmd="$parallel_cmd --load 80%"
    
    if [ "$DRY_RUN" = true ]; then
        parallel_cmd="$parallel_cmd --dry-run"
    fi
    
    # Execute parallel deployment
    printf '%s\n' "${DISCOVERED_SUBSCRIPTIONS[@]}" | \
        $parallel_cmd \
        "$SUBSCRIPTION_SCRIPT" \
        --subscription-id {} \
        --salt-host "$SALT_HOST" \
        --bearer-token "$BEARER_TOKEN" \
        --installation-id "$INSTALLATION_ID" \
        --attempt-id "$ATTEMPT_ID-{}" \
        --app-name "$APP_NAME" \
        --role-name "$ROLE_NAME" \
        --created-by "$CREATED_BY" \
        --auto-approve
    
    local parallel_exit_code=$?
    
    log_info ""
    log_info "Parallel execution completed with exit code: $parallel_exit_code" "${CYAN}${BOLD}"
    
    return $parallel_exit_code
}

# Function to analyze and report results
analyze_results() {
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "                    DEPLOYMENT RESULTS ANALYSIS" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
    
    if [ ! -f "$JOBLOG_FILE" ]; then
        log_error "Job log file not found: $JOBLOG_FILE"
        return 1
    fi
    
    # Skip header line and analyze results
    local total_jobs=0
    local successful_jobs=0
    local failed_jobs=0
    local failed_subscriptions=()
    
    while IFS=',' read -r seq host starttime jobruntime send receive exitval signal command; do
        # Skip header and empty lines
        if [ "$seq" = "Seq" ] || [ -z "$seq" ]; then
            continue
        fi
        
        total_jobs=$((total_jobs + 1))
        
        if [ "$exitval" = "0" ]; then
            successful_jobs=$((successful_jobs + 1))
        else
            failed_jobs=$((failed_jobs + 1))
            # Extract subscription ID from command
            subscription_id=$(echo "$command" | grep -o -- '--subscription-id [^ ]*' | cut -d' ' -f2)
            failed_subscriptions+=("$subscription_id")
        fi
    done < "$JOBLOG_FILE"
    
    # Report summary
    log_info "Deployment Summary:" "${CYAN}${BOLD}"
    log_info "Total Subscriptions: $total_jobs" "${YELLOW}"
    log_info "Successful Deployments: $successful_jobs" "${GREEN}"
    log_info "Failed Deployments: $failed_jobs" "${RED}"
    log_info ""
    
    if [ $failed_jobs -gt 0 ]; then
        log_warning "Failed Subscriptions:"
        for failed_sub in "${failed_subscriptions[@]}"; do
            log_warning "  $failed_sub" "${RED}"
        done
        log_info ""
    fi
    
    # Calculate success rate
    local success_rate=0
    if [ $total_jobs -gt 0 ]; then
        success_rate=$((successful_jobs * 100 / total_jobs))
    fi
    
    log_info "Success Rate: ${success_rate}%" "${CYAN}${BOLD}"
    
    if [ $failed_jobs -eq 0 ]; then
        log_info "✅  All deployments completed successfully!" "${GREEN}${BOLD}"
        return 0
    else
        log_error "❌  Some deployments failed. Check individual logs for details."
        return 1
    fi
}

# Function to send aggregated backend status
send_backend_status() {
    log_info ""
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info "         SALT SECURITY INTEGRATION - AGGREGATED STATUS" "${MAGENTA}${BOLD}"
    log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
    log_info ""
    
    # For management group deployments, we'll send individual notifications
    # as the current backend expects subscription-level notifications
    log_info "Individual subscription notifications are sent by subscription-level scripts" "${CYAN}"
    log_info "Management group orchestration completed" "${GREEN}${BOLD}"
    log_info ""
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

# Default values
AUTO_APPROVE=false
DRY_RUN=false
PARALLEL_JOBS=10
FAIL_THRESHOLD="20%"
MANAGEMENT_GROUP_IDS=()

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required parameters:"
    echo "  --management-group-ids=<id1,id2,...>  Comma-separated list of management group IDs"
    echo "  --salt-host=<url>                     Salt Host URL for status updates"
    echo "  --bearer-token=<token>                Authentication bearer token"
    echo "  --installation-id=<id>                Installation identifier"
    echo "  --attempt-id=<id>                     Attempt identifier"
    echo ""
    echo "Optional parameters:"
    echo "  --app-name=<name>                     Application name (default: SaltAppServicePrincipal)"
    echo "  --role-name=<name>                    Custom role name (default: SaltCustomAppRole)"
    echo "  --created-by=\"<name>\"                 The name of the person who executed this deployment"
    echo "  --parallel-jobs=<num>                 Number of parallel jobs (default: 10, max: 50)"
    echo "  --fail-threshold=<percent>            Failure threshold to halt execution (default: 20%)"
    echo "  --auto-approve                        Skip confirmation prompts"
    echo "  --dry-run                             Discover subscriptions and validate without deploying"
    echo "  --help                                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --management-group-ids=mg-prod,mg-dev --salt-host=https://api.saltsecurity.com --bearer-token=xyz..."
    echo "  $0 --management-group-ids=my-mg --parallel-jobs=5 --fail-threshold=10% --dry-run"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --management-group-ids=*)
            IFS=',' read -ra MANAGEMENT_GROUP_IDS <<< "${1#*=}"
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
        --parallel-jobs=*)
            PARALLEL_JOBS="${1#*=}"
            shift
            ;;
        --fail-threshold=*)
            FAIL_THRESHOLD="${1#*=}"
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
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set default values for optional parameters
APP_NAME="${APP_NAME:-SaltAppServicePrincipal}"
ROLE_NAME="${ROLE_NAME:-SaltCustomAppRole}"
CREATED_BY="${CREATED_BY:-Salt Security}"

# Log script start
log_info ""
log_info "Management Group Azure Deployment Script starting..." "${GREEN}${BOLD}"
log_info "Log file: $LOG_FILE" "${CYAN}"
log_info "Job log: $JOBLOG_FILE" "${CYAN}"
log_info "Nonce: $nonce" "${CYAN}"
log_info ""

# Check dependencies
check_dependencies

# Validate required parameters
missing_params=()
if [ ${#MANAGEMENT_GROUP_IDS[@]} -eq 0 ]; then
    missing_params+=("--management-group-ids")
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

# Check Azure authentication
check_azure_auth

# Validate inputs
validate_inputs

log_info ""
log_info "╔══════════════════════════════════════════════════════════════════════════════════╗" "${BLUE}${BOLD}"
log_info "║                     MANAGEMENT GROUP DEPLOYMENT SETUP                            ║" "${BLUE}${BOLD}"
log_info "╚══════════════════════════════════════════════════════════════════════════════════╝" "${BLUE}${BOLD}"
log_info ""
log_info "This script will deploy Azure authentication components across multiple subscriptions" "${CYAN}"
log_info "within the specified management groups using parallel execution." "${CYAN}"
log_info ""
log_info "Management Groups: ${MANAGEMENT_GROUP_IDS[*]}" "${MAGENTA}${BOLD}"
log_info "Parallel Jobs: $PARALLEL_JOBS" "${MAGENTA}${BOLD}"
log_info "Failure Threshold: $FAIL_THRESHOLD" "${MAGENTA}${BOLD}"

if [ "$DRY_RUN" = true ]; then
    log_info "DRY RUN MODE - No actual deployments will be performed" "${YELLOW}${BOLD}"
fi

log_info ""
log_info "Ready to begin discovery and deployment..." "${CYAN}${BOLD}"
log_info ""

# Discover subscriptions
if ! discover_subscriptions; then
    log_error "Subscription discovery failed. Check log file: $LOG_FILE"
    exit 1
fi

# Validate subscription access
if ! validate_subscription_access; then
    log_error "Subscription access validation failed. Check log file: $LOG_FILE"
    exit 1
fi

# Confirmation prompt
if [ "$AUTO_APPROVE" = true ]; then
    log_info "Auto-approve mode enabled - Starting parallel deployment..." "${GREEN}${BOLD}"
    log_info ""
elif [ "$DRY_RUN" = true ]; then
    log_info "Dry-run mode - No actual deployments will be performed" "${GREEN}${BOLD}"
    log_info ""
else
    echo -e "${YELLOW}Do you want to proceed with the deployment to ${#DISCOVERED_SUBSCRIPTIONS[@]} subscriptions? (y/n): ${NC}\c"
    read -r response
    log_info ""

    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Starting management group deployment..." "${GREEN}${BOLD}"
        log_info ""
    else
        log_info "Deployment cancelled by user." "${YELLOW}"
        exit 0
    fi
fi

# Execute parallel deployment
deployment_success=true
if ! execute_parallel_deployment; then
    deployment_success=false
fi

# Exit early if dry-run
if [ "$DRY_RUN" = true ]; then
    log_info ""
    log_info "DRY RUN completed - No actual deployments were performed" "${GREEN}${BOLD}"
    log_info "Check job log for details: $JOBLOG_FILE" "${GREEN}"
    log_info "Check master log: $LOG_FILE" "${GREEN}"
    exit 0
fi

# Analyze results
if ! analyze_results; then
    deployment_success=false
fi

# Send backend status (informational)
send_backend_status

# Final summary
log_info ""
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info "                     DEPLOYMENT SUMMARY" "${MAGENTA}${BOLD}"
log_info "══════════════════════════════════════════════════════════════" "${MAGENTA}${BOLD}"
log_info ""

if [ "$deployment_success" = true ]; then
    log_info "=== MANAGEMENT GROUP DEPLOYMENT COMPLETED SUCCESSFULLY ===" "${GREEN}${BOLD}"
    log_info "All subscriptions deployed successfully with nonce: $nonce" "${GREEN}"
    log_info ""
    log_info "✅  Script completed successfully." "${GREEN}"
else
    log_error "=== MANAGEMENT GROUP DEPLOYMENT COMPLETED WITH ERRORS ==="
    log_error "Some subscriptions failed to deploy. Check individual logs for details."
    log_error ""
fi

log_info "Master Log: $LOG_FILE" "${CYAN}"
log_info "Job Log: $JOBLOG_FILE" "${CYAN}"
log_info "Management Group Nonce: $nonce" "${CYAN}${BOLD}"
log_info ""

# Exit with appropriate code
if [ "$deployment_success" = false ]; then
    exit 1
fi
#!/bin/bash

# Cloud Foundry Opsman UAA Client Setup Script
# This script automates the process of adding a UAA client through Opsman

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Configuration
OPSMAN_URL=""  # Will be fetch from opsman SSH config file
BOSH_DIRECTOR_IP=""  # Will be auto-detected
CLIENT_NAME="hub-tas-collector"
CLIENT_SECRET=""  # Will be prompted if empty
SSH_CONFIG_PATH="" # Will be prompted if empty

# Opsman authentication variables
OPSMAN_USERNAME=""
OPSMAN_PASSWORD=""

# Operation mode - can be "bosh" or "opsman" or "both"
OPERATION_MODE="both"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are available
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v ssh &> /dev/null; then
        log_error "ssh command not found"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl command not found"
        exit 1
    fi
    
    if [ -z "$SSH_CONFIG_PATH" ]; then
        read -p "Enter Opsman SSH config file path: " SSH_CONFIG_PATH
    fi

    if [ ! -f "$SSH_CONFIG_PATH" ]; then
        log_error "SSH config file not found at: $SSH_CONFIG_PATH"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Function to get operation mode from user
get_operation_mode() {
    echo ""
    echo "Select operation mode:"
    echo "1) Add client to BOSH Director UAA only"
    echo "2) Add client to Opsman UAA only" 
    echo "3) Add client to both BOSH Director and Opsman UAA"
    
    read -p "Enter choice (1-3) [default: 3]: " choice
    
    case $choice in
        1)
            OPERATION_MODE="bosh"
            log_info "Selected: BOSH Director UAA only"
            ;;
        2)
            OPERATION_MODE="opsman"
            log_info "Selected: Opsman UAA only"
            ;;
        3|"")
            OPERATION_MODE="both"
            log_info "Selected: Both BOSH Director and Opsman UAA"
            ;;
        *)
            log_warn "Invalid choice, defaulting to both"
            OPERATION_MODE="both"
            ;;
    esac
}

# Function to get Opsman credentials
get_opsman_credentials() {
    log_info "Getting Opsman authentication credentials..."
    
    if [ -z "$OPSMAN_USERNAME" ]; then
        read -p "Enter Opsman username: " OPSMAN_USERNAME
    fi
    
    if [ -z "$OPSMAN_PASSWORD" ]; then
        read -s -p "Enter Opsman password: " OPSMAN_PASSWORD
        echo  # New line after hidden input
    fi
    
    if [ -z "$OPSMAN_USERNAME" ] || [ -z "$OPSMAN_PASSWORD" ]; then
        log_error "Both Opsman username and password are required"
        exit 1
    fi
}

validate_and_get_client_secret() {
    # Check if CLIENT_SECRET is empty or contains only whitespace
    if [ -z "$CLIENT_SECRET" ] || [[ "$CLIENT_SECRET" =~ ^[[:space:]]*$ ]]; then
        echo ""
        log_warn "Client secret is empty or not set"
        echo "Please enter the client secret for the UAA client '$CLIENT_NAME'."
        echo "This will be the password/secret used to authenticate the client."
        
        while true; do
            read -s -p "Client Secret: " CLIENT_SECRET
            echo  # New line after hidden input
            # Validate that the secret is not empty
            if [ -z "$CLIENT_SECRET" ] || [[ "$CLIENT_SECRET" =~ ^[[:space:]]*$ ]]; then
                log_error "Client secret cannot be empty. Please try again."
                continue
            else
                break
            fi
            
        done
        
        log_info "Client secret has been set"
    else
        log_info "Using provided client secret"
    fi
}

# Function to get Opsman authentication token
get_opsman_token() {
    log_info "Getting Opsman authentication token..."
    
    # Prompt for credentials if not set
    if [ -z "$OPSMAN_USERNAME" ]; then
        read -p "Enter Opsman username: " OPSMAN_USERNAME
    fi
    
    if [ -z "$OPSMAN_PASSWORD" ]; then
        read -s -p "Enter Opsman password: " OPSMAN_PASSWORD
        echo  # New line after hidden input
    fi
    
    # Get token via SSH to Opsman
    local token_output=$(execute_on_opsman "
        # Method 1: Using om CLI to get token
        if command -v om &> /dev/null; then
            om --target localhost --skip-ssl-validation --username '$OPSMAN_USERNAME' --password '$OPSMAN_PASSWORD' curl --path /uaa/oauth/token --request POST --data 'grant_type=password&username=$OPSMAN_USERNAME&password=$OPSMAN_PASSWORD' 2>/dev/null
        else
            # Method 2: Direct curl to get token
            curl -s -k -X POST 'https://localhost/uaa/oauth/token' \\
                -H 'Accept: application/json' \\
                -H 'Content-Type: application/x-www-form-urlencoded' \\
                -u 'opsman:' \\
                -d 'grant_type=password&username=$OPSMAN_USERNAME&password=$OPSMAN_PASSWORD' 2>/dev/null
        fi
    ")
    
    if [ -n "$token_output" ]; then
        # Extract access_token from JSON response
        OPSMAN_TOKEN=$(echo "$token_output" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$OPSMAN_TOKEN" ]; then
            log_info "Successfully obtained Opsman authentication token"
            return 0
        else
            log_warn "Could not extract token from response: $token_output"
        fi
    else
        log_warn "No response from Opsman token endpoint"
    fi
    
    log_error "Failed to obtain Opsman authentication token"
    return 1
}

# Function to get BOSH credentials and director IP from Opsman API
get_bosh_credentials_and_ip() {
    log_info "Retrieving BOSH credentials and director IP from Opsman API..."
    
    # Get authentication token first
    if ! get_opsman_token; then
        log_error "Cannot proceed without authentication token"
        exit 1
    fi
    
    # Get credentials via authenticated SSH command to Opsman API
    local creds_output=$(execute_on_opsman "
        # Get credentials from Opsman API using om CLI with auth
        if command -v om &> /dev/null; then
            om --target localhost --skip-ssl-validation --username '$OPSMAN_USERNAME' --password '$OPSMAN_PASSWORD' curl --path /api/v0/deployed/director/credentials/bosh_commandline_credentials 2>/dev/null
        else
            # Fallback using curl with authorization header
            curl -s -k -X GET 'https://localhost/api/v0/deployed/director/credentials/bosh_commandline_credentials' \\
                -H 'Authorization: Bearer $OPSMAN_TOKEN' \\
                -H 'Accept: application/json' 2>/dev/null
        fi
    ")
    
    if [ -n "$creds_output" ] && [[ "$creds_output" != *"errors"* ]]; then
        log_info "Successfully retrieved credentials from Opsman API"
        
        # Extract the credential string from JSON
        # Expected format: {"credential": "BOSH_CLIENT=ops_manager BOSH_CLIENT_SECRET=... BOSH_ENVIRONMENT=192.168.11.11 bosh "}
        local credential_string=$(echo "$creds_output" | grep -o '"credential":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$credential_string" ]; then
            # Parse BOSH_CLIENT
            UAA_CLIENT_ID=$(echo "$credential_string" | grep -o 'BOSH_CLIENT=[^ ]*' | cut -d'=' -f2)
            
            # Parse BOSH_CLIENT_SECRET  
            UAA_CLIENT_SECRET=$(echo "$credential_string" | grep -o 'BOSH_CLIENT_SECRET=[^ ]*' | cut -d'=' -f2)
            
            # Parse BOSH_ENVIRONMENT (Director IP)
            BOSH_DIRECTOR_IP=$(echo "$credential_string" | grep -o 'BOSH_ENVIRONMENT=[^ ]*' | cut -d'=' -f2)
            
            if [ -n "$UAA_CLIENT_ID" ] && [ -n "$UAA_CLIENT_SECRET" ] && [ -n "$BOSH_DIRECTOR_IP" ]; then
                log_info "Successfully parsed all BOSH credentials:"
                log_info "  BOSH Client: $UAA_CLIENT_ID"
                log_info "  BOSH Director IP: $BOSH_DIRECTOR_IP"
                return 0
            else
                log_warn "Could not parse all required fields from credential string"
                log_warn "Credential string: $credential_string"
            fi
        else
            log_warn "Could not extract credential string from JSON response"
            log_warn "API Response: $creds_output"
        fi
    else
        log_warn "API call failed or returned error"
        log_warn "API Response: $creds_output"
    fi
    
    # Fallback to manual input if automatic retrieval failed
    log_warn "Automatic credential retrieval failed. Manual input required."
    local credentials_url="${OPSMAN_URL}/api/v0/deployed/director/credentials/bosh_commandline_credentials"
    log_warn "Please retrieve the credentials from: $credentials_url"
    
    read -p "Enter UAA Client ID (BOSH_CLIENT): " UAA_CLIENT_ID
    read -s -p "Enter UAA Client Secret (BOSH_CLIENT_SECRET): " UAA_CLIENT_SECRET
    echo  # New line after hidden input
    read -p "Enter BOSH Director IP (BOSH_ENVIRONMENT): " BOSH_DIRECTOR_IP
    
    if [ -z "$UAA_CLIENT_ID" ] || [ -z "$UAA_CLIENT_SECRET" ] || [ -z "$BOSH_DIRECTOR_IP" ]; then
        log_error "Client ID, Secret, and Director IP are all required"
        exit 1
    fi
}

# Function to execute commands on Opsman via SSH
execute_on_opsman() {
    local command="$1"
    log_info "Executing on Opsman: $command"
    
    ssh -F "$SSH_CONFIG_PATH" opsman "$command"
}

# Function to setup UAA client in BOSH Director
setup_bosh_uaa_client() {
    log_info "Setting up UAA client in BOSH Director..."
    
    log_info "Setting BOSH UAA target..."
    execute_on_opsman "uaac target https://$BOSH_DIRECTOR_IP:8443 --skip-ssl-validation"

    # Execute commands directly via SSH instead of creating a script file
    log_info "Getting BOSH UAA token..."
    execute_on_opsman "uaac token client get '$UAA_CLIENT_ID' -s '$UAA_CLIENT_SECRET'"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get BOSH UAA token"
        exit 1
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to set BOSH UAA target"
        exit 1
    fi
    
    log_info "Adding UAA client to BOSH Director: $CLIENT_NAME"
    execute_on_opsman "uaac client add $CLIENT_NAME --secret '$CLIENT_SECRET' --authorized_grant_types client_credentials,refresh_token --authorities bosh.read --scope bosh.read"
    
    if [ $? -eq 0 ]; then
        log_info "BOSH UAA client '$CLIENT_NAME' added successfully"
    else
        log_error "Failed to add BOSH UAA client"
        exit 1
    fi
}

# Function to setup UAA client in Opsman
setup_opsman_uaa_client() {
    log_info "Setting up UAA client in Opsman..."
    
    # Extract hostname from OPSMAN_URL for UAA target
    local opsman_host=$(echo "$OPSMAN_URL" | sed 's|https\?://||' | sed 's|/.*||')
    local uaa_target="https://${opsman_host}/uaa"
    
    log_info "Setting Opsman UAA target: $uaa_target"
    execute_on_opsman "uaac target $uaa_target --skip-ssl-validation"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to set Opsman UAA target"
        exit 1
    fi
    
    log_info "Getting Opsman UAA token (owner grant)..."
    # Note: This will prompt for Client Secret (leave empty), Username, and Password
    execute_on_opsman "echo -e '\n$OPSMAN_USERNAME\n$OPSMAN_PASSWORD' | uaac token owner get opsman"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get Opsman UAA token"
        exit 1
    fi
    
    log_info "Adding UAA client to Opsman: $CLIENT_NAME"
    execute_on_opsman "uaac client add $CLIENT_NAME --secret '$CLIENT_SECRET' --authorized_grant_types client_credentials,refresh_token --authorities scim.read"
    
    if [ $? -eq 0 ]; then
        log_info "Opsman UAA client '$CLIENT_NAME' added successfully"
    else
        log_error "Failed to add Opsman UAA client"
        exit 1
    fi
}

# Function to verify client was created
verify_bosh_client() {
    log_info "Verifying BOSH UAA client creation..."
    
    log_info "Listing BOSH UAA clients to verify creation..."
    execute_on_opsman "uaac target https://$BOSH_DIRECTOR_IP:8443 --skip-ssl-validation && uaac clients | grep -A 5 -B 5 '$CLIENT_NAME' || echo '[WARN] Client not found in BOSH UAA listing'"
}

# Function to verify Opsman client was created
verify_opsman_client() {
    log_info "Verifying Opsman UAA client creation..."
    
    # Extract hostname from OPSMAN_URL for UAA target
    local opsman_host=$(echo "$OPSMAN_URL" | sed 's|https\?://||' | sed 's|/.*||')
    local uaa_target="https://${opsman_host}/uaa"
    
    log_info "Listing Opsman UAA clients to verify creation..."
    execute_on_opsman "uaac target $uaa_target --skip-ssl-validation && uaac clients | grep -A 5 -B 5 '$CLIENT_NAME' || echo '[WARN] Client not found in Opsman UAA listing'"
}

# Function to extract Opsman URL from SSH config
get_opsman_url_from_ssh_config() {
    log_info "Attempting to extract Opsman URL from SSH config..."
    
    if [ ! -f "$SSH_CONFIG_PATH" ]; then
        log_warn "SSH config file not found at: $SSH_CONFIG_PATH"
        return 1
    fi
    
    # Look for the opsman host entry in SSH config
    local opsman_hostname=$(grep -A 10 -i "^Host opsman" "$SSH_CONFIG_PATH" | grep -i "HostName" | head -1 | awk '{print $2}' | tr -d '\r\n')
    
    if [ -z "$opsman_hostname" ]; then
        # Try alternative patterns
        opsman_hostname=$(grep -A 10 -i "^Host.*opsman" "$SSH_CONFIG_PATH" | grep -i "HostName" | head -1 | awk '{print $2}' | tr -d '\r\n')
    fi
    
    if [ -z "$opsman_hostname" ]; then
        log_warn "Could not find Opsman hostname in SSH config"
        return 1
    fi
    
    # Construct the HTTPS URL
    OPSMAN_URL="https://$opsman_hostname"
    log_info "Extracted Opsman URL from SSH config: $OPSMAN_URL"
    return 0
}

# Main execution
main() {
    log_info "Starting Cloud Foundry Opsman UAA Client Setup"
    
    check_prerequisites
    get_opsman_url_from_ssh_config
    get_operation_mode
    get_opsman_credentials
    validate_and_get_client_secret
    
    # Setup based on operation mode
    case $OPERATION_MODE in
        "bosh")
            get_bosh_credentials_and_ip
            setup_bosh_uaa_client
            verify_bosh_client
            log_info "BOSH UAA client setup completed successfully!"
            log_info "BOSH Director IP: $BOSH_DIRECTOR_IP"
            ;;
        "opsman")
            setup_opsman_uaa_client
            verify_opsman_client
            log_info "Opsman UAA client setup completed successfully!"
            ;;
        "both")
            get_bosh_credentials_and_ip
            setup_bosh_uaa_client
            setup_opsman_uaa_client
            verify_bosh_client
            verify_opsman_client
            log_info "Both BOSH and Opsman UAA client setup completed successfully!"
            log_info "BOSH Director IP: $BOSH_DIRECTOR_IP"
            ;;
    esac
    
    log_info "Final Configuration Summary:"
    log_info "  Opsman URL: $OPSMAN_URL"
    log_info "  Client Name: $CLIENT_NAME"
    log_info "  Client Secret: [HIDDEN]"
    
    if [[ "$OPERATION_MODE" == "bosh" || "$OPERATION_MODE" == "both" ]]; then
        log_info "  BOSH Director IP: $BOSH_DIRECTOR_IP"
        log_info "  BOSH Authorities: bosh.read"
        log_info "  BOSH Scopes: bosh.read"
    fi
    
    if [[ "$OPERATION_MODE" == "opsman" || "$OPERATION_MODE" == "both" ]]; then
        log_info "  Opsman Authorities: scim.read"
    fi
    
    log_info "  Grant Types: client_credentials, refresh_token"
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"
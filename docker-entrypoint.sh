#!/bin/sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# Default configuration
DEFAULT_KEY_NAME="relayer_key"
DEFAULT_KEY_DIR="/home/relayer/.keys"

# Environment variables with defaults
KEY_DIR="${KEY_DIR:-$DEFAULT_KEY_DIR}"
KEY_NAME="${KEY_NAME:-$DEFAULT_KEY_NAME}"
START_ALL_PATHS="${START_ALL_PATHS:-true}"
SPECIFIC_PATH="${SPECIFIC_PATH:-}"
NO_START="${NO_START:-false}"
LIST_PATHS="${LIST_PATHS:-false}"

# Function to restore keys
restore_keys() {
    log_info "Restoring keys..."

    for chain_key_file in $KEY_DIR/*; do
        chain=$(basename $chain_key_file)

        # Check if key already exists
        if rly keys list "$chain" 2>/dev/null | grep -q "$KEY_NAME"; then
            log_warning "Key $KEY_NAME for $chain already exists, skipping..."
            continue
        fi

        log_info "Restoring key for chain: $chain"
        rly keys restore "$chain" "$KEY_NAME" "$(cat $chain_key_file)"
    done
}

# Function to list paths
list_paths() {
    log_info "Listing available paths..."
    rly paths list
}

# Function to check balances
check_balances() {
    log_info "Checking account balances..."

    CHAINS=$(rly chains list --yaml | grep -E -o '^[^ ][^:]+')

    for chain in $CHAINS; do
        log_info "Balance for $chain:"
        if ! rly q balance "$chain"; then
            log_warning "Could not query balance for $chain (chain might be down or account not funded)"
        fi
    done
}

# Function to start relayer
start_relayer() {
    if [ "$START_ALL_PATHS" = "true" ]; then
        log_info "Starting relayer on all configured paths..."
        exec rly start --enable-debug-server --debug-listen-addr localhost:7597
    elif [ -n "$SPECIFIC_PATH" ]; then
        log_info "Starting relayer on specific path: $SPECIFIC_PATH"
        exec rly start "$SPECIFIC_PATH" --enable-debug-server --debug-listen-addr localhost:7597
    else
        log_error "No valid start configuration specified"
        exit 1
    fi
}

# Main execution flow
main() {
    log_info "=== Initialization ==="

    restore_keys
    check_balances

    if [ "$LIST_PATHS" = "true" ]; then
        list_paths
    fi

    log_success "=== Initialization Complete ==="

    if [ "$NO_START" = "false" ]; then
        log_info "=== Starting Relayer ==="
        start_relayer
    else
        log_info "=== No Start Configuration ==="
    fi
}

# Handle signals gracefully
trap 'log_info "Shutting down relayer..."; exit 0' SIGTERM SIGINT

# Run main function
main "$@"

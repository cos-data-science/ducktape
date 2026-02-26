#!/bin/bash

################################################################################
# ducktape Shared Utilities
################################################################################
# Common functions used across ducktape scripts
# Source this file at the beginning of other scripts:
#   source "$(dirname "$0")/utils.sh"
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "\n${BLUE}=============================================="
    echo -e "$1"
    echo -e "==============================================\n${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_check() {
    if [ $1 -eq 1 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Utility functions
command_exists() {
    command -v "$1" &> /dev/null
}

format_size() {
    local size=$1
    if [ $size -lt 1024 ]; then
        echo "${size}B"
    elif [ $size -lt 1048576 ]; then
        echo "$(( size / 1024 ))KB"
    elif [ $size -lt 1073741824 ]; then
        echo "$(( size / 1024 / 1024 ))MB"
    else
        echo "$(( size / 1024 / 1024 / 1024 ))GB"
    fi
}

get_dir_size() {
    if [ -d "$1" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'
        else
            du -sb "$1" 2>/dev/null | awk '{print $1}'
        fi
    else
        echo "0"
    fi
}

get_file_size() {
    if [ -f "$1" ]; then
        stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null
    else
        echo "0"
    fi
}

# Configuration loading
load_config() {
    # Try to load config.sh from parent directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_path="${script_dir}/../config.sh"
    
    if [ -f "$config_path" ]; then
        source "$config_path"
        return 0
    else
        return 1
    fi
}

# Set default config values
set_default_config() {
    PG_DIR="${PG_DIR:-$HOME/osfdata/pg}"
    OSFIO_DIR="${OSFIO_DIR:-$HOME/osfio}"
    PARQUET_DIR="${PARQUET_DIR:-$HOME/osfdata/parquet}"
    DUCKDB_PATH="${DUCKDB_PATH:-$HOME/osfdata/osf.db}"
    KEYS_PATH="${KEYS_PATH:-$HOME/osfdata/keys.rds}"
    GPATH="${GPATH:-cos-gdrive:/data-science-warehouse/OSF Backups}"
}

# Progress bar generator (40 characters wide)
progress_bar() {
    local percent=$1
    local width=40
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]"
}

# Spinner animation
spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r  %s %s" "${spinstr:0:1}" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%*s\r" $((${#message} + 5)) ""
}

# Enhanced print functions for tests
print_test() {
    local status=$1
    local message=$2
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC} - $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC} - $message"
    else
        echo -e "${RED}✗ FAIL${NC} - $message"
    fi
}

# Track progress for loops
track_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local bar=$(progress_bar $percent)
    
    printf "\r  ➜ %s: %s %d%% (%d/%d)" "$message" "$bar" $percent $current $total
    
    # New line when complete
    if [ $current -eq $total ]; then
        echo ""
    fi
}

################################################################################
# Export functions for use in other scripts
################################################################################

# Note: In bash, functions are automatically available after sourcing
# No explicit export needed

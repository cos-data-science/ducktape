#!/bin/bash

################################################################################
# ducktape Interactive Setup Wizard
################################################################################
# This script guides you through the first-time setup of ducktape
################################################################################

set -e  # Exit on error

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Welcome message
clear
print_header "Welcome to ducktape Setup Wizard"

echo "This wizard will help you configure ducktape for first-time use."
echo "It will:"
echo "  1. Check your system dependencies"
echo "  2. Configure your paths"
echo "  3. Set up rclone (optional)"
echo "  4. Install R packages"
echo "  5. Create your config.sh file"
echo ""

# Check if config.sh already exists
if [ -f "../config.sh" ]; then
    print_warning "config.sh already exists!"
    echo ""
    echo "Options:"
    echo "  1) Backup existing config and create new one"
    echo "  2) Exit setup (keep existing config)"
    echo ""
    read -p "Choose option (1 or 2): " -n 1 -r
    echo
    
    if [[ $REPLY == "1" ]]; then
        BACKUP_FILE="../config.sh.backup.$(date +%Y%m%d-%H%M%S)"
        mv "../config.sh" "$BACKUP_FILE"
        print_success "Backed up existing config to: $(basename $BACKUP_FILE)"
    else
        echo "Setup cancelled. To modify your config, edit config.sh directly."
        exit 0
    fi
fi

read -p "Ready to begin? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

################################################################################
# STEP 1: Check Dependencies
################################################################################

print_header "Step 1: Checking Dependencies"

MISSING_DEPS=0

# Check DuckDB
if command_exists duckdb; then
    VERSION=$(duckdb --version 2>&1 | head -n1)
    print_success "DuckDB is installed: $VERSION"
else
    print_error "DuckDB is NOT installed"
    MISSING_DEPS=1
    echo "  Install with:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "    brew install duckdb"
    else
        echo "    wget https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip"
        echo "    unzip duckdb_cli-linux-amd64.zip && sudo mv duckdb /usr/local/bin/"
    fi
fi

# Check Docker
if command_exists docker; then
    VERSION=$(docker --version 2>&1)
    print_success "Docker is installed: $VERSION"
else
    print_error "Docker is NOT installed"
    MISSING_DEPS=1
    echo "  Install from: https://www.docker.com/get-started"
fi

# Check R
if command_exists Rscript; then
    VERSION=$(Rscript --version 2>&1 | head -n1)
    print_success "R is installed: $VERSION"
else
    print_error "R is NOT installed"
    MISSING_DEPS=1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  Install with: brew install r"
    else
        echo "  Install with: sudo apt install r-base"
    fi
fi

# Check rclone
if command_exists rclone; then
    VERSION=$(rclone version 2>&1 | head -n1)
    print_success "rclone is installed: $VERSION"
    RCLONE_AVAILABLE=1
else
    print_warning "rclone is NOT installed (optional for Google Drive uploads)"
    RCLONE_AVAILABLE=0
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  Install with: brew install rclone"
    else
        echo "  Install with: curl https://rclone.org/install.sh | sudo bash"
    fi
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    print_error "Please install missing dependencies and run setup again."
    exit 1
fi

################################################################################
# STEP 2: Configure Paths
################################################################################

print_header "Step 2: Configure Paths"

echo "Let's set up your data directories."
echo ""

# PostgreSQL backup directory
echo "PostgreSQL Backup Directory"
echo "This is where your uncompressed PostgreSQL backup is located."
read -p "Enter path [default: $HOME/osfdata/pg]: " PG_DIR_INPUT
PG_DIR=${PG_DIR_INPUT:-$HOME/osfdata/pg}

if [ -d "$PG_DIR" ]; then
    print_success "Directory exists: $PG_DIR"
else
    print_warning "Directory does not exist: $PG_DIR"
    read -p "Create it now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$PG_DIR"
        print_success "Created directory: $PG_DIR"
    fi
fi

echo ""

# OSF.io codebase directory
echo "OSF.io Codebase Directory"
echo "This is where the osf.io codebase with docker-compose.yml is located."
read -p "Enter path [default: $HOME/osfio]: " OSFIO_DIR_INPUT
OSFIO_DIR=${OSFIO_DIR_INPUT:-$HOME/osfio}

if [ -d "$OSFIO_DIR" ]; then
    print_success "Directory exists: $OSFIO_DIR"
else
    print_warning "Directory does not exist: $OSFIO_DIR"
    read -p "Create it now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$OSFIO_DIR"
        print_success "Created directory: $OSFIO_DIR"
    fi
fi

echo ""

# Parquet directory
echo "Parquet Output Directory"
echo "This is where Parquet files will be saved (requires several GB)."
read -p "Enter path [default: $HOME/osfdata/parquet]: " PARQUET_DIR_INPUT
PARQUET_DIR=${PARQUET_DIR_INPUT:-$HOME/osfdata/parquet}
mkdir -p "$PARQUET_DIR"
print_success "Will use: $PARQUET_DIR"

echo ""

# DuckDB database path
echo "DuckDB Database Path"
echo "This is where the final DuckDB database will be saved."
read -p "Enter path [default: $HOME/osfdata/osf.db]: " DUCKDB_PATH_INPUT
DUCKDB_PATH=${DUCKDB_PATH_INPUT:-$HOME/osfdata/osf.db}
DUCKDB_DIR=$(dirname "$DUCKDB_PATH")
mkdir -p "$DUCKDB_DIR"
print_success "Will use: $DUCKDB_PATH"

echo ""

# Keys path
KEYS_PATH="$DUCKDB_DIR/keys.rds"
print_info "Relational keys will be saved to: $KEYS_PATH"

################################################################################
# STEP 3: Configure Google Drive (Optional)
################################################################################

print_header "Step 3: Configure Google Drive Upload (Optional)"

UPLOAD_TO_GDRIVE=0
GPATH="cos-gdrive:/data-science-warehouse/OSF Backups"

if [ $RCLONE_AVAILABLE -eq 1 ]; then
    echo "Do you want to enable Google Drive uploads?"
    echo "This allows automatic backup of results to Google Drive."
    read -p "Enable Google Drive uploads? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Checking rclone configuration..."
        
        if rclone listremotes 2>/dev/null | grep -q ":"; then
            echo ""
            echo "Available rclone remotes:"
            rclone listremotes
            echo ""
            read -p "Enter remote name (e.g., 'cos-gdrive'): " REMOTE_NAME
            read -p "Enter remote path (e.g., '/data-science-warehouse/OSF Backups'): " REMOTE_PATH
            GPATH="${REMOTE_NAME}:${REMOTE_PATH}"
            UPLOAD_TO_GDRIVE=1
            print_success "Google Drive upload enabled: $GPATH"
        else
            print_warning "No rclone remotes configured"
            echo "Run 'rclone config' to set up Google Drive access"
            read -p "Configure rclone now? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rclone config
                echo ""
                print_info "After configuring rclone, edit config.sh to enable uploads"
            fi
        fi
    else
        print_info "Google Drive uploads disabled"
    fi
else
    print_info "Skipping Google Drive setup (rclone not installed)"
fi

################################################################################
# STEP 4: Install R Packages
################################################################################

print_header "Step 4: Install R Packages"

echo "ducktape requires several R packages: DBI, RPostgres, dm, here"
echo ""
read -p "Install R packages now? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installing R packages using renv..."
    if Rscript -e "renv::restore()" 2>&1; then
        print_success "R packages installed successfully"
    else
        print_warning "There were issues installing R packages"
        echo "You may need to run: Rscript -e \"renv::restore()\" manually"
    fi
else
    print_warning "Skipped R package installation"
    echo "Remember to run: Rscript -e \"renv::restore()\" before using ducktape"
fi

################################################################################
# STEP 5: Create config.sh
################################################################################

print_header "Step 5: Create Configuration File"

echo "Creating config.sh with your settings..."

cat > ../config.sh << EOF
#!/bin/bash

################################################################################
# ducktape Configuration
# Generated by setup wizard on $(date)
################################################################################

# PATHS ------------------------------------------------------------------------
PG_DIR="$PG_DIR"
OSFIO_DIR="$OSFIO_DIR"
PARQUET_DIR="$PARQUET_DIR"
DUCKDB_PATH="$DUCKDB_PATH"
KEYS_PATH="$KEYS_PATH"
GPATH="$GPATH"

# WORKFLOW OPTIONS -------------------------------------------------------------
# Set to 1 to enable, 0 to disable each workflow stage

RUN_CLEAN_SLATE=0        # Purge existing files (CAREFUL!)
RUN_PG_WORKFLOW=1        # Extract tables from PostgreSQL
RUN_PARQUET_WORKFLOW=1   # Export to Parquet files
RUN_DUCKDB_WORKFLOW=1    # Import into DuckDB

# GOOGLE DRIVE OPTIONS ---------------------------------------------------------
UPLOAD_TO_GDRIVE=$UPLOAD_TO_GDRIVE
UPLOAD_KEYS=1
UPLOAD_PARQUET=1
UPLOAD_DUCKDB=1

# ADVANCED OPTIONS -------------------------------------------------------------
PG_HOST="127.0.0.1"
PG_PORT="5432"
PG_USER="postgres"
PG_DBNAME="osf"

CLEAN_SLATE_WAIT_1=120
CLEAN_SLATE_WAIT_2=60
AUTO_START_DOCKER=1

EOF

chmod +x ../config.sh

print_success "config.sh created successfully"

################################################################################
# STEP 6: Summary
################################################################################

print_header "Setup Complete!"

echo "Your ducktape installation is configured and ready to use."
echo ""
echo "Configuration summary:"
echo "  PostgreSQL backup: $PG_DIR"
echo "  Parquet output:    $PARQUET_DIR"
echo "  DuckDB database:   $DUCKDB_PATH"
echo "  Google Drive:      $([ $UPLOAD_TO_GDRIVE -eq 1 ] && echo "Enabled ($GPATH)" || echo "Disabled")"
echo ""
echo "Next steps:"
echo ""
echo "  1. Ensure your PostgreSQL backup is in: $PG_DIR"
echo "  2. Review/edit config.sh if needed"
echo "  3. Run the pipeline: ./run.sh"
echo ""
echo "For help, see:"
echo "  - README.md for usage examples"
echo "  - SETUP.md for detailed setup instructions"
echo "  - example-queries.sql for query examples"
echo ""

print_success "Happy data wrangling!"

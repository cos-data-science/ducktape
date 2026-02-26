# Helper Scripts

This directory contains utility scripts to make working with ducktape easier.

## Core Utilities

### 📦 utils.sh - Shared Utilities Library

Common functions and utilities used across all helper scripts.

**Included functions:**
- **Colors:** `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`
- **Print functions:** `print_header()`, `print_success()`, `print_warning()`, `print_error()`, `print_info()`, `print_check()`, `print_test()`
- **Utilities:** `command_exists()`, `format_size()`, `get_dir_size()`, `get_file_size()`
- **Configuration:** `load_config()`, `set_default_config()`
- **Progress:** `progress_bar()`, `spinner()`, `track_progress()`

**Usage in scripts:**
```bash
# Load utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load config
load_config || set_default_config

# Use functions
print_header "My Script"
print_success "Operation completed"
```

---

## Available Scripts

### 🛠️ setup.sh - Interactive Setup Wizard

Guides you through first-time configuration with an interactive wizard.

```bash
./scripts/setup.sh
```

**Features:**
- Checks all dependencies
- Prompts for directory paths
- Configures Google Drive (optional)
- Installs R packages
- Generates `config.sh` automatically

**Use when:** Setting up ducktape for the first time or on a new machine.

---

### 📊 check-status.sh - Pipeline Status Checker

Shows the current state of your pipeline and data files.

```bash
./scripts/check-status.sh
```

**Displays:**
- ✓ PostgreSQL workflow status (tables, SQL files, keys)
- ✓ Parquet workflow status (file count, total size)
- ✓ DuckDB workflow status (database size, table count)
- ✓ Recent log files and errors
- ✓ Disk space information
- ✓ Overall completion percentage

**Use when:** Checking if a pipeline run completed successfully or monitoring progress.

---

### 🔍 query.sh - Quick Query Helper

Interactive tool for querying your DuckDB database.

```bash
./scripts/query.sh

# Or run a specific query
./scripts/query.sh "SELECT COUNT(*) FROM nodes"
```

**Interactive Menu:**
1. List all tables
2. Show table schemas
3. Count rows in all tables
4. Show nodes summary
5. Show users summary
6. Show recent activity
7. Open DuckDB shell
8. Run example queries

**Use when:** You want to quickly explore data without writing SQL from scratch.

---

### ✅ verify-data.sh - Data Integrity Verification

Runs comprehensive tests to verify data integrity across all pipeline stages.

```bash
./scripts/verify-data.sh
```

**Checks:**
- ✓ Table list exists
- ✓ All tables exported to Parquet
- ✓ No empty Parquet files
- ✓ DuckDB database is readable
- ✓ Table counts match expectations
- ✓ Spot checks on common tables

**Exit codes:**
- `0` = All tests passed
- `1` = Some tests failed

**Use when:** Verifying a pipeline run produced valid data or troubleshooting issues.

---

### 🧹 clean.sh - Safe Cleanup Utility

Interactively clean up pipeline files with safety prompts.

```bash
./scripts/clean.sh
```

**Cleanup Options:**
1. Parquet files only (keep DuckDB)
2. DuckDB database only (keep Parquet)
3. Both Parquet and DuckDB
4. Generated SQL files
5. Log files
6. Everything (full clean)
7. Custom selection

**Safety Features:**
- Shows file sizes before deletion
- Requires confirmation
- "Delete everything" requires typing full phrase

**Use when:** You need to free up disk space or start fresh.

---

## Quick Reference

| Task | Script |
|------|--------|
| First-time setup | `./scripts/setup.sh` |
| Check pipeline status | `./scripts/check-status.sh` |
| Query database | `./scripts/query.sh` |
| Verify data integrity | `./scripts/verify-data.sh` |
| Clean up files | `./scripts/clean.sh` |

## Tips

- **All scripts load config.sh** - They automatically use your configured paths
- **Run from project root** - All scripts should be run from the ducktape directory
- **Safe to re-run** - All scripts are idempotent and safe to run multiple times
- **Colorized output** - Green = success, Yellow = warning, Red = error

## Integration with Pipeline

These scripts complement the main pipeline (`run.sh`):

```bash
# Typical workflow
./scripts/setup.sh          # One-time setup
./run.sh                    # Run pipeline
./scripts/check-status.sh   # Verify completion
./scripts/query.sh          # Explore data
./scripts/verify-data.sh    # Run integrity checks
```

## Troubleshooting

**Script not executable:**
```bash
chmod +x scripts/*.sh
```

**Config not found warnings:**
- Scripts will use defaults if `config.sh` doesn't exist
- Run `./scripts/setup.sh` to create config.sh

**Permission denied:**
- Ensure you have write access to configured directories
- Check paths in config.sh are correct

## Contributing

To add a new helper script:
1. Create the script in `scripts/` directory
2. Make it executable: `chmod +x scripts/your-script.sh`
3. Add color variables if using output formatting
4. Load `config.sh` if the script needs configuration
5. Document it in this README

---

**Questions?** See the main [README.md](../README.md) or [SETUP.md](../SETUP.md)

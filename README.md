# 🦆 ducktape

A pipeline for simplifying your work with the OSF database backups using a motley assortment of tools and programs. `ducktape` transforms a PostgreSQL backup into a local DuckDB database (along with the underlying data tables as individual Parquet files) ready for exploration and analysis. No Docker shells or complex command-line hacking required!

## 🎯 What Does It Do?

`ducktape` automates the complete workflow from PostgreSQL backup to queryable DuckDB database:

```
PostgreSQL Backup → Extract Tables → Parquet Files → DuckDB Database
                         ↓               ↓              ↓
                    tables.txt      .parquet files   osf.db (ready!)
```

**Key Benefits:**

- 🚀 Fast queries on large OSF datasets using DuckDB
- 💾 Efficient storage with Parquet compression
- 🔍 No need to run Docker containers or PostgreSQL servers
- 📊 Direct integration with R, Python, and SQL analytics tools
- ☁️ Automatic backup to Google Drive (optional)

---

## 📋 Requirements

### Core Dependencies

1. **PostgreSQL Backup**: A properly staged PostgreSQL backup for local use
2. **[DuckDB](https://duckdb.org/docs/installation/)**: Installed and accessible via command line
   ```bash
   # macOS
   brew install duckdb
   
   # Linux
   wget https://github.com/duckdb/duckdb/releases/download/v0.10.0/duckdb_cli-linux-amd64.zip
   unzip duckdb_cli-linux-amd64.zip
   sudo mv duckdb /usr/local/bin/
   ```

3. **[rclone](https://rclone.org/)**: For Google Drive uploads (optional but recommended)
   ```bash
   # macOS
   brew install rclone
   
   # Linux
   curl https://rclone.org/install.sh | sudo bash
   ```
   
   Configure for Google Drive: Follow [rclone Google Drive setup](https://rclone.org/drive/)

4. **R (>= 4.0)**: With the following packages
   ```r
   # Install from R console
   install.packages("renv")
   renv::restore()  # Run from project directory
   ```

5. **Docker** (if working with PostgreSQL backups directly)

### Verify Installation

Run these commands to verify everything is installed:

```bash
duckdb --version          # Should show DuckDB version
rclone version            # Should show rclone version
Rscript --version         # Should show R version
docker --version          # Should show Docker version (if needed)
```

---

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd ducktape

# Restore R dependencies
Rscript -e "renv::restore()"
```

**⚡ Even easier:** Use the interactive setup wizard:

```bash
./scripts/setup.sh
```

This will guide you through dependency checks, path configuration, and R package installation.

### 2. Configure Paths

**Easy way (Recommended):** Use the interactive setup wizard

```bash
./scripts/setup.sh
```

Or manually configure:

```bash
# Copy the template
cp config.template.sh config.sh

# Edit with your paths
nano config.sh  # or vim, code, etc.
```

The config file has well-documented settings for all paths and options.

<details>
<summary>Alternative: Edit run.sh directly (click to expand)</summary>

Edit the "CONFIG" section in `run.sh` (lines 4-9) to match your system:

```bash
# Example configuration
PG_DIR="${HOME}/osfdata/pg"              # PostgreSQL backup location
OSFIO_DIR="${HOME}/code/osf.io"          # OSF codebase directory
PARQUET_DIR="${HOME}/osfdata/parquet"    # Parquet output directory
DUCKDB_PATH="${HOME}/osfdata/osf.db"     # DuckDB database path
KEYS_PATH="${HOME}/osfdata/keys.rds"     # Relational keys file
GPATH="remote:path/to/backups"           # Google Drive path (rclone)
```

**Note:** We recommend using `config.sh` instead to avoid accidentally committing your personal paths.
</details>

**💡 Tip:** Create a `data/` directory in the project root to keep everything organized:

```bash
mkdir -p data/{pg,parquet}
export PG_DIR="$(pwd)/data/pg"
export PARQUET_DIR="$(pwd)/data/parquet"
export DUCKDB_PATH="$(pwd)/data/osf.db"
```

### 3. Configure Runtime Options

Set which workflows to run in `config.sh`:

```bash
RUN_CLEAN_SLATE=0          # Set to 1 to delete existing files (CAREFUL!)
RUN_PG_WORKFLOW=1          # Extract table list and relational keys
RUN_PARQUET_WORKFLOW=1     # Convert PostgreSQL tables to Parquet
RUN_DUCKDB_WORKFLOW=1      # Import Parquet files into DuckDB
```

**First-time setup:** Set all to `1` except `RUN_CLEAN_SLATE`  
**Incremental updates:** Enable only the workflows you need

### 3b. Table Selection

By default, `ducktape` exports a **subset of 11 commonly used tables** defined in the `EXPORT_TABLES` array in `config.sh`:

```bash
# Default tables exported (from config.sh)
EXPORT_TABLES=(
    "osf_abstractnode"
    "osf_guid"
    "osf_osfuser"
    "osf_abstractnode_subjects"
    "osf_nodelog"
    "osf_guidmetadatarecord"
    "osf_institution"
    "osf_subject"
    "osf_registrationschema"
    "osf_abstractprovider"
    "osf_outcomeartifact"
)
```

You can edit this list to include any tables you need. When `EXPORT_TABLES` is set:

- **Parquet export:** Only the named tables are exported as `.parquet` files
- **DuckDB import:** Only the named tables are created in the DuckDB database
- **Relational keys:** `keys.rds` is filtered to only include primary keys for the named tables, and foreign keys where **both** parent and child tables are in the subset
- **Validation:** The pipeline warns if any names in `EXPORT_TABLES` don't match actual database tables

To export **all** tables instead, set the array to empty:

```bash
EXPORT_TABLES=()
```

Table names should match what appears in `tables.txt` (without the `osf.` schema prefix).

### 4. Run the Pipeline

```bash
./run.sh
```

**Expected Runtime:**
- Small databases (~10 tables): 2-5 minutes
- Full OSF database (100+ tables): 15-30 minutes

Monitor progress in the `logs/` directory:
```bash
tail -f logs/run-$(date +%Y%m%d).log
```

### 5. Explore Your Data!

Once complete, query your DuckDB database:

```bash
duckdb data/osf.db
```

```sql
-- See available tables
SHOW TABLES;

-- Example: Count nodes
SELECT COUNT(*) FROM nodes;

-- Example: Find recent projects
SELECT title, created 
FROM nodes 
WHERE type = 'osf.node' 
ORDER BY created DESC 
LIMIT 10;
```

---

## 🔄 Pipeline Workflows

### Workflow 1: PostgreSQL (Table Extraction)

**Purpose:** Extract table list and relational keys from PostgreSQL backup

**Steps:**

1. Queries PostgreSQL for all table names → `tables.txt`
2. Extracts primary/foreign keys → `keys.rds`
3. Generates SQL export commands → `pg-to-parquet.sql`
4. Uploads metadata to Google Drive

**Output Files:**

- `tables.txt`: List of all database tables
- `keys.rds`: R object containing relational structure
- `pg-to-parquet.sql`: Generated COPY commands for Parquet export

### Workflow 2: Parquet (Data Export)

**Purpose:** Export PostgreSQL tables to Parquet format (selected tables or all)

**Steps:**
1. Executes `pg-to-parquet.sql` against PostgreSQL
2. Creates one `.parquet` file per table in `PARQUET_DIR`
3. Uploads Parquet files to Google Drive

**Output:** Individual `.parquet` files (one per exported table)

### Workflow 3: DuckDB (Database Creation)

**Purpose:** Import Parquet files into a queryable DuckDB database

**Steps:**
1. Generates import SQL → `parquet-to-duck.sql`
2. Creates DuckDB database from Parquet files
3. Uploads `osf.db` to Google Drive

**Output:** `osf.db` - Ready-to-query DuckDB database

---

## 📁 Project Structure

```
ducktape/
├── run.sh                   # Main pipeline orchestrator
├── config.sh                # Your local configuration (git-ignored)
├── config.template.sh       # Configuration template
├── README.md                # This file
├── renv.lock                # R package dependencies
├── .Rprofile                # R environment config
├── .gitignore
│
├── src/                     # Source code
│   ├── get-keys.r           # Extract relational keys from PostgreSQL
│   └── get-tables.sql       # SQL to list all tables
│
├── scripts/                 # Helper scripts
│   ├── setup.sh             # Interactive setup wizard
│   ├── check-status.sh      # Check pipeline progress
│   ├── verify-data.sh       # Verify data integrity
│   ├── clean.sh             # Safely clean up files
│   ├── query.sh             # Interactive DuckDB query tool
│   ├── utils.sh             # Shared utility functions
│   └── README.md            # Helper script documentation
│
├── logs/                    # Pipeline execution logs
│
├── renv/                    # R environment (managed by renv)
│
│── (Generated at runtime) ──
├── tables.txt               # List of database tables
├── pg-to-parquet.sql        # Generated COPY commands
├── parquet-to-duck.sql      # Generated DuckDB import SQL
└── DB_VERSION.txt           # Database backup timestamp
```

---

## 💡 Usage Examples

### Example 1: First-Time Full Pipeline

```bash
# Configure paths in config.sh
cp config.template.sh config.sh
vim config.sh  # Set PG_DIR, PARQUET_DIR, DUCKDB_PATH, etc.

# Enable all workflows
# In config.sh, set:
RUN_CLEAN_SLATE=0
RUN_PG_WORKFLOW=1
RUN_PARQUET_WORKFLOW=1
RUN_DUCKDB_WORKFLOW=1

./run.sh
```

### Example 2: Update Existing Database

If you already have Parquet files but want to rebuild DuckDB:

```bash
# In run.sh, set:
RUN_PG_WORKFLOW=0
RUN_PARQUET_WORKFLOW=0
RUN_DUCKDB_WORKFLOW=1

./run.sh
```

### Example 3: Export All Tables

The default configuration exports only 11 core tables. To export the entire database instead:

```bash
# In config.sh, set:
EXPORT_TABLES=()
RUN_PG_WORKFLOW=1
RUN_PARQUET_WORKFLOW=1
RUN_DUCKDB_WORKFLOW=1

./run.sh
```

This exports all 100+ tables. Note that this requires significantly more disk space and time.

### Example 4: Skip Google Drive Uploads

Set the upload flag in `config.sh`:

```bash
# In config.sh, set:
UPLOAD_TO_GDRIVE=0
```

---

## 🔍 Querying Your Data

💡 **See [example-queries.sql](example-queries.sql)** for 50+ ready-to-use queries including:
- Node and user analytics
- Storage analysis by provider
- Collaboration patterns
- Temporal trends
- Data quality checks

### From Command Line

```bash
# Interactive DuckDB shell
duckdb data/osf.db

# Run a query directly
duckdb data/osf.db -c "SELECT COUNT(*) FROM nodes;"

# Run example queries from file
duckdb data/osf.db < example-queries.sql

# Export query results to CSV
duckdb data/osf.db -c "COPY (SELECT * FROM nodes LIMIT 1000) TO 'nodes_sample.csv' (HEADER, DELIMITER ',');"
```

### From R

```r
library(DBI)
library(duckdb)

# Connect to database
con <- dbConnect(duckdb(), "data/osf.db", read_only = TRUE)

# Query
nodes <- dbGetQuery(con, "SELECT * FROM nodes LIMIT 10")
print(nodes)

# Or use dplyr
library(dplyr)
nodes_tbl <- tbl(con, "nodes")
nodes_tbl |> 
  filter(type == "osf.node") |> 
  count()

dbDisconnect(con)
```

### From Python

```python
import duckdb

# Connect
con = duckdb.connect('data/osf.db', read_only=True)

# Query
result = con.execute("SELECT * FROM nodes LIMIT 10").fetchdf()
print(result)

con.close()
```

---

## 🛠️ Helper Scripts

ducktape includes several utility scripts to make your workflow easier:

### Quick Start Helper
```bash
./scripts/setup.sh          # Interactive setup wizard
```

### Pipeline Management
```bash
./scripts/check-status.sh   # Check pipeline progress and completion
./scripts/verify-data.sh    # Verify data integrity
./scripts/clean.sh          # Safely clean up files
```

### Data Exploration
```bash
./scripts/query.sh          # Interactive DuckDB query tool
```

**See [scripts/README.md](scripts/README.md) for detailed documentation of all helper scripts.**

---

## 🐛 Troubleshooting

### Issue: "command not found: duckdb"

**Solution:** Install DuckDB and ensure it's in your PATH:
```bash
brew install duckdb  # macOS
# or download from https://duckdb.org/docs/installation/
```

### Issue: "cannot connect to PostgreSQL"

**Solution:** Verify your PostgreSQL backup is properly staged:
```bash
# Check if PostgreSQL directory exists
ls -la $PG_DIR

# Verify Docker container is running (if applicable)
docker ps | grep postgres
```

### Issue: "R packages not found"

**Solution:** Restore R environment:
```bash
Rscript -e "renv::restore()"
```

### Issue: "rclone error: remote not found"

**Solution:** Configure rclone for Google Drive:
```bash
rclone config  # Follow interactive setup
rclone listremotes  # Verify 'remote' appears
```

### Issue: "Parquet files not found"

**Solution:** Verify `PARQUET_DIR` is correct and Workflow 2 completed:
```bash
ls -la $PARQUET_DIR/*.parquet
# Should show many .parquet files
```

### Issue: "Permission denied: ./run.sh"

**Solution:** Make script executable:
```bash
chmod +x run.sh
```

---

## 📊 Performance Tips

1. **Use SSD storage** for `PARQUET_DIR` and `DUCKDB_PATH` - significantly faster I/O
2. **Allocate sufficient RAM** - DuckDB benefits from memory (8GB+ recommended)
3. **Skip Google Drive uploads** during development to save time
4. **Use incremental workflows** - don't re-run completed stages
5. **Monitor disk space** - Parquet files + DuckDB can be several GB

---

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- [x] Add configuration file (avoid editing `run.sh`)
- [x] Add data validation checks
- [x] Create progress indicators
- [ ] Implement dry-run mode
- [ ] Support other cloud storage backends
- [ ] Add automated tests

---

## 📝 License

[Add your license here]

---

## ❓ FAQ

**Q: Do I need to keep the Parquet files after creating the DuckDB database?**  
A: Not strictly necessary, but recommended for backup and regenerating DuckDB if needed.

**Q: Can I query Parquet files directly without DuckDB?**  
A: Yes! DuckDB, R (arrow package), Python (pandas/polars), and other tools can read Parquet directly.

**Q: How often should I update the database?**  
A: Depends on your PostgreSQL backup frequency. Re-run when you have a new backup.

**Q: Can I use this with other databases besides OSF?**  
A: Yes! Modify the SQL queries and table extraction logic for your schema.

**Q: Can I export only some tables instead of everything?**  
A: Yes — in fact, the default configuration exports only 11 core tables. Edit the `EXPORT_TABLES` array in `config.sh` to customize which tables are exported. Set it to an empty array `()` to export all tables.

**Q: What if I don't have Google Drive?**  
A: Set `UPLOAD_TO_GDRIVE=0` in `config.sh` — local processing will still work.

---

## 🔗 Resources

- [DuckDB Documentation](https://duckdb.org/docs/)
- [Parquet Format](https://parquet.apache.org/)
- [rclone Google Drive Setup](https://rclone.org/drive/)
- [R renv Package](https://rstudio.github.io/renv/)

---

**Questions or issues?** [Open an issue](link-to-issues) or contact [maintainer]

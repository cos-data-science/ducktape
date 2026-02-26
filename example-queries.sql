-- ============================================================================
-- ducktape Example Queries
-- ============================================================================
-- 
-- This file contains useful example queries for exploring the OSF database
-- in DuckDB. Use these as starting points for your own analyses.
--
-- To run these queries:
--   1. Open DuckDB: duckdb data/osf.db
--   2. Copy/paste queries into the DuckDB CLI
--   3. Or run from command line: duckdb data/osf.db < example-queries.sql
--
-- ============================================================================

-- ----------------------------------------------------------------------------
-- EXPLORING THE DATABASE
-- ----------------------------------------------------------------------------

-- List all available tables
SHOW TABLES;

-- Get row counts for all tables (quick overview)
-- Note: This query can be slow for large databases
-- SELECT 
--     table_name,
--     (SELECT COUNT(*) FROM table_name) as row_count
-- FROM information_schema.tables 
-- WHERE table_schema = 'main'
-- ORDER BY table_name;

-- Describe a specific table's structure
DESCRIBE osf_abstractnode;

-- Get a sample of data from a table
SELECT * FROM osf_guid LIMIT 10;


-- ----------------------------------------------------------------------------
-- BASIC NODE QUERIES
-- ----------------------------------------------------------------------------

-- Count all nodes by type
SELECT 
    type,
    COUNT(*) as count
FROM osf_abstractnode
GROUP BY type
ORDER BY count DESC;

-- Find recently created projects and components
SELECT 
    id,
    title,
    type,
    created,
    is_public
FROM osf_abstractnode
WHERE type = 'osf.node'
  AND is_deleted = false
ORDER BY created DESC
LIMIT 20;

-- Count public vs private projects and components
SELECT 
    CASE 
        WHEN is_public THEN 'Public'
        ELSE 'Private'
    END as visibility,
    COUNT(*) as count
FROM osf_abstractnode
WHERE type = 'osf.node'
  AND is_deleted = false
GROUP BY is_public;

-- Find nodes (projects and registraitons) created in a specific year
SELECT 
    DATE_TRUNC('month', created) as month,
    COUNT(*) as nodes_created
FROM osf_abstractnode
WHERE YEAR(created) = 2023
  AND is_deleted = false
GROUP BY month
ORDER BY month;


-- ----------------------------------------------------------------------------
-- USER QUERIES
-- ----------------------------------------------------------------------------

-- Count total users
SELECT COUNT(*) as total_users FROM osf_osfuser;

-- Find users who registered recently
SELECT 
    username,
    fullname,
    date_registered,
    is_active
FROM osf_osfuser
ORDER BY date_registered DESC
LIMIT 20;

-- Count users by registration year
SELECT 
    YEAR(date_registered) as year,
    COUNT(*) as users_registered
FROM osf_osfuser
WHERE date_registered IS NOT NULL
GROUP BY year
ORDER BY year;

-- Find most active users (by node count)
SELECT 
    u.username,
    u.fullname,
    COUNT(DISTINCT c.node_id) as node_count
FROM osf_osfuser u
LEFT JOIN osf_contributor c ON u.id = c.user_id
WHERE u.is_active = true
GROUP BY u.id, u.username, u.fullname
ORDER BY node_count DESC
LIMIT 25;


-- ----------------------------------------------------------------------------
-- FILE QUERIES (if file tables exist)
-- ----------------------------------------------------------------------------

-- Count files by storage provider
SELECT 
    provider,
    COUNT(*) as file_count
FROM osf_basefilenode
WHERE deleted IS NULL
GROUP BY provider
ORDER BY file_count DESC;

-- Find most recently modified files
SELECT 
    name,
    provider,
    created,
    modified,
    deleted
FROM osf_basefilenode
WHERE deleted IS NULL
ORDER BY modified DESC
LIMIT 20;

-- Count files created by month
SELECT 
    DATE_TRUNC('month', created) as month,
    COUNT(*) as files_created
FROM osf_basefilenode
WHERE created >= '2023-01-01'
  AND deleted IS NULL
GROUP BY month
ORDER BY month;


-- ----------------------------------------------------------------------------
-- REGISTRATION QUERIES
-- ----------------------------------------------------------------------------

-- Count registrations by type
SELECT 
    type,
    COUNT(*) as count
FROM osf_abstractnode
WHERE type LIKE '%registration%'
  AND is_deleted = false
GROUP BY type
ORDER BY count DESC;

-- Find recent registrations
SELECT 
    id,
    title,
    created,
    registered_date,
    is_public
FROM osf_abstractnode
WHERE type LIKE '%registration%'
  AND is_deleted = false
ORDER BY registered_date DESC
LIMIT 20;





-- ----------------------------------------------------------------------------
-- STORAGE ANALYTICS
-- ----------------------------------------------------------------------------

-- File counts by provider and node
SELECT 
    provider,
    COUNT(DISTINCT target_object_id) as unique_nodes,
    COUNT(*) as total_files
FROM osf_basefilenode
WHERE deleted IS NULL
GROUP BY provider
ORDER BY total_files DESC;

-- File creation growth over time (monthly)
SELECT 
    DATE_TRUNC('month', created) as month,
    COUNT(*) as new_files,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', created)) as cumulative_files
FROM osf_basefilenode
WHERE deleted IS NULL
  AND created >= '2020-01-01'
GROUP BY month
ORDER BY month;


-- ----------------------------------------------------------------------------
-- COLLABORATION QUERIES
-- ----------------------------------------------------------------------------

-- Find projects with most contributors
SELECT 
    n.title,
    n.type,
    COUNT(DISTINCT c.user_id) as contributor_count
FROM osf_abstractnode n
JOIN osf_contributor c ON n.id = c.node_id
WHERE n.is_deleted = false
  AND n.type = 'osf.node'
GROUP BY n.id, n.title, n.type
ORDER BY contributor_count DESC
LIMIT 20;

-- Count solo vs collaborative projects
SELECT 
    CASE 
        WHEN contributor_count = 1 THEN 'Solo'
        WHEN contributor_count = 2 THEN '2 contributors'
        WHEN contributor_count <= 5 THEN '3-5 contributors'
        WHEN contributor_count <= 10 THEN '6-10 contributors'
        ELSE '10+ contributors'
    END as collaboration_size,
    COUNT(*) as project_count
FROM (
    SELECT 
        n.id,
        COUNT(DISTINCT c.user_id) as contributor_count
    FROM osf_abstractnode n
    JOIN osf_contributor c ON n.id = c.node_id
    WHERE n.is_deleted = false
      AND n.type = 'osf.node'
    GROUP BY n.id
) subquery
GROUP BY 
    CASE 
        WHEN contributor_count = 1 THEN 'Solo'
        WHEN contributor_count = 2 THEN '2 contributors'
        WHEN contributor_count <= 5 THEN '3-5 contributors'
        WHEN contributor_count <= 10 THEN '6-10 contributors'
        ELSE '10+ contributors'
    END
ORDER BY 
    CASE collaboration_size
        WHEN 'Solo' THEN 1
        WHEN '2 contributors' THEN 2
        WHEN '3-5 contributors' THEN 3
        WHEN '6-10 contributors' THEN 4
        ELSE 5
    END;


-- ----------------------------------------------------------------------------
-- TEMPORAL ANALYSIS
-- ----------------------------------------------------------------------------

-- Activity by day of week
SELECT 
    DAYNAME(created) as day_of_week,
    COUNT(*) as nodes_created
FROM osf_abstractnode
WHERE created >= '2023-01-01'
  AND is_deleted = false
GROUP BY day_of_week, DAYOFWEEK(created)
ORDER BY DAYOFWEEK(created);

-- Activity by hour of day (UTC)
SELECT 
    HOUR(created) as hour_utc,
    COUNT(*) as nodes_created
FROM osf_abstractnode
WHERE created >= '2023-01-01'
  AND is_deleted = false
GROUP BY hour_utc
ORDER BY hour_utc;


-- ----------------------------------------------------------------------------
-- DATA QUALITY CHECKS
-- ----------------------------------------------------------------------------

-- Find nodes with missing titles
SELECT 
    id,
    type,
    created
FROM osf_abstractnode
WHERE title IS NULL OR title = ''
  AND is_deleted = false
LIMIT 20;

-- Check for orphaned contributors (users not in user table)
SELECT 
    c.user_id,
    COUNT(*) as contribution_count
FROM osf_contributor c
LEFT JOIN osf_osfuser u ON c.user_id = u.id
WHERE u.id IS NULL
GROUP BY c.user_id
ORDER BY contribution_count DESC;

-- Find duplicate nodes by title (potential data quality issue)
SELECT 
    title,
    COUNT(*) as duplicate_count
FROM osf_abstractnode
WHERE is_deleted = false
  AND title IS NOT NULL
GROUP BY title
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- EXPORT EXAMPLES
-- ----------------------------------------------------------------------------

-- Export query results to CSV
-- COPY (
--     SELECT 
--         _id,
--         title,
--         type,
--         created,
--         is_public
--     FROM nodes
--     WHERE type = 'osf.node'
--       AND created >= '2023-01-01'
--     ORDER BY created
-- ) TO 'nodes_2023.csv' (HEADER, DELIMITER ',');

-- Export to Parquet (for further analysis in R/Python)
-- COPY (
--     SELECT * FROM nodes WHERE is_deleted = false
-- ) TO 'nodes_active.parquet' (FORMAT PARQUET);


-- ----------------------------------------------------------------------------
-- Performance tips
-- ----------------------------------------------------------------------------

-- Create indexes for frequently queried columns (optional)
-- Note: DuckDB is fast even without indexes for most queries
-- CREATE INDEX idx_nodes_created ON osf_abstractnode(created);
-- CREATE INDEX idx_nodes_type ON osf_abstractnode(type);
-- CREATE INDEX idx_nodes_deleted ON osf_abstractnode(is_deleted);


-- ============================================================================
-- CUSTOM QUERY TEMPLATES
-- ============================================================================

-- Template: Count by field
-- SELECT 
--     <field_name>,
--     COUNT(*) as count
-- FROM <table_name>
-- GROUP BY <field_name>
-- ORDER BY count DESC;

-- Template: Time series analysis
-- SELECT 
--     DATE_TRUNC('<day|week|month|year>', <date_field>) as period,
--     COUNT(*) as count
-- FROM <table_name>
-- WHERE <date_field> >= '<start_date>'
-- GROUP BY period
-- ORDER BY period;

-- Template: Join two tables
-- SELECT 
--     t1.field1,
--     t2.field2
-- FROM table1 t1
-- JOIN table2 t2 ON t1.id = t2.foreign_key
-- WHERE <conditions>;

-- ============================================================================
-- END OF EXAMPLES
-- ============================================================================

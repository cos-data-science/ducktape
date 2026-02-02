-- Connect to OSF postgres backup
ATTACH 'dbname=osf user=postgres host=127.0.0.1 port=5432' AS osf (TYPE postgres);

-- Get all tables
.once tables.txt
.tables

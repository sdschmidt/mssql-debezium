-- Enable SQL Server Agent (required for CDC)
EXEC xp_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'AgentXpsEnabled', N'REG_DWORD', 1;

-- Create a sample database for testing
CREATE DATABASE TestDB;
GO

USE TestDB;
GO

-- Enable CDC on the database
EXEC sys.sp_cdc_enable_db;
GO

-- Create a sample table
CREATE TABLE users (
  id INT PRIMARY KEY IDENTITY(1,1),
  name NVARCHAR(100) NOT NULL,
  email NVARCHAR(100),
  created_at DATETIME DEFAULT GETDATE()
);
GO

-- Enable CDC on the table
EXEC sys.sp_cdc_enable_table
  @source_schema = 'dbo',
  @source_name = 'users',
  @role_name = NULL;
GO

-- Create a login for Debezium
CREATE LOGIN debezium WITH PASSWORD = 'Deb3zium_P@ss';
GO

USE TestDB;
GO

-- Create a user for Debezium
CREATE USER debezium FOR LOGIN debezium;
GO

-- Grant necessary permissions for Debezium
GRANT SELECT ON sys.tables TO debezium;
GRANT SELECT ON sys.schemas TO debezium;
GRANT SELECT ON sys.databases TO debezium;
GRANT EXECUTE ON sys.sp_cdc_enable_db TO debezium;
GRANT EXECUTE ON sys.sp_cdc_enable_table TO debezium;
GRANT SELECT ON cdc.change_tables TO debezium;
GRANT SELECT ON cdc.lsn_time_mapping TO debezium;
GRANT SELECT ON cdc.ddl_history TO debezium;
GRANT SELECT ON cdc.captured_columns TO debezium;
GRANT SELECT ON cdc.index_columns TO debezium;
GRANT SELECT ON cdc.tracked_change_tables TO debezium;
GO

-- Grant SELECT on CDC schema and specific objects
GRANT EXECUTE ON sys.sp_cdc_get_ddl_history TO debezium;
GRANT EXECUTE ON sys.sp_cdc_get_captured_columns TO debezium;
GRANT EXECUTE ON sys.sp_cdc_get_source_columns TO debezium;
GRANT SELECT ON dbo.users TO debezium;
GRANT SELECT ON cdc.dbo_users_CT TO debezium;
GO

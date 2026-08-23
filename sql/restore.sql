SET NOCOUNT ON;
GO

IF DB_ID(N'soma') IS NULL
BEGIN
    RESTORE DATABASE [soma]
      FROM DISK = N'/var/opt/mssql/backup/soma.bak'
      WITH MOVE N'mythtest_Data' TO N'/var/opt/mssql/data/soma.mdf',
           MOVE N'mythtest_Log' TO N'/var/opt/mssql/data/soma_log.ldf',
           RECOVERY,
           REPLACE,
           STATS = 10;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'soma')
BEGIN
    CREATE LOGIN [soma]
      WITH PASSWORD = N'soma', CHECK_POLICY = OFF, DEFAULT_DATABASE = [soma];
END
ELSE
BEGIN
    ALTER LOGIN [soma]
      WITH PASSWORD = N'soma', CHECK_POLICY = OFF, DEFAULT_DATABASE = [soma];
END;
GO

USE [soma];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'soma')
    CREATE USER [soma] FOR LOGIN [soma];
GO

IF IS_ROLEMEMBER(N'db_owner', N'soma') <> 1
    ALTER ROLE [db_owner] ADD MEMBER [soma];
GO

SELECT DB_NAME() AS database_name,
       (SELECT COUNT(*) FROM sys.tables) AS table_count;
GO

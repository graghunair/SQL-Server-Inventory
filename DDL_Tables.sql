/*
		Name		:		DDL_Tables.sql
		Date		:		1st Nov 2021
		Version		:		1.0
		Purpose		:		Create database and tables needed to create a SQL Server Inventory
		History		:
							
							1st Nov 2021	:	v1.0	:	Inception
*/

SET NOCOUNT ON
GO
/*
	CREATE DATABASE [DBA_Inventory]
	GO
	ALTER DATABASE [DBA_Inventory] SET RECOVERY SIMPLE
	GO
*/

USE [DBA_Inventory]
GO
DROP TABLE IF EXISTS [load].[tblSQL_Server_Details]
GO
DROP SCHEMA IF EXISTS [load]
GO
DROP TABLE IF EXISTS [inventory].[tblSQL_Servers]
GO
DROP SCHEMA IF EXISTS [inventory]
GO
CREATE SCHEMA [inventory] AUTHORIZATION [dbo]
GO
CREATE TABLE [inventory].[tblSQL_Servers](
		[SQL_Server_Instance] [nvarchar](128) NOT NULL,
		[Is_Active] [bit] NOT NULL,
		[Is_Active_Desc] [varchar](2000) NULL,
		[Is_Production] [bit] NOT NULL,
		[Application] [varchar](100) NULL,
		[Owner] [varchar](100) NULL,
		[Date_Created] [datetime] NOT NULL,
		CONSTRAINT [PK_tblSQL_Servers] PRIMARY KEY CLUSTERED
			(
				[SQL_Server_Instance] ASC
			))
GO

ALTER TABLE [inventory].[tblSQL_Servers] ADD  CONSTRAINT [DF_inventory_tblSQL_Servers_Is_Active]  DEFAULT 1 FOR [Is_Active]
ALTER TABLE [inventory].[tblSQL_Servers] ADD  CONSTRAINT [DF_inventory_tblSQL_Servers_Is_Production]  DEFAULT 1 FOR [Is_Production]
ALTER TABLE [inventory].[tblSQL_Servers] ADD  CONSTRAINT [DF_inventory_tblSQL_Servers_Date_Created] DEFAULT getdate() FOR [Date_Created]
GO

CREATE SCHEMA [load] AUTHORIZATION [dbo]
GO
CREATE TABLE [load].[tblSQL_Server_Details](
				[SQL_Server_Instance] [nvarchar](128) NOT NULL,
				[SQL_Server_IP] [varchar](48) NULL,
				[SQL_Server_Port] [int] NOT NULL,
				[Server_Name] [sysname] NULL,		
				[Server_Host] [sysname] NULL,
				[Server_Domain] [varchar](256) NULL,
				[SQL_Server_Edition] [nvarchar](128) NULL,
				[SQL_Server_Version] [nvarchar](128) NULL,
				[OS_Version] [nvarchar](128) NULL,
				[Is_Clustered] [bit] NULL,
				[Is_Hadr_Enabled] [bit] NULL,
				[User_Databases_Count] [smallint] NULL,
				[Databases_Data_Size_GB] [decimal](10, 2) NULL,
				[Databases_TLog_Size_GB] [decimal](10, 2) NULL,
				
				[CPU_Count] [smallint] NULL,
				[Physical_Memory_GB] [decimal](10, 2) NULL,
				[Committed_Target_GB] [decimal](10, 2) NULL,
				[Collation] [nvarchar](128) NULL,
				[Last_Full_Backup_Timestamp] DATETIME NULL,
				[Last_Full_Backup_Database_Name] SYSNAME,
				[Last_TLog_Backup_Timestamp] DATETIME NULL,
				[Last_TLog_Backup_Database_Name] SYSNAME,
				[Instance_Default_Data_Path] nvarchar(128) NULL,
				[Instance_Default_TLog_Path] nvarchar(128) NULL,
				[SQL_Server_Service_Account] [nvarchar](256) NULL,
				[SQL_Server_Start_Time] [datetime] NULL,
				[Ad_Hoc_Distributed_Queries] [bit] NULL,
				[Backup_Compression_Default] [bit] NULL,
				[CLR_Enabled] [bit] NULL,
				[Filestream_Access_Level] [tinyint] NULL,
				[MAXDOP] [tinyint] NULL,
				[Optimize_for_ad_hoc_Workloads] [bit] NULL,
				[Xp_Cmdshell] [bit] NULL,
				[File_System_Storage] [xml] NULL,
				[Date_Captured] [datetime] NOT NULL,
			 CONSTRAINT [PK_Load_tblSQL_Server_Details] PRIMARY KEY NONCLUSTERED 
			(
				[SQL_Server_Instance] ASC
			)) 
GO

ALTER TABLE [load].[tblSQL_Server_Details] 
ADD CONSTRAINT [DF_load_tblSQL_Servers_Details_Date_Created] 
DEFAULT (getdate()) FOR [Date_Captured]
GO
ALTER TABLE [load].[tblSQL_Server_Details] 
ADD CONSTRAINT [FK_tblSQL_Server_Details] 
FOREIGN KEY ([SQL_Server_Instance])     
REFERENCES [inventory].[tblSQL_Servers] ([SQL_Server_Instance]) 
GO

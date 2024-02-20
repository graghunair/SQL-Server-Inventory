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
DROP TABLE IF EXISTS [load].[tblSQL_Server_AOAG_Details]
GO
DROP TABLE IF EXISTS [load].[tblSQL_Server_Disk_Drives]
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
      [Last_Full_Backup_Timestamp] [datetime] NULL,
      [Last_Full_Backup_Database_Name] [sysname] NOT NULL,
      [Last_TLog_Backup_Timestamp] [datetime] NULL,
      [Last_TLog_Backup_Database_Name] [sysname] NOT NULL,
      [Instance_Default_Data_Path] [nvarchar](128) NULL,
      [Instance_Default_TLog_Path] [nvarchar](128) NULL,
      [SQL_Server_Service_Account] [nvarchar](256) NULL,
      [SQL_Server_Start_Time] [datetime] NULL,
      [Ad_Hoc_Distributed_Queries] [bit] NULL,
      [Backup_Compression_Default] [bit] NULL,
      [CLR_Enabled] [bit] NULL,
      [Filestream_Access_Level] [tinyint] NULL,
      [MAXDOP] [tinyint] NULL,
      [Optimize_for_ad_hoc_Workloads] [bit] NULL,
      [Xp_Cmdshell] [bit] NULL,      
      [Date_Captured] [datetime] NOT NULL,
 CONSTRAINT [PK_Load_tblSQL_Server_Details] PRIMARY KEY NONCLUSTERED
(
      [SQL_Server_Instance] ASC
)
) 
GO

ALTER TABLE [load].[tblSQL_Server_Details] ADD  CONSTRAINT [DF_load_tblSQL_Servers_Details_Date_Created]  DEFAULT (getdate()) FOR [Date_Captured]
GO

ALTER TABLE [load].[tblSQL_Server_Details]  WITH CHECK ADD  CONSTRAINT [FK_tblSQL_Server_Details] FOREIGN KEY([SQL_Server_Instance])
REFERENCES [inventory].[tblSQL_Servers] ([SQL_Server_Instance])
GO

ALTER TABLE [load].[tblSQL_Server_Details] CHECK CONSTRAINT [FK_tblSQL_Server_Details]
GO

DROP TABLE IF EXISTS [load].[tblSQL_Server_AOAG_Details]
GO
CREATE TABLE [load].[tblSQL_Server_AOAG_Details](
	[SQL_Server_Instance] [nvarchar](128) NULL,
	[Listener_Name] [nvarchar](63) NULL,
	[Listener_Port] [int] NULL,
	[Listener_IP] [nvarchar](4000) NULL,
	[AG_Role] [nvarchar](60) NULL,
	[AG_Name] [sysname] NULL,
	[AG_Availability_Mode] [nvarchar](60) NULL,
	[AG_Failover_Mode] [nvarchar](60) NULL,
	[AG_Sync_Health] [nvarchar](60) NULL,
	[Date_Captured] [datetime] NOT NULL
)
GO
ALTER TABLE [load].[tblSQL_Server_AOAG_Details] ADD  CONSTRAINT [DF_load_tblSQL_Server_AOAG_Details_Date_Created]  DEFAULT (getdate()) FOR [Date_Captured]
GO

DROP TABLE IF EXISTS [load].[tblSQL_Server_Disk_Drives]
GO
CREATE TABLE [load].[tblSQL_Server_Disk_Drives](
	[SQL_Server_Instance] [nvarchar](128) NULL,
	[Server_Host] [nvarchar](128) NULL,
	[Drive] [nvarchar](256) NULL,
	[Volume_Name] [nvarchar](256) NULL,
	[Total_GB] [int] NULL,
	[Free_GB] [int] NULL,
	[Date_Captured] [datetime] NOT NULL)
GO

ALTER TABLE [load].[tblSQL_Server_Disk_Drives] ADD  CONSTRAINT [DF_load_tblSQL_Server_Disk_Drives_Date_Created]  DEFAULT (getdate()) FOR [Date_Captured]
GO

DROP VIEW IF EXISTS [dbo].[vwSQL_Server_Details]
GO
CREATE VIEW [dbo].[vwSQL_Server_Details]
AS
SELECT	[SQL_Server_Instance]
		,[SQL_Server_IP]
		,[SQL_Server_Port]
		,[Server_Name]
		,[Server_Host]
		,[Server_Domain]
		,[SQL_Server_Edition]
		,CASE 
			WHEN [SQL_Server_Version] LIKE '16%' THEN '2022'
			WHEN [SQL_Server_Version] LIKE '15%' THEN '2019'
			WHEN [SQL_Server_Version] LIKE '14%' THEN '2017'
			WHEN [SQL_Server_Version] LIKE '13%' THEN '2016'
			WHEN [SQL_Server_Version] LIKE '12%' THEN '2014'
			WHEN [SQL_Server_Version] LIKE '11%' THEN '2012'
			WHEN [SQL_Server_Version] LIKE '10%' THEN '2008/R2'
			ELSE 'Not Defined'
		END [SQL_Server_Version]
		,CASE 
			WHEN [SQL_Server_Version] LIKE '16%' THEN 'SQL Server 2022'
			WHEN [SQL_Server_Version] LIKE '15%' THEN 'SQL Server 2019'
			WHEN [SQL_Server_Version] LIKE '14%' THEN 'SQL Server 2017'
			WHEN [SQL_Server_Version] LIKE '13%' THEN 'SQL Server 2016'
			WHEN [SQL_Server_Version] LIKE '12%' THEN 'SQL Server 2014'
			WHEN [SQL_Server_Version] LIKE '11%' THEN 'SQL Server 2012'
			WHEN [SQL_Server_Version] LIKE '10%' THEN 'SQL Server 2008/R2'
			ELSE 'Not Defined'
		END [SQL_Server_Version_Verbose]
		,[OS_Version]
		,[Is_Clustered]
		,[Is_Hadr_Enabled]
		,[User_Databases_Count]
		,[Databases_Data_Size_GB]
		,[Databases_TLog_Size_GB]
		,[CPU_Count]
		,[Physical_Memory_GB]
		,[Committed_Target_GB]
		,[Collation]
		,DATEDIFF(hh, [Last_Full_Backup_Timestamp], GETDATE()) AS [Last_Full_Backup_Hours]
		,[Last_Full_Backup_Database_Name]
		,DATEDIFF(hh, [Last_TLog_Backup_Timestamp], GETDATE()) AS [Last_TLog_Backup_Hours]
		,[Last_TLog_Backup_Database_Name]
		,[Instance_Default_Data_Path]
		,[Instance_Default_TLog_Path]
		,[SQL_Server_Service_Account]
		,[SQL_Server_Start_Time]
		,DATEDIFF(dd,GETDATE(),[SQL_Server_Start_Time]) AS [SQL_Server_Start_Days_Ago]
		,[Ad_Hoc_Distributed_Queries]
		,[Backup_Compression_Default]
		,[CLR_Enabled]
		,[Filestream_Access_Level]
		,[MAXDOP]
		,[Optimize_for_ad_hoc_Workloads]
		,[Xp_Cmdshell]
		,[Date_Captured]
FROM	[load].[tblSQL_Server_Details]
WHERE	[Server_Name] <> 'Login Failed!'
GO

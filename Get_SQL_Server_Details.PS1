cls

#Variable Declarations and Initiations
    #[string]$varDBA_Server_Name ="<Server-Name>"
    [string]$varDBA_Server_Name ="SQLDBAInventory"
    [string]$varDBA_Database_Name = "DBA_Inventory"
    [string]$varTarget_Database_Name = "master"

#T-SQL Queries
    $varTruncate_Query =
@"
    TRUNCATE TABLE [load].[tblSQL_Server_Details]
"@

    $varGetSQL_Servers =
@"
    SET NOCOUNT ON
    GO
    SELECT	[SQL_Server_Instance]
    FROM	[inventory].[tblSQL_Servers]
    WHERE	[Is_Active] = 1
    GO
"@

    $varGetSQL_Server_Details = 
@"
    SET NOCOUNT ON
    GO
    DECLARE @varDomain VARCHAR(256)
    DECLARE @varDatabases_Count SMALLINT
    DECLARE @varCPU_Count SMALLINT
    DECLARE @varPhysical_Memory_GB DECIMAL(10,2)
    DECLARE @varCommitted_Target_GB DECIMAL(10,2)
	DECLARE @varSQL_Command NVARCHAR(MAX)
    DECLARE @varSQL_Server_Start_Time DATETIME
    DECLARE @varDatabases_Data_Size_GB DECIMAL(10,2)
    DECLARE @varDatabases_TLog_Size_GB DECIMAL(10,2)
    DECLARE @varFile_System_Storage XML
    DECLARE @varSQL_Server_Service_Account NVARCHAR(256)
    DECLARE	@varAd_Hoc_Distributed_Queries TINYINT
    DECLARE	@varbackup_compression_default TINYINT
    DECLARE	@varclr_enabled TINYINT
    DECLARE	@varfilestream_access_level TINYINT
    DECLARE	@varMAXDOP TINYINT
    DECLARE	@varoptimize_for_ad_hoc_workloads TINYINT
    DECLARE	@varxp_cmdshell TINYINT
	DECLARE @varLast_Full_Backup_Timestamp DATETIME
	DECLARE @varLast_TLog_Backup_Timestamp DATETIME
	DECLARE @varLast_Full_Backup_Database_Name SYSNAME
	DECLARE @varLast_TLog_Backup_Database_Name SYSNAME
	DECLARE @varIP VARCHAR(48)
	DECLARE @varPort INT
    DECLARE @varOS_Version NVARCHAR(256)
    DECLARE @var_Parameters NVARCHAR(256) = N'@varOS_Version NVARCHAR(256) OUTPUT'
    DECLARE @varSQL_Text NVARCHAR(256) = 'SELECT @varOS_Version = host_distribution FROM sys.dm_os_host_info'

    IF (CAST(SERVERPROPERTY('ProductMajorVersion') AS TINYINT)> 13)
        BEGIN
            EXEC sp_executesql @varSQL_Text, @var_Parameters, @varOS_Version = @varOS_Version OUTPUT
        END

    EXEC master..xp_regread		N'HKEY_LOCAL_MACHINE',
							    N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\',
							    @value_name = 'Domain',
							    @value = @varDomain OUTPUT

    SELECT	@varDatabases_Count = COUNT(1)
    FROM	sys.databases 
    WHERE	[database_id] > 4

	SELECT	TOP 1 @varPort = local_tcp_port,
			@varIP = local_net_address
	FROM	sys.dm_exec_connections 
	WHERE	local_tcp_port IS NOT NULL
	AND		session_id IS NOT NULL;
	
    IF (CAST(SERVERPROPERTY('ProductMajorVersion') AS TINYINT) > 10)
	    BEGIN

			SELECT @varSQL_Command = 'SELECT @ct = CAST([committed_target_kb]/1024./1024. AS DECIMAL(32,0)), @pm= CAST([physical_memory_kb]/1024./1024. AS DECIMAL(32,0)) FROM sys.dm_os_sys_info'
			EXEC sp_executesql @varSQL_Command, N'@ct DECIMAL(10,2) OUTPUT, @pm DECIMAL(10,2) OUTPUT', @ct= @varCommitted_Target_GB OUTPUT, @pm= @varPhysical_Memory_GB OUTPUT
			
		    SELECT @varCPU_Count = [cpu_count],
		    @varSQL_Server_Start_Time = [sqlserver_start_time]
		    FROM sys.dm_os_sys_info
	    END
    ELSE
	    BEGIN
		    SELECT @varCPU_Count = [cpu_count],
		    @varSQL_Server_Start_Time = [sqlserver_start_time],
		    @varPhysical_Memory_GB = 0,
		    @varCommitted_Target_GB = 0
		    FROM sys.dm_os_sys_info
	    END

    SELECT	@varDatabases_Data_Size_GB = SUM(CAST((size*8)/1024./1024. AS DECIMAL(32,0)))
    FROM	sys.master_files 
    WHERE	[type] <> 1

    SELECT	@varDatabases_TLog_Size_GB = SUM(CAST((size*8)/1024./1024. AS DECIMAL(32,0)))
    FROM	sys.master_files 
    WHERE	[type] = 1

	--Get backup details
	IF(SERVERPROPERTY('IsHadrEnabled') = 1)
		BEGIN
			SELECT		TOP 1 
						@varLast_Full_Backup_Database_Name = [name], 
						@varLast_Full_Backup_Timestamp = DATEADD(S ,DATEDIFF (S, GETDATE(), GETUTCDATE()), ISNULL(backup_finish_date, 0))
			FROM		sys.databases [Database_Full_Backup_Timestamp]
			LEFT JOIN	(
							SELECT		a.[database_name], MAX(a.backup_finish_date) backup_finish_date
							FROM		msdb.dbo.backupset a
							WHERE		a.[type] = 'D'
							GROUP BY	a.[database_name]
						) a
					ON	[name] = a.[database_name]
			INNER JOIN	sys.database_mirroring
					ON	[Database_Full_Backup_Timestamp].database_id = sys.database_mirroring.database_id
			WHERE		[state] <> 6
			AND			[Database_Full_Backup_Timestamp].database_id <> 2
			AND			sys.fn_hadr_backup_is_preferred_replica([name]) = 1
			AND			(sys.database_mirroring.mirroring_role <> 2 or sys.database_mirroring.mirroring_role is null)
			ORDER BY	2

			SELECT		TOP 1 
						@varLast_TLog_Backup_Database_Name = [name], 
						@varLast_TLog_Backup_Timestamp = DATEADD(S ,DATEDIFF (S, GETDATE(), GETUTCDATE()), ISNULL(backup_finish_date, 0))
			FROM		sys.databases [Database_TLog_Timestamp]
			LEFT JOIN	(
							SELECT		a.[database_name], MAX(a.backup_finish_date) backup_finish_date
							FROM		msdb.dbo.backupset a
							WHERE		a.[type] = 'L'
							GROUP BY	a.[database_name]
						) a
					ON	[name] = a.[database_name]
			INNER JOIN	sys.database_mirroring
					ON	[Database_TLog_Timestamp].database_id = sys.database_mirroring.database_id 
			WHERE		[Database_TLog_Timestamp].recovery_model <> 3 
			AND			[state] = 0
			--AND			[Database_TLog_Timestamp].database_id <> 3 --ignore model
			AND			sys.fn_hadr_backup_is_preferred_replica([name]) = 1
			AND			(sys.database_mirroring.mirroring_role <> 2 or sys.database_mirroring.mirroring_role is null)
			ORDER BY	2
		END
	ELSE
		BEGIN
			SELECT		TOP 1 
						@varLast_Full_Backup_Database_Name = [name], 
						@varLast_Full_Backup_Timestamp = DATEADD(S ,DATEDIFF (S, GETDATE(), GETUTCDATE()), ISNULL(backup_finish_date, 0))
			FROM		sys.databases [Database_Full_Backup_Timestamp]
			LEFT JOIN	(
							SELECT		a.database_name, MAX(a.backup_finish_date) backup_finish_date
							FROM		msdb.dbo.backupset a
							WHERE		a.[type] = 'D'
							GROUP BY	a.database_name
						) a
					ON	[name] = a.database_name
			INNER JOIN	sys.database_mirroring
					ON	[Database_Full_Backup_Timestamp].database_id = sys.database_mirroring.database_id  
			WHERE		[state] <> 6
			AND			[Database_Full_Backup_Timestamp].database_id <> 2
			AND			(sys.database_mirroring.mirroring_role <> 2 or sys.database_mirroring.mirroring_role is null)
			ORDER BY	2

			SELECT		TOP 1 
						@varLast_TLog_Backup_Database_Name = [name], 
						@varLast_TLog_Backup_Timestamp = DATEADD(S ,DATEDIFF (S, GETDATE(), GETUTCDATE()), ISNULL(backup_finish_date, 0))
			FROM		sys.databases [Database_TLog_Timestamp]
			LEFT JOIN	(
							SELECT		a.database_name, MAX(a.backup_finish_date) backup_finish_date
							FROM		msdb.dbo.backupset a
							WHERE		a.[type] = 'L'
							GROUP BY	a.database_name
						) a
					ON	[name] = a.database_name
			INNER JOIN	sys.database_mirroring
					ON	[Database_TLog_Timestamp].database_id = sys.database_mirroring.database_id 
			WHERE		[Database_TLog_Timestamp].recovery_model <> 3 
			AND			[state] = 0
			--AND			[Database_TLog_Timestamp].database_id <> 3 --ignore model
			AND			(sys.database_mirroring.mirroring_role <> 2 or sys.database_mirroring.mirroring_role is null)
			ORDER BY	2
		END

	SET		@varFile_System_Storage = 
				    (SELECT		DISTINCT volume_mount_point as Drive,   
							    CAST(CAST(total_bytes/1024./1024./1024. AS DECIMAL(20,2)) AS INT) AS [Total_GB],   
							    CAST(CAST(available_bytes/1024./1024./1024. AS DECIMAL(20,2)) AS INT) AS [Free_GB]
				    FROM		sys.master_files AS f  
				    CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)  [File_System_Storage]
				    ORDER BY 1  
				    FOR XML AUTO, ELEMENTS)

    SELECT		@varSQL_Server_Service_Account = [service_account]
	FROM		sys.dm_server_services AS [SQL_Server_Services]
	WHERE		[filename]  LIKE '%sqlservr.exe%'

    SELECT	@varAd_Hoc_Distributed_Queries = CAST([value_in_use] AS BIT)
    FROM	[sys].[configurations] 
    WHERE	[name] = 'Ad Hoc Distributed Queries'
    SELECT	@varbackup_compression_default = CAST([value_in_use] AS BIT)
    FROM	[sys].[configurations] 
    WHERE	[name] = 'backup compression default'
    SELECT	@varclr_enabled = CAST([value_in_use] AS BIT)
    FROM	[sys].[configurations] 
    WHERE	[name] = 'clr enabled'
    SELECT	@varfilestream_access_level = CAST([value_in_use] AS TINYINT)
    FROM	[sys].[configurations] 
    WHERE	[name] = 'filestream access level'
    SELECT	@varMAXDOP = CAST([value_in_use] AS TINYINT)
    FROM	[sys].[configurations] 
    WHERE	[name] = 'max degree of parallelism'
    SELECT	@varoptimize_for_ad_hoc_workloads = CAST([value_in_use] AS BIT)
    FROM	[sys].[configurations] 
    WHERE	[name] = 'optimize for ad hoc workloads'
    SELECT	@varxp_cmdshell = CAST([value_in_use] AS BIT)
    FROM	[sys].[configurations] 
    WHERE	[name] = 'xp_cmdshell'

    SELECT	@varIP AS [SQL_Server_IP],
			ISNULL(@varPort, 0) AS [SQL_Server_Port],
			SERVERPROPERTY('ServerName') AS [Server_Name],
		    SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [Server_Host],
		    @varDomain AS [Server_Domain],
		    SERVERPROPERTY('Edition') AS [SQL_Server_Edition],
		    SERVERPROPERTY('ProductVersion') AS [SQL_Server_Version],
            @varOS_Version AS [OS_Version],
		    ISNULL(SERVERPROPERTY('IsClustered'),0) AS [Is_Clustered],
		    ISNULL(SERVERPROPERTY('IsHadrEnabled'),0) AS [Is_Hadr_Enabled],
		    @varDatabases_Count AS [User_Databases_Count],
            @varDatabases_Data_Size_GB AS [Databases_Data_Size_GB],
		    @varDatabases_TLog_Size_GB AS [Databases_TLog_Size_GB],
		    @varFile_System_Storage AS [File_System_Storage],
		    @varCPU_Count AS [CPU_Count],
		    @varPhysical_Memory_GB AS [Physical_Memory_GB],
		    @varCommitted_Target_GB AS [Committed_Target_GB],
            SERVERPROPERTY('Collation') AS [Collation],
		    @varLast_Full_Backup_Timestamp AS [Last_Full_Backup_Timestamp],
			@varLast_Full_Backup_Database_Name AS [Last_Full_Backup_Database_Name], 
			@varLast_TLog_Backup_Timestamp AS [Last_TLog_Backup_Timestamp],
			@varLast_TLog_Backup_Database_Name AS [Last_TLog_Backup_Database_Name],
			SERVERPROPERTY('InstanceDefaultDataPath') AS [Instance_Default_Data_Path],
			SERVERPROPERTY('InstanceDefaultLogPath') AS [Instance_Default_TLog_Path],
		    @varSQL_Server_Service_Account AS [SQL_Server_Service_Account],
		    @varSQL_Server_Start_Time AS [SQL_Server_Start_Time],
            @varAd_Hoc_Distributed_Queries AS [Ad_Hoc_Distributed_Queries],
            @varbackup_compression_default AS [Backup_Compression_Default],
            @varclr_enabled AS [CLR_Enabled],
            @varfilestream_access_level AS [Filestream_Access_Level],
            @varMAXDOP AS [MAXDOP],
            @varoptimize_for_ad_hoc_workloads AS [Optimize_for_ad_hoc_Workloads],
            @varxp_cmdshell AS [Xp_Cmdshell]
    GO
"@

#Tuncate existing old data before fresh capture
    Invoke-Sqlcmd -ServerInstance $varDBA_Server_Name -Database $varDBA_Database_Name -Query $varTruncate_Query

#Get a list of SQL Servers
    $varSQL_Servers = Invoke-Sqlcmd -ServerInstance $varDBA_Server_Name -Database $varDBA_Database_Name -Query $varGetSQL_Servers

#Loop through each SQL Server
    ForEach ($varSQL_Server in $varSQL_Servers)
        {
            try
                {
                    $varSQL_Server_Details = Invoke-Sqlcmd -ServerInstance $varSQL_Server.SQL_Server_Instance -Database $varTarget_Database_Name -Query $varGetSQL_Server_Details -ConnectionTimeout 5
                }
            catch
                {
                    $varError_Text = "********** Error connecting to: " + $varSQL_Server.SQL_Server_Instance + " **********"
                    Write-Host $varError_Text -ForegroundColor Yellow
                                        
                    $varSQL_Server_Details.SQL_Server_IP = ""
                    $varSQL_Server_Details.SQL_Server_Port = 0
                    $varSQL_Server_Details.Server_Name = "Login Failed!"
                    $varSQL_Server_Details.Server_Host = ""
                    $varSQL_Server_Details.Server_Domain = ""
                    $varSQL_Server_Details.SQL_Server_Edition = ""
                    $varSQL_Server_Details.SQL_Server_Version = ""
                    $varSQL_Server_Details.OS_Version = ""
                    $varSQL_Server_Details.Is_Clustered = 0
                    $varSQL_Server_Details.Is_Hadr_Enabled = 0
                    $varSQL_Server_Details.User_Databases_Count = 0
                    $varSQL_Server_Details.Databases_Data_Size_GB = 0
                    $varSQL_Server_Details.Databases_TLog_Size_GB = 0
                    $varSQL_Server_Details.CPU_Count = 0
                    $varSQL_Server_Details.Physical_Memory_GB = 0
                    $varSQL_Server_Details.Committed_Target_GB = 0
                    $varSQL_Server_Details.Collation = ""
                    $varSQL_Server_Details.Last_Full_Backup_Timestamp = "1899-01-01"
                    $varSQL_Server_Details.Last_Full_Backup_Database_Name = ""
                    $varSQL_Server_Details.Last_TLog_Backup_Timestamp = "1899-01-01"
                    $varSQL_Server_Details.Last_TLog_Backup_Database_Name = ""
                    $varSQL_Server_Details.Instance_Default_Data_Path = ""
                    $varSQL_Server_Details.Instance_Default_TLog_Path = ""
                    $varSQL_Server_Details.SQL_Server_Service_Account = ""
                    $varSQL_Server_Details.SQL_Server_Start_Time = "1899-01-01"
                    $varSQL_Server_Details.Ad_Hoc_Distributed_Queries = 0
                    $varSQL_Server_Details.Backup_Compression_Default = 0
                    $varSQL_Server_Details.CLR_Enabled = 0
                    $varSQL_Server_Details.Filestream_Access_Level = 0
                    $varSQL_Server_Details.MAXDOP = 0
                    $varSQL_Server_Details.Optimize_for_ad_hoc_Workloads = 0
                    $varSQL_Server_Details.Xp_Cmdshell = 0
                    $varSQL_Server_Details.File_System_Storage = ""
                }
           
            $varIns_SQL_Text =  "INSERT INTO [load].[tblSQL_Server_Details](" + 
                                            "[SQL_Server_Instance], " +
                                            "[SQL_Server_IP], " + 
                                            "[SQL_Server_Port], " + 
                                            "[Server_Name], " + 
                                            "[Server_Host], " +
                                            "[Server_Domain], " + 
                                            "[SQL_Server_Edition], " + 
                                            "[SQL_Server_Version], " + 
                                            "[OS_Version], " + 
                                            "[Is_Clustered], " + 
                                            "[Is_Hadr_Enabled], " + 
                                            "[User_Databases_Count], " + 
                                            "[Databases_Data_Size_GB], " + 
                                            "[Databases_TLog_Size_GB], " +                                             
                                            "[CPU_Count], " +                                             
                                            "[Physical_Memory_GB], " + 
                                            "[Committed_Target_GB], " + 
                                            "[Collation], " +
                                            "[Last_Full_Backup_Timestamp], " +
                                            "[Last_Full_Backup_Database_Name], " +
                                            "[Last_TLog_Backup_Timestamp], " +
                                            "[Last_TLog_Backup_Database_Name], " +
                                            "[Instance_Default_Data_Path], " +
                                            "[Instance_Default_TLog_Path], " +
                                            "[SQL_Server_Service_Account], " + 
                                            "[SQL_Server_Start_Time], " +
                                            "[Ad_Hoc_Distributed_Queries]," +
                                            "[Backup_Compression_Default]," +
                                            "[CLR_Enabled]," +
                                            "[Filestream_Access_Level]," +
                                            "[MAXDOP]," +
                                            "[Optimize_for_ad_hoc_Workloads]," +
                                            "[Xp_Cmdshell]," +                                            
                                            "[File_System_Storage]) " + 
                                        "VALUES " + 
                                        "('" + 
                                            $varSQL_Server.SQL_Server_Instance + "', '" + 
                                            $varSQL_Server_Details.SQL_Server_IP + "', " + 
                                            $varSQL_Server_Details.SQL_Server_Port +", '" + 
                                            $varSQL_Server_Details.Server_Name + "', '" + 
                                            $varSQL_Server_Details.Server_Host + "', '" + 
                                            $varSQL_Server_Details.Server_Domain + "', '" + 
                                            $varSQL_Server_Details.SQL_Server_Edition + "', '" + 
                                            $varSQL_Server_Details.SQL_Server_Version + "', '" + 
                                            $varSQL_Server_Details.OS_Version + "', " +
                                            $varSQL_Server_Details.Is_Clustered + ", " + 
                                            $varSQL_Server_Details.Is_Hadr_Enabled + ", " + 
                                            $varSQL_Server_Details.User_Databases_Count + ", " + 
                                            $varSQL_Server_Details.Databases_Data_Size_GB + ", " +
                                            $varSQL_Server_Details.Databases_TLog_Size_GB + ", " +
                                            $varSQL_Server_Details.CPU_Count + ", " +
                                            $varSQL_Server_Details.Physical_Memory_GB + ", " +
                                            $varSQL_Server_Details.Committed_Target_GB + ", '" +
                                            $varSQL_Server_Details.Collation + "', '" +
                                            $varSQL_Server_Details.Last_Full_Backup_Timestamp + "', '" +
                                            $varSQL_Server_Details.Last_Full_Backup_Database_Name + "', '" +
                                            $varSQL_Server_Details.Last_TLog_Backup_Timestamp + "', '" +
                                            $varSQL_Server_Details.Last_TLog_Backup_Database_Name + "', '" +
                                            $varSQL_Server_Details.Instance_Default_Data_Path + "', '" +
                                            $varSQL_Server_Details.Instance_Default_TLog_Path + "', '" +
                                            $varSQL_Server_Details.SQL_Server_Service_Account + "', '" +
                                            $varSQL_Server_Details.SQL_Server_Start_Time + "', " +
                                            $varSQL_Server_Details.Ad_Hoc_Distributed_Queries + ", " +
                                            $varSQL_Server_Details.Backup_Compression_Default + ", " +
                                            $varSQL_Server_Details.CLR_Enabled + ", " +
                                            $varSQL_Server_Details.Filestream_Access_Level + ", " +
                                            $varSQL_Server_Details.MAXDOP + ", " +
                                            $varSQL_Server_Details.Optimize_for_ad_hoc_Workloads + ", " +
                                            $varSQL_Server_Details.Xp_Cmdshell + ", '" +
                                            $varSQL_Server_Details.File_System_Storage +                                             
                                        "')" 
            #$varIns_SQL_Text
            
            #Insert SQL Server Details into the inventory table
            Invoke-Sqlcmd -ServerInstance $varDBA_Server_Name -Database $varDBA_Database_Name -Query $varIns_SQL_Text
        }


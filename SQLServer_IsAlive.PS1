cls

#Variable Declarations and Initiations
    [string]$varDBA_Server_Name ="SQL-Server-Name"
    [string]$varDBA_Database_Name = "DBA_Inventory"
    [string]$varTarget_Database_Name = "master"
    [string[]]$varSQL_Servers_Succeeded = New-Object System.Collections.ArrayList
    [string[]]$varSQL_Servers_Failed = New-Object System.Collections.ArrayList
    [int]$varCount_Succeeded = 0
    [int]$varCount_Failed = 0
    [string]$varSQL_Server_Name = ""
    [string]$varIns_SQL_Text = ""


    $varGetSQL_Servers =
@"
    SET NOCOUNT ON
    GO
    SELECT	[SQL_Server_Instance]
    FROM	[inventory].[tblSQL_Servers]
    WHERE	[Is_Active] = 1
    GO
"@
    $varGetIs_Alive =
@"
    SET NOCOUNT ON
    GO
    SELECT CAST(SERVERPROPERTY('servername') AS SYSNAME) AS [SQL_Server_Name], CAST(SERVERPROPERTY('ProductVersion') AS SYSNAME) AS [SQL_Server_Version]
    GO

"@

#Get a list of SQL Servers
    $varSQL_Servers = Invoke-Sqlcmd -ServerInstance $varDBA_Server_Name -Database $varDBA_Database_Name -Query $varGetSQL_Servers

#Loop through each SQL Server
    ForEach ($varSQL_Server in $varSQL_Servers)
        {
            $varProgress = 'Succeeded: ' + $varCount_Succeeded + ', Failed: ' + $varCount_Failed
            Write-Progress -Activity 'SQL Server Count' -Status $varProgress
            try
                {
                    $varIs_Alive = Invoke-Sqlcmd -ServerInstance $varSQL_Server.SQL_Server_Instance -Database $varTarget_Database_Name -Query $varGetIs_Alive -ConnectionTimeout 5
                    $varIs_Alive
                    $varSQ_Server_Name = $varCount_Succeeded.ToString() + ". " + $varSQL_Server.SQL_Server_Instance
                    $varSQL_Servers_Succeeded += $varSQ_Server_Name
                    $varCount_Succeeded += 1                    
                }
            catch
                {
                    $varError_Text = "********** Error connecting to: " + $varSQL_Server.SQL_Server_Instance + " **********"
                    Write-Host $varError_Text -ForegroundColor Yellow
                    $varSQ_Server_Name = $varCount_Failed.ToString() + ". " + $varSQL_Server.SQL_Server_Instance
                    $varSQL_Servers_Failed += $varSQ_Server_Name
                    $varCount_Failed += 1
                }
        }

#cls
Write-Host " "
Write-Host "************************" -ForegroundColor Green
Write-Host "| SQL Server Succeeded |" -BackgroundColor Green
Write-Host "************************" -ForegroundColor Green
$varSQL_Servers_Succeeded
Write-Host "------------------------" -ForegroundColor Green

Write-Host " "
Write-Host " "
Write-Host " "

Write-Host "*********************" -ForegroundColor Red
Write-Host "| SQL Server Failed |" -BackgroundColor Red
Write-Host "*********************" -ForegroundColor Red
$varSQL_Servers_Failed
Write-Host "---------------------" -ForegroundColor Red

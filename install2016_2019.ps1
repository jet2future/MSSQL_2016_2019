$Version = Read-Host -Prompt 'Input your version name equal Values are 2016 and 2019'
$edition = Read-Host -Prompt 'Input your edition name equal Values are "STD" for Standard Edition and "ENT" for Enterprise Edition'
$InstanceName = Read-Host -Prompt 'Input your Instance name or default value will be "MSSQLSERVER"'
if ($InstanceName -eq "") {
$InstanceName ="MSSQLSERVER"
}

#can be "SQLENGINE,RS,CONN,IS,BC,SDK"
$FEATURES = Read-Host -Prompt 'Input Features to be Installed possible Values "SQLENGINE,RS,CONN,IS,BC,SDK" default value will be "SQLENGINE,CONN,IS"'
if ($FEATURES -eq "") {
$FEATURES="SQLENGINE,CONN,IS"
}
Write-Output $Features

$collation = Read-Host -Prompt 'Input your collation name or default value will be "SQL_Latin1_General_CP1_CI_AS"'
if ($collation -eq "") {
$collation ="SQL_Latin1_General_CP1_CI_AS"
}

$TCPPort = Read-Host -Prompt 'Input your Port for instance or default value will be "1433"'
if ($TCPPort -eq "") {
$TCPPort ="1433"
}


$domain = Read-Host -Prompt 'Input your Domain name or default value will be "YOUR DOMAIN HERE"'
if ($domain -eq "") {
$domain ="YOUR DOMAIN HERE"
}


$serviceaccount = Read-Host -Prompt 'Input your Serviceaccount Username (eg. domain\username) if this is empty it will be Installed with System Accounts'
if ($serviceaccount -eq "") {
$SQLSVCAccount ="NT AUTHORITY\Network Service"
$AGTSVCACCOUNT ="NT AUTHORITY\System"
$RSSVCACCOUNT = "NT AUTHORITY\System"
$ISSVCACCOUNT="NT AUTHORITY\System"
}
else
{
$SQLSVCAccount ="$serviceaccount"
$AGTSVCACCOUNT ="$serviceaccount"
$RSSVCACCOUNT ="$serviceaccount"
$ISSVCACCOUNT="NT AUTHORITY\System"
}

if ($serviceaccount -ne "") {
$servicepwd = Read-Host -Prompt 'Input your Serviceaccount Password'
}
if ($servicepwd -ne "") {
$SQLSVCPASSWORD="$servicepwd"
$AGTSVCPASSWORD="$servicepwd"
$RSSVCPASSWORD="$servicepwd"
$ISSVCPASSWORD=""
$SAPWD="$servicepwd"
}
else{
$SQLSVCPASSWORD=""
$AGTSVCPASSWORD=""
$RSSVCPASSWORD=""
$ISSVCPASSWORD=""
}

$yourusername = Read-Host -Prompt 'Input your Sysadmin-Group or User default Value "YOUR DOMAIN HERE\admin"'
if ($yourusername -eq "") {
$yourusername ="YOUR DOMAIN HERE\admin"
$SQLSYSADMINACCOUNTS="$yourusername"
}
else{
$SQLSYSADMINACCOUNTS="$yourusername"
}


if ($serviceaccount -eq "") {
$SAPDW = Read-Host -Prompt 'Please provide an SA Password'
}





try{
  stop-transcript|out-null
}
catch [System.InvalidOperationException]{}
cls
New-Item -ItemType Directory -Force -Path D:\DBA\logs
Write-Output "$date Starting logging to file D:\DBA\logs\$InstanceName_00_SQL_install.txt "
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
$date = Get-Date -format "yyyyMMdd_HHmmss" 
$MainLog = "D:\DBA\logs\"+$InstanceName+$date+"_00_SQL_install.txt"
Start-Transcript -path $MainLog
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "################################################################################
                    SQL Server installation script
################################################################################
Installation started at $date 
On computer $env:computername
Script parameters: $version $edition $InstanceName $collation $TCPPort"

################################################################################
# Step 1: Validating input parameters
################################################################################
Write-Output "$date Validating input parameters"

if (($version -eq "2008R2") -or ($version -eq "2016") -or ($version -eq "2019"))
{
}
else
{

Write-Output "$date Missing parameter with version of SQL Server. Possible options are: 2016, 2019
################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}

if (($edition -eq "DEV") -or ($edition -eq "STD") -or ($edition -eq "ENT") -or ($edition -eq "ENT_core"))
{
}
else
{
Write-Output "$date Missing parameter with edition of SQL Server. Possible options are: DEV, STD, ENT, (ENT_Core only for 2016/2019)
################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}
if ($InstanceName)
{
}
else
{
Write-Output "$date Please provide Instance Name for SQL Server
################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}
if ($collation)
{
}
else
{
Write-Output "$date Missing parameter with collation of server. Please provide correct collation like SQL_Latin1_General_CP1_CI_AS, etc.
################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}
if ($TCPPort)
{
Write-Output "$date Step 1: completed - Script is going to install SQL Server $version $edition edition with Instance Name: $InstanceName using $TCPPort on $env:computername"

}
else
{
Write-Output "$date Step 2: failed
Please provide TCP Port for SQL Server
################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}

################################################################################
# Step 2: .Net framework 3.5 sp1 
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Checking if .NET 3.5 is installed"

$net_core_2016 = (Get-WindowsFeature -Name Net-Framework-Core).InstallState
$net_core_2019 = (Get-WindowsFeature -Name Net-Framework-Core).InstallState

if (($net_core_2016 -eq "Installed") -or ($net_core_2019 -eq $True))
{
$message = "Step2:.NET Framework 3.5 is installed on the server"
Write-Output $message
}
else
{
$message = "Step 2:.NET Framework 3.5 is missing on the server, please reach out to the Provisioning team and ask them to install .NET Framework 3.5"
Write-Output $message
exit
}
################################################################################
# Step 3: Disk alignment
################################################################################
 
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Checking disk aligment"

$wql = "SELECT Label, Blocksize, Name FROM Win32_Volume WHERE FileSystem='NTFS'"

$disk_block_sizes = (Get-WmiObject -Query $wql -ComputerName '.' | Where-Object {$_.Name -notmatch "C:?"})  | Where-Object {$_.Name -notmatch "System"}
($disk_block_sizes |  Where-Object {$_.BlockSize -eq "65536"}).Name

$disks_wrong = ($disk_block_sizes |  Where-Object {$_.BlockSize -ne "65536"}).Name
$disks_64k = ($disk_block_sizes |  Where-Object {$_.BlockSize -eq "65536"}).Name

if ($disks_64k -ne $null)
{
$message = "Step3:Following disks are correctly formated, please check if following disk are with letters D:, F:, L:, T:, U: or D:\SQLData, D:\SQLLog,D:\SQLDB"
Write-Output $message $disks_64k
}
else
{
$message = "Step3:Following disks are formatted incorrectly, please consider reformating following disk"
Write-Output $message, $disks_wrong 
exit
}
################################################################################
# Step 4: Define Source Path
################################################################################
$SQL=($version)
$SQL+=($edition)


if ($SQL -eq "2016STD"){$SQLsource="\\your source Path here\Deployment\MSSQL2016SE"}
elseif ($SQL -eq "2016ENT"){$SQLsource="\\your source Path here\Deployment\MSSQL2016EE"}
elseif ($SQL -eq "2019STD"){$SQLsource="\\your source Path here\Deployment\MSSQL2019SE"}
elseif ($SQL -eq "2019ENT"){$SQLsource="\\your source Path here\Deployment\MSSQL2019EE"}
$message = "Step4:Source directory will be $SQLsource"
Write-Output $message

if ($version -eq "2016"){$serviceaccount="NT Service\SSISTELEMETRY130"}
elseif ($version -eq "2019"){$serviceaccount="NT Service\SSISTELEMETRY150"}
$message = "Step4:System Servicaccount will be $serviceaccount"
Write-Output $message
################################################################################
# Step 5: Define Variables
################################################################################
# below variables are customizable
$folderpath="D:\DBA"
$inifile="$folderpath\ConfigurationFile.ini"
# path to the SQL media
$SQLInstallDrive = "D:"
# SQL memory
$SqlMemMin ="1024"
$SqlMemMax = Get-CimInstance win32_ComputerSystem | foreach {[math]::round($_.TotalPhysicalMemory /1MB -2048)}
# configurationfile.ini settings https://msdn.microsoft.com/en-us/library/ms144259.aspx
$ACTION="Install"
$ASCOLLATION="Latin1_General_CI_AS"
$ErrorReporting="False"
$SUPPRESSPRIVACYSTATEMENTNOTICE="False"
$IACCEPTROPENLICENSETERMS="False"
$ENU="True"
$QUIET="True"
$QUIETSIMPLE="False"
$UpdateEnabled="True"
$USEMICROSOFTUPDATE="False"
#can be "SQLENGINE,RS,CONN,IS,BC,SDK"
$FEATURES="SQLENGINE,CONN,IS"
$UpdateSource="MU"
$HELP="False"
$INDICATEPROGRESS="False"
$X86="False"
$INSTANCENAME=($InstanceName)
$INSTALLSHAREDDIR="$SQLInstallDrive\Program Files\Microsoft SQL Server"
$INSTALLSHAREDWOWDIR="$SQLInstallDrive\Program Files (x86)\Microsoft SQL Server"
$INSTANCEID=($InstanceName)
$RSINSTALLMODE="DefaultNativeMode"
$SQLTELSVCACCT="NT Service\SQLTELEMETRY"
$SQLTELSVCSTARTUPTYPE="Automatic"
$ISTELSVCSTARTUPTYPE="Automatic"
$ISTELSVCACCT=($serviceaccount)
$INSTANCEDIR="$SQLInstallDrive\Program Files\Microsoft SQL Server"
$AGTSVCSTARTUPTYPE="Automatic"
$ISSVCSTARTUPTYPE="Disabled"
$COMMFABRICPORT="0"
$COMMFABRICNETWORKLEVEL="0"
$COMMFABRICENCRYPTION="0"
$MATRIXCMBRICKCOMMPORT="0"
$SQLSVCSTARTUPTYPE="Automatic"
$FILESTREAMLEVEL="0"
$ENABLERANU="False"
$SQLCOLLATION=($collation)
$SQLSVCINSTANTFILEINIT="False"
$SQLTEMPDBFILECOUNT="1"
$SQLTEMPDBFILESIZE="8"
$SQLTEMPDBFILEGROWTH="64"
$SQLTEMPDBLOGFILESIZE="8"
$SQLTEMPDBLOGFILEGROWTH="64"
$ADDCURRENTUSERASSQLADMIN="True"
$TCPENABLED="1"
$NPENABLED="1"
$BROWSERSVCSTARTUPTYPE="Disabled"
$RSSVCSTARTUPTYPE="Automatic"
$IAcceptSQLServerLicenseTerms="True"
$SQLData="$SQLInstallDrive\SQLData\Databases"
$SQLLog="$SQLInstallDrive\SQLLog\Databases"
$TempDB="$SQLInstallDrive\TempDB\Databases"


# do not edit below this line

$conffile= @"
[OPTIONS]
Action="$ACTION"
ErrorReporting="$ERRORREPORTING"
Quiet="$Quiet"
Features="$FEATURES"
InstanceName="$INSTANCENAME"
InstanceDir="$INSTANCEDIR"
SQLSVCAccount="$SQLSVCACCOUNT"
SQLSVCPASSWORD="$SQLSVCPASSWORD"
SQLSysAdminAccounts="$SQLSYSADMINACCOUNTS"
SQLSVCStartupType="$SQLSVCSTARTUPTYPE"
AGTSVCACCOUNT="$AGTSVCACCOUNT"
AGTSVCPASSWORD="$AGTSVCPASSWORD"
AGTSVCSTARTUPTYPE="$AGTSVCSTARTUPTYPE"
RSSVCACCOUNT="$RSSVCACCOUNT"
RSSVCSTARTUPTYPE="$RSSVCSTARTUPTYPE"
ISSVCACCOUNT="$ISSVCACCOUNT" 
ISSVCSTARTUPTYPE="$ISSVCSTARTUPTYPE"
ASCOLLATION="$ASCOLLATION"
SQLCOLLATION="$SQLCOLLATION"
TCPENABLED="$TCPENABLED"
NPENABLED="$NPENABLED"
IAcceptSQLServerLicenseTerms="$IAcceptSQLServerLicenseTerms"
SQLTEMPDBDIR="$TempDB"
SQLUSERDBLOGDIR="$SQLLog"
SQLUSERDBDIR="$SQLData"
SAPWD="$SAPWD"
"@


# Check for Script Directory & file
if (Test-Path "$folderpath"){
 write-host "The folder '$folderpath' already exists, will not recreate it."
 } else {
mkdir "$folderpath"
}
if (Test-Path "$folderpath\ConfigurationFile.ini"){
 write-host "The file '$folderpath\ConfigurationFile.ini' already exists, removing..."
 Remove-Item -Path "$folderpath\ConfigurationFile.ini" -Force
 } else {

}
# Create file:
write-host "Creating '$folderpath\ConfigurationFile.ini'..."
New-Item -Path "$folderpath\ConfigurationFile.ini" -ItemType File -Value $Conffile


################################################################################
# Step 5: Install MSSQL server
################################################################################
Try
{
if (Test-Path $SQLsource){
 write-host "about to install SQL Server..." -nonewline
$fileExe =  "$SQLsource\setup.exe" 
$CONFIGURATIONFILE = "$folderpath\ConfigurationFile.ini"
& $fileExe  /CONFIGURATIONFILE=$CONFIGURATIONFILE
Write-Host "done!" -ForegroundColor Green
 } else {
write-host "Could not find the media for SQL Server..."
break
}}
catch
{write-host "Something went wrong with the installation of SQL Server, aborting."
break}

# start the SQL Server CU
if ($SQL -eq "2016STD"){$CUsource="\\your source Path here\Deployment\Update\SQLServer2016_LastUpdate.exe"}
elseif ($SQL -eq "2016ENT"){$CUsource="\\your source Path here\\Update\SQLServer2016_LastUpdate.exe"}
elseif ($SQL -eq "2019STD"){$CUsource="\\your source Path here\\Update\SQLServer2019_LastUpdate.exe"}
elseif ($SQL -eq "2019ENT"){$CUsource="\\your source Path here\Update\SQLServer2019_LastUpdate.exe"}
$message = "Step4:Source directory for Updates will be $CUsource"
Write-Output $message


$filepath="$CUsource"
if (!(Test-Path $filepath)){
}
 else {
write-host "found the SQL Server CU Installer"
}
# start the SQL Server CU installer
write-host "about to install SQL Server CU..." -nonewline
$Parms = " /quiet /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances"
$Prms = $Parms.Split(" ")
& "$filepath" $Prms | Out-Null
Write-Host "done!" -ForegroundColor Green


# Configure SQL memory 
write-host "Configuring SQL memory..." -nonewline

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
$SQLMemory = New-Object ('Microsoft.SqlServer.Management.Smo.Server') ("(local)")
$SQLMemory.Configuration.MinServerMemory.ConfigValue = $SQLMemMin
$SQLMemory.Configuration.MaxServerMemory.ConfigValue = $SQLMemMax
$SQLMemory.Configuration.Alter()
Write-Host "done!" -ForegroundColor Green
write-host ""

# Configure SQL memory
#$TCPCheck=($version)
#$TCPCheck+=($TCPPort)

#if ($TCPCheck -ne "20161433"){
#write-host "Configuring SQL TCPPort..." -nonewline
#stop-service -force $InstanceName ; \
#    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.MSSQLSERVER\$InstanceName\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value '' ; \
#    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.MSSQLSERVER\$InstanceName\supersocketnetlib\tcp\ipall' -name tcpport -value $TCPPort ; \
#start-service $InstanceName;\
#Write-Host "done!" -ForegroundColor Green
#}

#if ($TCPCheck -ne "20191433"){
#write-host "Configuring SQL TCPPort..." -nonewline
#stop-service -force $InstanceName ; \
#    set-itemproperty -path "HKLM:\software\microsoft\microsoft sql server\mssql15.MSSQLSERVER\$InstanceName\supersocketnetlib\tcp\ipall" -name tcpdynamicports -value '' ; \
#    set-itemproperty -path "HKLM:\software\microsoft\microsoft sql server\mssql15.MSSQLSERVER\$InstanceName\supersocketnetlib\tcp\ipall" -name tcpport -value $TCPPort ; \
#start-service $InstanceName;\
#Write-Host "done!" -ForegroundColor Green
#}
# exit script
write-host "Exiting script, goodbye."


################################################################################
# Step 17: Review summary
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Installation completed"
Stop-Transcript|out-null
Set-Location D:\DBA
notepad $MainLog

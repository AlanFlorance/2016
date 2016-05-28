<#
    The following scripts are examples from the European Powershell Conference 2016
    
    Track-Title: SQL-Server mit Powershell verwalten
    
    Author: Holger Voges
    web: www.netz-weise-it.training
    email: holger.voges(at)netz-weise.de
    twitter: @HolgerVoges

    Please keep track of my project to build an alternative Powershell-Module for SQL-Server
    based on SMO:
    http://www.netz-weise-it.training/weisheiten/tipps/item/323-zugriff-auf-sql-server-per-smo-mit-powershell-ohne-smo-installation.html
#>


#region SMO-Assemblys laden

# L�dt SMO-Assemblies - Nur notwendig, wenn sqlps nicht geladen wird

# Alte Variante, funktioniert zuverl�ssig mit der Funktion LoadWithPartialName
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')

# Aber Powershell 2.0 steht das Cmdlet Add-Type zur Verf�gung. Leider l�dt es nicht immer
# die aktuellste Version, wenn man den friendly-Name angibt, was zu Problemen f�hren kann
# Eine gute Beschreibung zu dem Thema gibt es hier: 
# http://www.madwithpowershell.com/2013/10/add-type-vs-reflectionassembly-in.html
Add-Type -AssemblyName 'Microsoft.SqlServer.Smo'

# Gibt man die Version der Assemblys an, klappt das Laden, allerdings ist man Versionsabh�ngig
# und der Code ist nicht selbsterkl�rend. 
# Hier die Version f�r SQL-Server 2008 (R2)
add-type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.SMOExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.SqlEnum, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
�
# und das Laden der SMO-Bibliotheken f�r SQL Server 2012
add-type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.Smo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.SMOExtended, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.SqlEnum, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
add-type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop

# geladene Assemblies kann man sich mit der Methode GetAssemblies() auflisten
[appdomain]::CurrentDomain.GetAssemblies() | Where-Object {$_.FullName -like '*sqlserver*'}

#endregion
�

#region Instanzen auflisten

# Alle verf�gbaren Instanzen auflisten mit der Methode EnumAvailableSqlServers
# Der �bergabewert $false gibt an, dass auch Instanzen im Netzwerk gesucht werden sollen.
# Die Suche im Netz geht �ber den SQL-Browser, der Port UDP1434 mu� also verf�gbar sein.  
$SQLInstanceName = [Microsoft.SqlServer.Management.Smo.SmoApplication]::EnumAvailableSqlServers($false) |
    Select-Object -Property name
$SQLInstanceName

# Eine weitere Variante, Instanzen im Netz auflisten
[System.Data.Sql.SqlDataSourceEnumerator]::Instance.GetDataSources()

#endregion

#region Serverinformationen

# Den Server referenzieren und in der Variablen $SQLSvr speichern
$SQLSvr = New-Object Microsoft.SqlServer.Management.Smo.Server $SQLInstanceName.Name
$SQLSvr

# Server Versionsinformationen
$SQLSvr.Information.VersionString
$SQLSvr.Information.ProductLevel
$SQLSvr.Information | out-gridview
$SQLSvr.Databases | Out-GridView
$SQLSvr | Get-Member

#endregion

#region Datenbank anlegen
# Eine neue Datenbank PSHDB mit Standard-Werten anlegen
$dbName = 'PSHDB'
$db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database($SQLSvr, $dbName)
# Die Methode Create() wird zum anlegen ben�tigt!
$db.Create()

#endregion

#region Datenbanken konfigurieren

$dbname = 'Adventureworks2012'
# Datenbank abfragen und Referenz speichern
$db = $SQLSvr.Databases[$dbName]
# Datenbankoptionen �ndern
$db.DatabaseOptions.AnsiNullsEnabled = $false
$db.DatabaseOptions.AnsiPaddingEnabled = $false

# Den aktuellen Bensitzer abfragen
$db.Owner

# Den Besitzer der Datenbank �ndern
# SetOwner braucht 2 Parameter: den Besitzer und die Option "overrideIfAlreadyUser"
$db.SetOwner('sa',$False)

# Datenbank-Zugriffsmodus �ndern
# Die 3 Modi hei�ten: multiple, restricted, single
$db.DatabaseOptions.UserAccess = [Microsoft.SqlServer.Management.Smo.DatabaseUserAccess]::Restricted
$db.Alter()

# Einige Optionen m�ssen direkt gesetzt werden
$db.AutoUpdateStatisticsEnabled = $true
$db.CompatibilityLevel = [Microsoft.SqlServer.Management.Smo.CompatibilityLevel]::Version90
$db.Alter()
# Datenbank auf NurLesend setzen
$db.DatabaseOptions.ReadOnly = $true
$db.Alter()

# Gr��e der Datenbank ermitteln abfragen
$db.DataSpaceUsage

# Datenbankinformationen erneut abfragen
$db.Refresh()

# Und die Testdatenbank wieder l�schen
$db.Drop()

#endregion

#region Server Verwalten

# Laufende Serverprozesse auflisten
$SQLSvr.EnumProcesses()

# Blockierte Prozesse auflisten
$SQLSvr.EnumProcesses() |
    Where-Object -Property BlockingSpid -NE -Value 0 |
    Select-Object -Property Name, Spid, Command, Status, Login, Database, BlockingSpid

# Alle Eintr�ge im Errorlog auslesen, die nach dem 31.05.2015 aufgetreten sind
$date = get-date -Year 2015 -Month 05 -Day 31
$SQLSvr.ReadErrorLog() |
    Where-Object Text -Like '*' |
    Where-Object LogDate -ge $date |
    Out-GridView

# Index-Fragementierung �berpr�fen

$databasename = 'AdventureWorks2012'
$database = $SQLSvr.Databases[$databasename]
$tableName = 'Person'
$schemaName = 'Person'
$table = $database.Tables |
	Where-Object {( $_. Schema -eq $schemaName ) -and ( $_.Name -eq $tableName )}
# MSDN:
# EnumFragmentation enumerates a list of
# fragmentation information for the index
# using the default fast fragmentation option.

# Reorganize / Rebuild aller Indizies abh�ngig von Fragmentierung und Pagesize

$Reorg = @{ UpperBoundary=5; LowerBoundary=0 } 
$pagelimit = 100
$ExcludedIndexType = 'PrimaryXmlIndex','SecondaryXmlIndex'
Foreach ( $Index in ( $table.Indexes | where-object { 
	    $ExcludedIndexType -Notcontains $_.IndexType }))
{
    $IndexFrag = $index.EnumFragmentation()
    If (( $IndexFrag.AverageFragmentation -ge $Reorg.LowerBoundary ) -and 
		    ( $IndexFrag.AverageFragmentation -le $Reorg.UpperBoundary ) -and
		    ( $IndexFrag.pages -ge $pagelimit ))
	    {
		    'Index {0} wird reorganisiert' -f $IndexFrag.Index_Name
		    $index.Reorganize()
	    }
	ElseIf (( $IndexFrag.AverageFragmentation -gt $Reorg.UpperBoundary ) -and
		    ( $IndexFrag.pages -ge $pagelimit ))
	    {
		    'Index {0} wird neu aufgebaut' -f $IndexFrag.Index_Name
		    $index.Rebuild()
	    }
}


# Datenbank reparieren
$databasename = 'AdventureWorks2012'
$database = $SQLSvr.Databases[$databasename]
#RepairType Values: AllowDataLost, Fast, None, Rebuild
$database.CheckTables([Microsoft.SqlServer.Management.Smo.RepairType]::None)

#endregion

#region SQL-Server Agent

# Alle Jobs auflisten
$SQLSvr.JobServer.Jobs | Select-Object -Property * 

# Datenbankmail aktivieren
$SQLSvr.Configuration.DatabaseMailEnabled.ConfigValue = 1
$SQLSvr.Configuration.Alter()
$SQLSvr.Refresh()

# Ein DB-Mail Konto anlegen
$accountName = 'DBMail'
$accountDescription = 'Database Mail'
$displayName = 'mail'
$emailAddress = 'sqlagent@bit-weise.de'
$replyToAddress = 'sqlagent@bit-weise.de'
$mailServerAddress = 'smtp.bit-weise.de'
$account = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Mail.MailAccount -ArgumentList $SQLSvr.Mail, $accountName, $accountDescription, $displayName, $emailAddress
$account.ReplyToAddress = $replyToAddress
# Achtung, der Account wird erst mit der Create()-Methode angelegt!
$account.Create()

# SQL-Server Jobs anlegen
$JobName = 'Recycle Errorlog'
if($SQLSvr.JobServer.Jobs[$jobName])
	{ $SQLSvr.JobServer.Jobs[$jobName].Drop() }
$job = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.Job -ArgumentList $SQLSvr.JobServer, $jobName
# Einen Operator angeben
$operator = $SQLSvr.JobServer.Operators['SQLAdmin']
$job.OperatorToEmail = $operator.Name
# Die Benachrichtiungsoption kann sein: Never, OnSuccess, OnFailure, Always
$job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
# Anlegen des Jobs wieder �ber die Create()-Methode
$job.Create()
# Den Job auf der lokalen Instanz anlegen
$job.ApplyToTargetServer($instanceName)
# Als n�chstes mu� ein Jobstep hinzugef�gt werden. 
$jobStep = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobStep($job, 'Cycle Error Log')
$jobStep.Subsystem = [Microsoft.SqlServer.Management.Smo.Agent.AgentSubSystem]::TransactSql
$jobStep.Command = 'Exec sp_cycle_errorlog'
$jobStep.OnSuccessAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::QuitWithSuccess
$jobStep.OnFailAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::QuitWithFailure
$jobStep.Create()

# Einen Job ausf�hren
$jobserver = $SQLSvr.JobServer
$jobname ='Cycle Error Log'
$job = $jobserver.Jobs[$jobname]
$job.Start()
# Warten, bis der Job beendet wurde und dann den Jobstatus ausgeben
while ( $job.CurrentRunStatus -eq 'Running') {start-sleep -Seconds 1}
$job.LastRunDate

#endregion



#region Verschl�sselung

# F�r die Verschl�sselung ist ein Master-Key notwendig, der einmalig 
# erstellt werden mu�
$masterdb = $SQLSvr.Databases['master']
if($masterdb.MasterKey -eq $null)
{
	$masterkey = New-Object Microsoft.SqlServer.Management.Smo.MasterKey -ArgumentList $masterdb
	$masterkey.Create('P@ssword')
	Write-Output "Master Key angelegt : $($masterkey.CreateDate)"
}

# Ein Zertifikat anlegen, �ber das der 
$certificateName = 'Test Certificate'
$masterdb = $SQLSvr.Databases['master']
if ($masterdb.Certificates[$certificateName])
	{
	 $masterdb.Certificates[$certificateName].Drop()
	}
$certificate = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Certificate -ArgumentList $masterdb,$certificateName
# Eigenschaften f�r das Zertifikat setze
$certificate.StartDate = 'August 01, 2015'
$certificate.Subject = 'Selbstsigniertes Zertifikat zur Verschl�sselung'
$certificate.ExpirationDate = 'August 01, 2020'
$certificate.Create()
# Das Zertifikat anzeigen
$certificate | Select-Object *

#endregion


#region Backups auflisten
# Von allen Datenbanken das letzte Backupdatum anzeigen
$SQLSvr.Databases |
	Select-Object Name, RecoveryModel, LastBackupDate, LastDifferentialBackupDate, LastLogBackupDate 
#endregion
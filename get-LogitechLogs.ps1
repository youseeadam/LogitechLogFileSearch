<#
.SYNOPSIS
    This script is used in conjuction with Azure Log Analytics. It creates a unique json file in the system temp directory.
    Push this file to each system you want to inventory via a Script Deploy in SCCM
    In Azure Log Analytics you pick up thei file and create a custom field mapping
    Becasue each log file is different a seperate json file must be created for each device.
    
.DESCRIPTION
    Using SCCM go to Software Library/Scripts-->Create Script
    Import the script and approve it
    then goto the Site Collection and Run Script
    From one of the systems the file was deployed to copy to a computer that can access Azure Log Analytics workspace
    logon to the Azure Log Anaylytics workspace (DO NOT use Edge, it has issues with field extractions)
    All Resources-->Resource Group Name-->Workspace Name-->Adavanced Settings
    Goto Data-->Custom Logs-->Add
    Click Choose File and Select the example file from your computer (this is only example file, and will not be used for actual data)
    Add to the Log Collection c:\windows\Temp\LogitechFirmware-[Smartdock|MeetUp|RallyCamera]*.json
    Give the log a name like SmartDock_CL
    To Verify the logs wait a few minutes and go to the Log Workspace and do the following query
    then extract fields as SDAIT_CF (SmartDockAIT)
    You can then create a query to extract the data
        SmartDock_CL | extend smartdock = parse_json(RawData) | project Computer,smartdock.NXP,smartdock.AIT,smartdock.NXPStatus,smartdock.AITStatus,smartdock.devicename
        MeetUp_CL | extend MeetUp = parse_json(RawData) | project Computer,MeetUp.ble,MeetUp.Audio,MeetUp.Video,MeetUp.eeprom,MeetUp.codec,MeetUp.devicename
        RallyCamera_CL | extend RallyCamera = parse_json(RawData) | project Computer,RallyCamera.video,RallyCamera.eeprom,RallyCamera.videoble,RallyCamera.devicename
        RallySystem_CL | extend RallySystem = parse_json(RawData) | project Computer,RallySystem.tablehub,RallySystem.TableHub_Valens,RallySystem.video,RallySystem.eeprom,RallySystem.videoble,RallySystem.tvhub,RallySystem.tvhubble,RallySystem.TVHub_Valens,RallySystem.micpod33

.NOTES
    Creates a JSON file of the format as example
    for SmartDock: File Name for ALA: c:\windows\temp\LogitechFirmware-*-SmartDock.json{, Content: "NXP":"2018.03.01.001","AIT":"0001.0001.0430","NXPStatus":"Failed","devicename":"SmartDock","AITStatus":"Failed"}
    Brio coming soon
    Becasue of limitations on ALA you cannot set a patch as c:\Windows\Temp\Logitech-*-SmartDock.json to the File Location

.EXAMPLE 
    Search-LogitechLogs.ps1
#>

#Get the Windows Temp Directory
$TempDir = [System.Environment]::GetEnvironmentVariable('TEMP', 'Machine')
$timestamp = (get-date -Format FileDateTime)

#Generate the SmartDock File
$SmartDockLog = $tempdir + "\" + "LogitechFirmware-SmartDock" + $timestamp + ".json"
$MeetupLog = $tempdir + "\" + "LogitechFirmware-MeetUp" + $timestamp + ".json"
$RallyCameraLog = $tempdir + "\" + "LogitechFirmware-RallyCamera" + $timestamp + ".json"
$RallySystemLog = $tempdir + "\" + "LogitechFirmware-RallySystem" + $timestamp + ".json"
#$BrioCameraLog = $tempdir + "\" + "LogitechFirmware-Brio" + $timestamp + ".json"

#User Profile Paths
$profiles = (get-wmiobject win32_userprofile -Property localpath -Filter "LocalPath like '%Users%'") | Select-Object localpath

<###############
SmartDock
################>
$smartdock=$null
$SerchStrings = "AIT Subsystem Package Version", "NXP Subsystem Package Version"
foreach ($profilepath in $profiles.localpath) {
    if (test-path ($profilepath + "\appdata\Local\Temp\SmartDockUpdate*.log")) {
        Write-Output "SmartDock"
        $smartdock=$true
        foreach ($fwupdate in get-childitem -path $TempDir -filter "SmartDockUpdate*.log" | Sort-Object LastWriteTime | Select-Object -Last 1) {
            foreach ($status in $SerchStrings) {
                $AIT = (Select-String -Path $fwupdate.FullName -Pattern 'AIT Subsystem Package Version *') | Select-Object -Last 1 | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
                $NXP = (Select-String -Path $fwupdate.FullName -Pattern 'NXP Subsystem Package Version *') | Select-Object -Last 1 | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
                $AITStatus = (Select-String -Path $fwupdate.FullName -Pattern 'AIT Subsystem Update *') | Select-Object -Last 1 | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
                $NXPStatus = (Select-String -Path $fwupdate.FullName -Pattern 'NXP Subsystem Update *') | Select-Object -Last 1 | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
            }
        }
        if ($smartdock) {
            New-Object psobject -Property @{devicename = "SmartDock"; AIT = ($AIT | convertFrom-csv)."P10"; NXP = (($NXP | convertFrom-csv)."P10"); AITStatus = ($AITStatus | ConvertFrom-Csv)."P8" -replace ":", ""; NXPStatus = ($NXPStatus | ConvertFrom-Csv)."P8" -replace ":", "" } | ConvertTo-Json -Compress | Out-File -FilePath $SmartDockLog -Encoding ascii -Append
        }
    }
}


<###############
Meetup
Nowhere in the log file does it tell the firmware version downloaded as it pertains to the website.
################>
$meetup=$null
$global:meetupfw = $null
$global:meetupfw = @{ }

function set-MeetupSettings {
    switch ($pattern) {
        "Info:      ble" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
            $global:meetupfw.add("ble", ($deviceinfo | convertFrom-csv)."P7")
        }
        "Info:      audio" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
            $global:meetupfw.add("audio", ($deviceinfo | convertFrom-csv)."P7")
        }
        "Info:      codec" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
            $global:meetupfw.add("codec", ($deviceinfo | convertFrom-csv)."P7")
        }
        "Info:      video" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String | ConvertTo-Csv -NoTypeInformation
            $global:meetupfw.add("video", ($deviceinfo | convertFrom-csv)."P8")
        }
        "Info:      eeprom" {
            #this one has to be handled different due to how the log is written. Doing it the same as the rest will return just the pre-decimal point value
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String  -Delimiter "`t" | ConvertTo-Csv -NoTypeInformation
            $global:meetupfw.add("eeprom", (($deviceinfo | convertFrom-csv)."P2" -split ": ")[1])
        }
    }
}

$fwupdates = "Info:      audio", "Info:      ble", "Info:      codec", "Info:      video", "Info:      eeprom"
foreach ($profilepath in $profiles.localpath) {
    $logpath = $null
    $logpath = ($profilepath + "\appdata\Local\Temp\LogiFWUpdate"), ($tempdir + "\LogiFWUpdate")
    foreach ($logfile in $logpath) {
        if (test-path $logfile) {
            foreach ($fwupdate in get-childitem -path $logfile -Filter FWUpdateMeetup*.log | Sort-Object LastWriteTime | Select-Object -last 1) {
                write-output "Meetup"
                $meetup=$true
                foreach ($pattern in $fwupdates) {
                    foreach ($deviceinfo in Select-String -Path $fwupdate.FullName -Pattern $pattern) {
                        set-MeetupSettings
                    }              
                }
            }
        }
    }
}
if ($meetup) {
    $global:meetupfw.add("devicename", "MeetUp")
    $global:meetupfw | ConvertTo-Json -Compress | Out-File -FilePath $MeetupLog -Encoding ascii
}
<##############
Rally Camera
################>
$global:rallycamerafw = $null
$global:rallycamerafw = @{ }
$rallycamera=$null
function set-RallyCameraSettings {
    switch ($pattern) {
        "Info:      video" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String  -Delimiter "`t" | ConvertTo-Csv -NoTypeInformation
            $global:rallycamerafw.add("video", (($deviceinfo | convertFrom-csv)."P2" -split ": ")[1])
        }
        "Info:      eeprom" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t" | ConvertTo-Csv -NoTypeInformation
            $global:rallycamerafw.add("eeprom", (($deviceinfo | convertFrom-csv)."P2" -split ": ")[1])
        }
        "Info:      videoble" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t" | ConvertTo-Csv -NoTypeInformation
            $global:rallycamerafw.add("videoble", (($deviceinfo | convertFrom-csv)."P2" -split ": ")[1])
        }
    }
}

$fwupdates = "Info:      video", "Info:      eeprom", "Info:      codec", "Info:      videoble"
foreach ($profilepath in $profiles.localpath) {
    $logpath = $null
    $logpath = ($profilepath + "\appdata\Local\Temp\LogiFWUpdate"), ($tempdir + "\LogiFWUpdate")
    foreach ($logfile in $logpath) {
        if (test-path $logfile) {
            foreach ($fwupdate in get-childitem -path $logfile -Filter FWUpdateRallyCamera*.log | Sort-Object LastWriteTime | Select-Object -last 1) {
                write-output "RallyCamera"
                $rallycamera=$true
                foreach ($pattern in $fwupdates) {
                    foreach ($deviceinfo in Select-String -Path $fwupdate.FullName -Pattern $pattern | Select-Object -Last 1) {
                        set-RallyCameraSettings
                    }              
                }
            }
        }
    }
}
if ($rallycamera) {
    $global:rallycamerafw.add("devicename", "RallyCamera")
    $global:rallycamerafw | ConvertTo-Json -Compress | Out-File -FilePath $RallyCameraLog -Encoding ascii
}
<###############
Rally System
################>
$global:rallysystemfw = $null
$global:rallysystemfw = @{ }
$rallysystem=$null
function set-RallySystemSettings {
    switch ($pattern) {
        "Info:      tablehub" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String  -Delimiter "`t" 
            $global:rallysystemfw.add("tablehub", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      TableHub_Valens" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t" 
            $global:rallysystemfw.add("TableHub_Valens", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      video" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t"
            $global:rallysystemfw.add("video", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      eeprom" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t"
            $global:rallysystemfw.add("eeprom", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      videoble" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t"
            $global:rallysystemfw.add("videoble", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      tvhub" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t"
            $global:rallysystemfw.add("tvhub", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      tvhubble" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t"
            $global:rallysystemfw.add("tvhubble", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      TVHub_Valens" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t"
            $global:rallysystemfw.add("TVHub_Valens", (($deviceinfo)."P2" -split ": ")[1])
        }
        "Info:      micpod 33" {
            $deviceinfo = Get-Content $fwupdate.FullName | Select-Object -Index ($deviceinfo.linenumber + 1) | ConvertFrom-String -Delimiter "`t" 
            $global:rallysystemfw.add("micpod33", (($deviceinfo)."P2" -split ": ")[1])
        }
    }
}

$fwupdates = "Info:      tablehub", "Info:      TableHub_Valens", "Info:      video", "Info:      eeprom", "Info:      videoble", "Info:      tvhub", "Info:      tvhubble", "Info:      TVHub_Valens", "Info:      micpod 33"
foreach ($profilepath in $profiles.localpath) {
    $logpath = $null
    $logpath = ($profilepath + "\appdata\Local\Temp\LogiFWUpdate"), ($tempdir + "\LogiFWUpdate")
    foreach ($logfile in $logpath) {
        if (test-path $logfile) {
            foreach ($fwupdate in get-childitem -path $logfile -Filter FWUpdateRally*.log | Sort-Object LastWriteTime | Select-Object -last 1) {
                write-output "RallySystem"
                $rallysystem=$true
                foreach ($pattern in $fwupdates) {
                    foreach ($deviceinfo in Select-String -Path $fwupdate.FullName -Pattern $pattern | Select-Object -Last 1) {
                        set-RallySystemSettings
                    }              
                }
            }
        }
    }
}

if ($rallysystem) {
    $global:rallysystemfw.add("devicename", "RallySystem")
    $global:rallysystemfw | ConvertTo-Json -Compress | Out-File -FilePath $RallySystemLog -Encoding ascii
}

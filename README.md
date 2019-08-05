# LogitechLogFileSearch
Searches Logitech Log files for firmware update status.
<p></p>
This will search your system for the following Logitech Devices" MeetUp, Rally Camera, SmartDock.<br />
It will then save the files to a JSON File in one of the following names in System Windows Temp. * is a date/time format<br />
  <blockquote>
  LogitechFirmware-MeetUp*.json<br />
  LogitechFirmware-RallyCamera*.json<br />
  LogitechFirmware-SmartDock*.json<br />
  </blockquote>
  <p>
The JSON files are designed to work with Azure Log Analytics Services.
  </p>
  
# The Scheuled Task
<p></p>
The Scheduled Task does the following:
<ol>
  <li>Creates a Directory c:\Scripts</li>
  <li>Copies the PowerShell Script from a shared location that the machine can access</li>
  <li>Executes the PowerShell Script</li>
  </ol>
The scheduled task is designed to run at logon.  You can import the schedulted task onto an admin computer. Most common changes are the following:
<ul>
  <li>Action: The Path to where the PowerShell script is stored. It it is set to c:\Scripts\*.ps1.  If you place it in a different location, you will need to change the -file parameter to match</li>
  <li>Triggers: You can set this to whatever.  If you want to manually trigger it later, you can set the trigger to be one time in the past</li>
  <li>The Copy from location in the Actions
</ul>

# Importing the Scheduled Task with Batch Scripting
<p></p>
<ul>
  <li> The roomsystems-scheduled.txt is a text file of each room requring the script to be run, each room per line, FQDN or NetBios name</li>
  <li> The person running this script must have admin access on the remote machine. If the machines are not on a domain, you can add the /RU /RP commands to show the Runas and RunasPassword on the local machine</li>
  <li> The XML file must also be accessible to the machine</li>
  </ul>
  To Import the XML file for Scheduled Tasks
  <blockquote>
  for /F  %%A in (c:\scripts\roomsystems-scheduled.txt) do schtasks /create /s %%A /RP P@ssword! /TN "Generate JSON for Azure Log Analytics" /XML <pathto> Generate JSON for Azure Log Analytics.xml
  </blockquote>
  
# Executing the Scheduled Task
for /F  %%A in (c:\scripts\roomsystems-scheduled.txt) do schtasks /run /s %%A /TN "Generate JSON for Azure Log Analytics" 

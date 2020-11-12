# powerfront
SCCM OSD frontend

A customizable front end for use in SCCM OSD zero or light touch deployments, based on XAML forms, WMI queries, configmgr webservices and SCCM task sequence integration. 
By using powershell during the start of a OSD task sequence it is possible to dynamically fill all OSD variables and present the end user with a wide range of options in a single input screen and single task sequence.

In the example powershell file the user can select a OS version, fill in a computername and select a location / OU before continuing the task sequence.
If the computer is already a member of the selected domain the current computername will be filled in and locked to prevent duplicate computeraccounts.

# prerequisites 
- configmgr webservices https://msendpointmgr.com/configmgr-webservice/
- serviceui.exe from MDT tools package

# installation
1. Install the webservice on a domain joined web server (management point or siteserver is fine), instructions found in the download.
2. Create a package of the root structure of powerfront in SCCM an make sure that it is distributed to all desired distribution points.
3. Add the following options to the required boot file.
    - Windows Powershell (WInPE-Powershell)
    - Windows Powershell (WinPE-DismCmdlets)
    - Windows Powershell (WinPE-StorageWMI)
    - Network (WinPE-Dot3Svc)
    - HTML (WinPE-HTA)
    - File Management (WinPE-FMAPI)
    - Microsoft .NET (WinPE-NetFx)
    - Storage (WinPE-EnhancedStorage)
    - Microsoft Secure Boot CmdLets (WinPE-SecureBootCmdlets)
4. Create a software package containing the Powerfront source files.

5. create a "run commandline" step in the task sequence directly after disk provisioning
  commandline:<br>
  <code>ServiceUI.exe -process:TSProgressUI.exe %SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File Powerfrontv2.ps1</code>

[x] disable 64-bit file system redirection<br>
[x] Package [ the created powerfront package ]<br>


# Powerfront file and folder structure:

- file - powerfront.ps1 - main script file.
- file - mainwindow.xaml - front end design ui.
- file - ServiceUI.exe - MDT serviceui executable (x86) to start powershell within the OSD PE environment and exposing the task sequence variables to powershell
- folder - images - used to store logo and background images.


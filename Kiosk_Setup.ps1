﻿# Created By Adam Waszczyszak
# Version 1.0

$host.ui.RawUI.WindowTitle = “MSShell for Kiosk by Adam Waszczyszak”
# Scripts Disabled Bypass from CMD: powershell -ExecutionPolicy Bypass -File "C:\Temp\MSShell.ps1"
# Might need to update local group policy if the bypass does not work.

# Self-check for admin rights, and ask for perms if launched not as admin (from Superuser.com)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}

# Clear Screen after admin check
Clear-Host

# Menu from StackOverflow
Function MenuMaker{
    param(
        [parameter(Mandatory=$true)][String[]]$Selections,
        [switch]$IncludeExit,
        [string]$Title = $null
        )

    $Width = if($Title){$Length = $Title.Length;$Length2 = $Selections|%{$_.length}|Sort -Descending|Select -First 1;$Length2,$Length|Sort -Descending|Select -First 1}else{$Selections|%{$_.length}|Sort -Descending|Select -First 1}
    $Buffer = if(($Width*1.5) -gt 78){[math]::floor((78-$width)/2)}else{[math]::floor($width/4)}
    if($Buffer -gt 6){$Buffer = 6}
    $MaxWidth = $Buffer*2+$Width+$($Selections.count).length+2
    $Menu = @()
    $Menu += "╔"+"═"*$maxwidth+"╗"
    if($Title){
        $Menu += "║"+" "*[Math]::Floor(($maxwidth-$title.Length)/2)+$Title+" "*[Math]::Ceiling(($maxwidth-$title.Length)/2)+"║"
        $Menu += "╟"+"─"*$maxwidth+"╢"
    }
    For($i=1;$i -le $Selections.count;$i++){
        $Item = "$(if ($Selections.count -gt 9 -and $i -lt 10){" "})$i`. "
        $Menu += "║"+" "*$Buffer+$Item+$Selections[$i-1]+" "*($MaxWidth-$Buffer-$Item.Length-$Selections[$i-1].Length)+"║"
    }
    If($IncludeExit){
        $Menu += "║"+" "*$MaxWidth+"║"
        $Menu += "║"+" "*$Buffer+"X - Exit"+" "*($MaxWidth-$Buffer-8)+"║"
    }
    $Menu += "╚"+"═"*$maxwidth+"╝"
    $menu
}

# Disable download progress bar increases download speed significantly.
$ProgressPreference = 'SilentlyContinue'

function Start-Menu{
    MenuMaker -Selections 'Create local Admin account (recommended to do this first)', 
    'Automatic',
    'Manual' -Title 'Kiosk Setup Automatic or Manual' 
}

Start-Menu

$startMenu = Read-Host "Automatic or Manual"

if($startMenu -eq 1){

    #Paolo Frigo, https://www.scriptinglibrary.com

    function Create-NewLocalAdmin {
        [CmdletBinding()]
        param (
            [string] $NewLocalAdmin,
            [securestring] $Password
        )    
        begin {
        }    
        process {
            New-LocalUser "$NewLocalAdmin" -Password $Password -FullName "$NewLocalAdmin" -Description "Temporary local admin"
            Write-Verbose "$NewLocalAdmin local user created"
            Add-LocalGroupMember -Group "Administrators" -Member "$NewLocalAdmin"
            Write-Verbose "$NewLocalAdmin added to the local administrator group"
        }    
        end {
        }
    }
    $NewLocalAdmin = Read-Host "New local admin username:"
    $Password = Read-Host -AsSecureString "Create a password for $NewLocalAdmin"
    Create-NewLocalAdmin -NewLocalAdmin $NewLocalAdmin -Password $Password -Verbose
    exit 
}

if($startMenu -eq 2){

    if (Test-Path -Path C:\Temp){
     "Temp Folder Already Exists"
    }

     else{
         New-Item -Path C:\Temp -ItemType Directory
     }

     if (Test-Path -Path C:\Visitor_pic){
         "Visitor_Pic Folder Already Exists"
     }

     else{
         New-Item -Path C:\Visitor_pic -ItemType Directory
     }

     'Folders Created.'
 
     $path=Get-Acl -Path C:\Temp
     $acl=New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule ('BUILTIN\Users','FullControl','ContainerInherit, ObjectInherit','None','Allow')
     $path.setaccessrule($acl)
     Set-Acl -Path C:\Temp\ -AclObject $path


     $path=Get-Acl -Path C:\Visitor_pic
     $acl=New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule ('BUILTIN\Users','FullControl','ContainerInherit, ObjectInherit','None','Allow')
     $path.setaccessrule($acl)
     Set-Acl -Path C:\Visitor_pic\ -AclObject $path

     "Permissions for Temp and Visitor_Pics Set!"

     $path=Get-Acl -Path C:\ProgramData\PTI
     $acl=New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule ('BUILTIN\Users','FullControl','ContainerInherit, ObjectInherit','None','Allow')
     $path.setaccessrule($acl)
     Set-Acl -Path C:\ProgramData\PTI\ -AclObject $path

     "PTI Folder Permissions Set!"

     'Have to manually disable S-Mode, luanching Microsoft Store...'
     Start-Process ms-windows-store://pdp/?productid=9nffmgm4vkkd

     'Installing PS Module...'
     Install-Module PSWindowsUpdate
     'Installing all newest Windows Updates'
     Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
     Install-WindowsUpdate

     'Done, remember to restart later!'

     'Enabling Rotation Lock using Registry.'
     Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AutoRotation -Name Enable -Value 0 -Type DWord
     'Done!'

     'Disabling Notifications using Registry.'
     New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows" -Name "Explorer" -force
     New-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -PropertyType "DWord" -Value 1
     New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -PropertyType "DWord" -Value 0
     'Done!'

     $regContent = @"
     Windows Registry Editor Version 5.00
     ;Disable IE11 Welcome Screen
     [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Internet Explorer\Main]
     "DisableFirstRunCustomize"=dword:00000001 
"@

     # Create a temporary .reg file
     $tempFile = New-TemporaryFile 
     $tempFile.FullName 
     $regContent | Out-File -FilePath $tempFile.FullName -Encoding ASCII

     # Import the registry settings
     reg.exe import $tempFile.FullName

     # Clean up the temporary file
     Remove-Item $tempFile.FullName   

     'Parsing download site...'

     # Retrieve the HTML content of the website
     $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/5da99203-21ba-4aa2-93e6-a60a8a0b3ae3"
     # Extract the text content from the parsed HTML
     $text = $response.ParsedHtml.body.innerText
 
     'Downloading...'

     $Destination = "C:\Temp\adobe.exe" 
     Invoke-WebRequest -Uri $text -OutFile $Destination

     "Launching Adobe with silent installer params..."
     Start-Process -FilePath "C:\Temp\adobe.exe" -ArgumentList -sAll
     "Success!"

     'Parsing download site...'
     # Download HF driver
     # Retrieve the HTML content of the website
     $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/c862d6fc-fc72-4e77-8347-ab079c8d4fa3"
     # Extract the text content from the parsed HTML
     $text = $response.ParsedHtml.body.innerText
 
     'Downloading driver...'

     $Destination = "C:\Temp\Zebra_CoreScanner_Driver.exe" 
     Invoke-WebRequest -Uri $text -OutFile $Destination
     "Launching Hands Free Scanner with silent installer params..."
     Start-Process -FilePath "C:\Temp\Zebra_CoreScanner_Driver.exe" -ArgumentList "/S", "/v/qn"
     "Success!"

     'Downloading Restore Default PDF...'

     $Destination = "C:\Temp\KioskPDF.pdf" 
     Invoke-WebRequest -Uri $text -OutFile $Destination
    # Retrieve the HTML content of the website
    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/0958c824-3f1e-42b3-89d1-c29a88efe9c2"
    # Extract the text content from the parsed HTML
    $text = $response.ParsedHtml.body.innerText  
    
    'Parsing download site...'

    # Retrieve the HTML content of the website
    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/1ab37806-4228-4eb1-8178-1ba492b0ea0f"
    # Extract the text content from the parsed HTML
    $text = $response.ParsedHtml.body.innerText

    'Downloading...'

    $Destination = "C:\Temp\DCDSetup1.4.5.1.exe" 
    Invoke-WebRequest -Uri $text -OutFile $Destination

    "Launching DYMO 550 driver with silent installer params..."
    Start-Process -FilePath "C:\Temp\DCDSetup1.4.5.1.exe" -ArgumentList "/S", "/v/qn"
    "Success!"

    'Parsing download site...'
            
    # Retrieve the HTML content of the website
    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/6ffe0dbd-c7cd-4206-a960-b2231fd4bd34"
    # Extract the text content from the parsed HTML
    $text = $response.ParsedHtml.body.innerText

    'Downloading...'
       
    $Destination = "C:\Temp\kiosk.zip" 
    Invoke-WebRequest -Uri $text -OutFile $Destination
    'Uncompressing...'
    Expand-Archive -LiteralPath 'C:\Temp\kiosk.zip' -DestinationPath C:\
    'Adding to startup...'

    $shortcutPath = "C:\v2.4_14vp\MS Shift Kiosk.lnk"
    $startupPath = [Environment]::GetFolderPath("Startup")

    Copy-Item $shortcutPath -Destination $startupPath 
    'Added to startup!'

    'Disabling Rear Camera...'
    Get-PnpDevice -FriendlyName "*Microsoft Camera Rear*" | Disable-PnpDevice -Confirm:$false
    'Camera Disabled!'

    'Editing power plan settings...'
    Powercfg /Change monitor-timeout-ac 0
    Powercfg /Change monitor-timeout-dc 0
    Powercfg /Change standby-timeout-ac 0
    Powercfg /Change standby-timeout-dc 0
    'Power plan saved!'

    $batchContent = @"
@echo off
net stop spooler
ping -n 4 127.0.0.1 > nul 
echo Deleting Print Queue...
del %systemroot%\System32\spool\printers\* /Q
echo Queue Deleted.
net start spooler
"@

$vbsContent = @"
CreateObject("Wscript.Shell").Run "C:\Temp\QueueDeletion.bat",0,True
"@

        $batchFilePath = "C:\Temp\QueueDeletion.bat"
        $batchContent | Out-File -FilePath $batchFilePath -Encoding ascii
        "Batch File created in Temp folder..."

        "Creating VBS for silent launch..."
        $vbsFilePath = "C:\Temp\QueueDeletion.vbs"
        $vbsContent | Out-File -FilePath $vbsFilePath -Encoding ascii
        "VBS File created in Temp folder..."

        "Creating Scheduled Task..."
        $action = New-ScheduledTaskAction -Execute "C:\Temp\QueueDeletion.vbs"
        $trigger = New-ScheduledTaskTrigger -Daily -At 11:30AM
        Register-ScheduledTask -TaskName "Print Queue Deletion Task" -Action $action -Trigger $trigger -AsJob -Force -RunLevel Highest

        # Ensure Edge key exists
        $EdgeHome = 'HKCU:\Software\Policies\Microsoft\Edge'
        If ( -Not (Test-Path $EdgeHome)) {
        New-Item -Path $EdgeHome | Out-Null
        }
        # Set RestoreOnStartup value entry
        $IPHT = @{
        Path   = $EdgeHome 
        Name   = 'RestoreOnStartup' 
        Value  = 4 
        Type   = 'DWORD'
        }
        Set-ItemProperty @IPHT -verbose
        # Create Startup URL's registry key
        $EdgeSUURL = "$EdgeHome\RestoreOnStartupURLs"
        If ( -Not (Test-Path $EdgeSUURL)) {
        New-Item -Path $EdgeSUURL | Out-Null
        }
        # Create a single URL startup page
        $HOMEURL = 'https://msshift.webex.com'
        Set-ItemProperty -Path $EdgeSUURL -Name '1' -Value $HomeURL

        'Removing all drivers...'

        if(Test-Path "C:\Temp\kiosk.zip" ){
             Remove-Item "C:\Temp\kiosk.zip"
            'Kiosk files deleted!'
        }

        if(Test-Path "C:\Temp\MSShift.DevicesAPI.Setup.NEW.msi"){
             Remove-Item "C:\Temp\MSShift.DevicesAPI.Setup.NEW.msi"
        }

        if(Test-Path "C:\Temp\adobe.exe"){
             Remove-Item "C:\Temp\adobe.exe"
             'Adobe files removed!'
        }

        if(Test-Path "C:\Temp\sigplus_.exe"){
             Remove-Item "C:\Temp\sigplus_.exe"
             'Signature Pads files removed!'
        }

        if(Test-Path "C:\Temp\Zebra_CoreScanner_Driver.exe"){
             Remove-Item "C:\Temp\Zebra_CoreScanner_Driver.exe"
             'Scanner files removed!'
        }

        if(Test-Path "C:\Temp\Restore Default.pdf"){
             Remove-Item "C:\Temp\Restore Default.pdf"
             'PDFs Removed!'
        }

        if(Test-Path "C:\Temp\ScanX_Config_Codebar.pdf"){
             Remove-Item "C:\Temp\ScanX_Config_Codebar.pdf"
        }

        if(Test-Path "C:\Temp\Zebra123_CoreScanner_Driver.exe" ){
             Remove-Item "C:\Temp\Zebra123_CoreScanner_Driver.exe"
             'Scanner files removed!'
        }

        if(Test-Path "C:\Temp\Primera.2.3.1.exe"){
             Remove-Item "C:\Temp\Primera.2.3.1.exe"  
             'LX 500 files removed!'
        }

        if(Test-Path "C:\Temp\DCDSetup1.4.5.1.exe"){
             Remove-Item "C:\Temp\DCDSetup1.4.5.1.exe"
             'DYMO files removed!'  
        }

        
        if(Test-Path "C:\Temp\DCDSetup1.3.2.18.exe"){
             Remove-Item "C:\Temp\DCDSetup1.3.2.18.exe"  
             'DYMO files removed!'
        }
                    
        if(Test-Path "C:\Temp\zd51.exe"){
             Remove-Item "C:\Temp\zd51.exe"  
             'ZD files removed!'
        }

        if(Test-Path "C:\Temp\zd.exe"){
             Remove-Item "C:\Temp\zd.exe"  
             'ZD files removed!'
        }

        if(Test-Path "C:\Temp\zd105.exe"){
             Remove-Item "C:\Temp\zd105.exe" 
             'ZD files removed!' 
        }

        if(Test-Path "C:\Temp\ZXP73.0.2.exe"){
             Remove-Item "C:\Temp\ZXP73.0.2.exe"  
             'ZXP-7 files removed!'
        }
        'Temp folder cleaned!'
}



if($startMenu -eq 3){
# Function for the Menu creation
function Print-Menu{
    MenuMaker -Selections 'Create Temp and Visitor_pics Folders', #1
    'Set Temp and Visitor_Pics Permissions', #2
    'Set PTI Folder Permissions', #3
    'Block DYMO Updates', #4
    'Block Adobe Auto-Update Service', #5 
    'Disable S-Mode', #6
    'Download and Install Windows Updates', #7
    'Enable Rotation Lock', #8
    'Disable Notifications', #9
    'Driver download and install menu', #10
    'Microsoft Edge Registry Patch (Edge Engine Error)', #13
    'Delete drivers from Temp', #16
    'Disable Windows Updates', #17
    'Silent Install Menu', #18
    'Create silent print queue deletion task.' -Title 'Choose a Function (Type "menu" to reload)' -IncludeExit
}

Print-Menu

# Function to reset console per command
function Console-Reset{
    Clear-Host
    Print-Menu
}

$MenuChoice = Read-Host "Choose an option"

while($MenuChoice -ne 'X'){

    if($MenuChoice -eq "menu"){
            Console-Reset
    }

    if($MenuChoice -eq 'X'){
        Write-Output "Exiting Menu..."
        break
        exit
    }

    if($MenuChoice -eq 1){
        
        Console-Reset
           if (Test-Path -Path C:\Temp){
            "Temp Folder Already Exists"
        }

            else{
                New-Item -Path C:\Temp -ItemType Directory
            }

            if (Test-Path -Path C:\Visitor_pic){
                "Visitor_Pic Folder Already Exists"
            }

            else{
                New-Item -Path C:\Visitor_pic -ItemType Directory
            }
        }

        if($MenuChoice -eq 2){     
            
            Console-Reset    
            $path=Get-Acl -Path C:\Temp
            $acl=New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule ('BUILTIN\Users','FullControl','ContainerInherit, ObjectInherit','None','Allow')
            $path.setaccessrule($acl)
            Set-Acl -Path C:\Temp\ -AclObject $path


            $path=Get-Acl -Path C:\Visitor_pic
            $acl=New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule ('BUILTIN\Users','FullControl','ContainerInherit, ObjectInherit','None','Allow')
            $path.setaccessrule($acl)
            Set-Acl -Path C:\Visitor_pic\ -AclObject $path

            "Permissions for Temp and Visitor_Pics Set!"
    }
        
        if($MenuChoice -eq 3){ 
            Console-Reset
            $path=Get-Acl -Path C:\ProgramData\PTI
            $acl=New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule ('BUILTIN\Users','FullControl','ContainerInherit, ObjectInherit','None','Allow')
            $path.setaccessrule($acl)
            Set-Acl -Path C:\ProgramData\PTI\ -AclObject $path

            "PTI Folder Permissions Set!"
    }

        if($MenuChoice -eq 4){
            Console-Reset
            New-NetFirewallRule -Program "C:\Program Files (x86)\DYMO\DYMO Connect\DYMOConnect.exe" -Action Block -Profile Domain, Private, Public -DisplayName “Block DYMO Connect” -Description “Block DYMO Connect” -Direction Outbound | Format-Table -AutoSize -Property DisplayName, Enabled, Direction, Action  

            New-NetFirewallRule -Program "C:\Program Files (x86)\DYMO\DYMO Connect\DYMO.WebApi.Win.Host.exe" -Action Block -Profile Domain, Private, Public -DisplayName “Block DYMO WebService” -Description “Block DYMO WebService” -Direction Outbound | Format-Table -AutoSize -Property DisplayName, Enabled, Direction, Action 
            
            "Services Blocked using the Firewall!"
        }
        if($MenuChoice -eq 5){
            Console-Reset
            Set-Service -Name "AdobeARMservice" -StartupType Disabled

            "Adobe Update Services Blocked In Services.msc"
    }
        if($MenuChoice -eq 6){
            Console-Reset
            'Have to manually disable S-Mode, luanching Microsoft Store...'
            Start-Process ms-windows-store://pdp/?productid=9nffmgm4vkkd

        }
        if($MenuChoice -eq 7){

            Console-Reset

            'Installing PS Module...'
            Install-Module PSWindowsUpdate
            Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
            Install-WindowsUpdate

            'Done, remember to restart later!'
        }

        if($MenuChoice -eq 8){
            'Enabbling Rotation Lock using Registry.'
            Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AutoRotation -Name Enable -Value 0 -Type DWord
            'Done!'
        }

        if($MenuChoice -eq 9){
            'Disabling Notifications using Registry.'
            New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows" -Name "Explorer" -force
            New-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -PropertyType "DWord" -Value 1
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -PropertyType "DWord" -Value 0
            'Done!'
        }

        if($MenuChoice -eq 10){
            Clear-Host
            MenuMaker -Selections 'Download and Install API', 
            'Download and Install Adobe', 
            'Download and Install Signature Pad', 
            'Download and Install HF Scanner (DS8101) + PDFs',
            'Download and Install HF Scanner (DS6707) + PDFs',
            'Download and Install LX 500 driver',
            'Download and Install DYMO 550 driver',
            'Download and Install DYMO 450 driver',
            'Download and Install GK420d driver',
            'Download and Install GC420d driver (download broken, use GK420d)',
            'Download and Install ZD421/420 driver',
            'Download and Install ZXP-7 driver' -Title 'Choose a Driver' -IncludeExit

            $DownloadPick = Read-Host "Choose a download menu option"

            while($DownloadPick -ne 'X'){

            if($DownloadPick -eq 1){
            
                'Parsing download site...'
            
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e2d06108-8cc8-4705-a316-54463dc1d78f"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText

                'Downloading...'
                $Destination = "C:\Temp\api.zip" 
                Invoke-WebRequest -Uri $text -OutFile $Destination
                'Uncompressing...'
                Expand-Archive -LiteralPath 'C:\Temp\api.zip' -DestinationPath C:\Temp
                "Launching API installer..."
                Start-Process -FilePath "C:\Temp\MSShift.DevicesAPI.Setup.NEW.msi"
                "Success!"

            }

             if($DownloadPick -eq 2){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/5da99203-21ba-4aa2-93e6-a60a8a0b3ae3"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\adobe.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching Adobe installer..."
                Start-Process -FilePath "C:\Temp\adobe.exe"
                "Success!"

        }

            if($DownloadPick -eq 3){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e43d957b-0b20-4422-a3d0-a114162c5dfe"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\sigplus_.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching Signature Pad installer..."
                Start-Process -FilePath "C:\Temp\sigplus_.exe"
                "Success!"

            }
            if($DownloadPick -eq 4){
            
                'Parsing download site...'
                # Download HF driver
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/c862d6fc-fc72-4e77-8347-ab079c8d4fa3"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading driver...'

                $Destination = "C:\Temp\Zebra_CoreScanner_Driver.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                #Downloading PDF's
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/76cdef97-2774-4b11-9adb-14b0220159f5"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading Restore Default PDF...'

                $Destination = "C:\Temp\Restore Default.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e5a5d996-6a66-400b-a2c7-548627642815"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading ScanX_Config_Codebar PDF...'

                $Destination = "C:\Temp\ScanX_Config_Codebar.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching Hands Free Scanner installer..."
                Start-Process -FilePath "C:\Temp\Zebra_CoreScanner_Driver.exe"
                "Success!"

            }

            if($DownloadPick -eq 5){
            
                'Parsing download site...'
                # Download HF driver
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/be6e546f-2bff-4547-ad52-a13442f9a53f"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading driver...'

                $Destination = "C:\Temp\Zebra123_CoreScanner_Driver.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                #Downloading PDF's
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/76cdef97-2774-4b11-9adb-14b0220159f5"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading Restore Default PDF...'

                $Destination = "C:\Temp\Restore Default.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e5a5d996-6a66-400b-a2c7-548627642815"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading ScanX_Config_Codebar PDF...'

                $Destination = "C:\Temp\ScanX_Config_Codebar.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching Hands Free Scanner installer..."
                Start-Process -FilePath "C:\Temp\Zebra123_CoreScanner_Driver.exe"
                "Success!"

            }

            if($DownloadPick -eq 6){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/7ebdd547-4c3c-4dc4-8639-e0ce88c1f60c"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\Primera.2.3.1.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching LX 500 installer..."
                Start-Process -FilePath "C:\Temp\Primera.2.3.1.exe"
                "Success!"

            }
            if($DownloadPick -eq 7){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/1ab37806-4228-4eb1-8178-1ba492b0ea0f"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\DCDSetup1.4.5.1.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching DYMO 550 driver installer..."
                Start-Process -FilePath "C:\Temp\DCDSetup1.4.5.1.exe"
                "Success!"

            }

            if($DownloadPick -eq 8){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/2f89909d-4539-446b-a76c-1ff7f47954aa"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\DCDSetup1.3.2.18.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching DYMO 450 driver installer..."
                Start-Process -FilePath "C:\Temp\DCDSetup1.3.2.18.exe"
                "Success!"

            }

            if($DownloadPick -eq 9){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/2923c379-b7a0-4506-9c28-4ea5b2c0e48c"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\zd51.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching GK420d driver installer..."
                Start-Process -FilePath "C:\Temp\zd51.exe"
                "Success!"

            }

            if($DownloadPick -eq 10){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/56bbaadf-adb3-4a2b-875b-68dac3bb2489"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\zd.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching GC420d driver installer..."
                Start-Process -FilePath "C:\Temp\zd.exe"
                "Success!"

            }

            if($DownloadPick -eq 11){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/75b8f783-51f0-4a8a-9128-bf6957480aa4"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\zd105.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching ZD421/420 driver installer..."
                Start-Process -FilePath "C:\Temp\zd105.exe"
                "Success!"

            }

            if($DownloadPick -eq 12){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/7cc7f865-5107-4f8b-9f3e-617b8ca23802"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\ZXP73.0.2.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching ZXP-7 driver installer..."
                Start-Process -FilePath "C:\Temp\ZXP73.0.2.exe"
                "Success!"

            }

            $DownloadPick = Read-Host "Choose another download menu option" 
                
            }

        }

        if($MenuChoice -eq 11){
            Console-Reset
            "Manually input the old port number"
            $content = Get-Content "C:\Program Files (x86)\MS Shift Inc\MS Shift DevicesAPI\MSShift.DevicesAPI.exe.config"
            'Current API Port #: '
            (Get-Content -Path "C:\Program Files (x86)\MS Shift Inc\MS Shift DevicesAPI\MSShift.DevicesAPI.exe.config" -TotalCount 55)[-1]
            $oldPort = Read-Host "Old Port Number"            
            $newPort = Read-Host "New Port Number"
            $content = $content -replace "$oldPort", "$newPort"
            Set-Content "C:\Program Files (x86)\MS Shift Inc\MS Shift DevicesAPI\MSShift.DevicesAPI.exe.config" -Value $content
            "Changed API port to: $newPort"

        }
        if($MenuChoice -eq 12){
            Console-Reset
            'Launching print server'
            rundll32 printui.dll, PrintUIEntry /s 

        }

        if($MenuChoice -eq 13){

            Console-Reset

            $regContent = @"
            Windows Registry Editor Version 5.00
            ;Disable IE11 Welcome Screen
            [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Internet Explorer\Main]
            "DisableFirstRunCustomize"=dword:00000001 
"@

            # Create a temporary .reg file
            $tempFile = New-TemporaryFile 
            $tempFile.FullName 
            $regContent | Out-File -FilePath $tempFile.FullName -Encoding ASCII

            # Import the registry settings
            reg.exe import $tempFile.FullName

            # Clean up the temporary file
            Remove-Item $tempFile.FullName           

        }

        if($MenuChoice -eq 14){          

            MenuMaker -Selections 'API', 
            'Adobe', 
            'Signature Pad', 
            'HF Scanner (DS8101) + PDFs',
            'HF Scanner (DS6707) + PDFs',
            'LX 500 driver',
            'DYMO 550 driver',
            'DYMO 450 driver',
            'GK420d driver',
            'ZD421/420 driver',
            'ZXP-7 driver' -Title 'Choose a Driver' -IncludeExit

            $CopyLink = Read-Host "Please Choose a Driver"  
         
            While($CopyLink -ne 'X'){
            
                if($CopyLink -eq 1){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e2d06108-8cc8-4705-a316-54463dc1d78f"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }
                if($CopyLink -eq 2){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/5da99203-21ba-4aa2-93e6-a60a8a0b3ae3"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }
                if($CopyLink -eq 3){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e43d957b-0b20-4422-a3d0-a114162c5dfe"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }

                if($CopyLink -eq 4){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/c862d6fc-fc72-4e77-8347-ab079c8d4fa3"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }

                if($CopyLink -eq 5){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/c862d6fc-fc72-4e77-8347-ab079c8d4fa3"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }

                if($CopyLink -eq 6){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/7ebdd547-4c3c-4dc4-8639-e0ce88c1f60c"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }
                if($CopyLink -eq 7){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/1ab37806-4228-4eb1-8178-1ba492b0ea0f"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }
                if($CopyLink -eq 8){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/2f89909d-4539-446b-a76c-1ff7f47954aa"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }

                if($CopyLink -eq 9){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/2923c379-b7a0-4506-9c28-4ea5b2c0e48c"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }

                if($CopyLink -eq 10){

                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/75b8f783-51f0-4a8a-9128-bf6957480aa4"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }
                if($CopyLink -eq 11){
                
                    # Retrieve the HTML content of the website
                    $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/7cc7f865-5107-4f8b-9f3e-617b8ca23802"
                    # Extract the text content from the parsed HTML
                    $text = $response.ParsedHtml.body.innerText
                    Set-Clipboard -Value "$text"
                    'Driver download link copied to clipboard'
                    
                }

            $CopyLink = Read-Host "Choose another download menu option" 
            }
        }

        if($MenuChoice -eq 15){
            Console-Reset
            'Removing the Document.pdf (existing badge PDF)'
            Remove-Item "C:\Temp\Document.pdf" -Confirm
            'PDF deleted!'

        }
        
        if($MenuChoice -eq 16){
            Console-Reset
            'Removing all drivers...'

            if(Test-Path "C:\Temp\api.zip" ){
                 Remove-Item "C:\Temp\api.zip"
                'API files deleted!'
            }

            if(Test-Path "C:\Temp\MSShift.DevicesAPI.Setup.NEW.msi"){
                 Remove-Item "C:\Temp\MSShift.DevicesAPI.Setup.NEW.msi"
            }

            if(Test-Path "C:\Temp\adobe.exe"){
                 Remove-Item "C:\Temp\adobe.exe"
                 'Adobe files removed!'
            }

            if(Test-Path "C:\Temp\sigplus_.exe"){
                 Remove-Item "C:\Temp\sigplus_.exe"
                 'Signature Pads files removed!'
            }

            if(Test-Path "C:\Temp\Zebra_CoreScanner_Driver.exe"){
                 Remove-Item "C:\Temp\Zebra_CoreScanner_Driver.exe"
                 'Scanner files removed!'
            }

            if(Test-Path "C:\Temp\Restore Default.pdf"){
                 Remove-Item "C:\Temp\Restore Default.pdf"
                 'PDFs Removed!'
            }

            if(Test-Path "C:\Temp\ScanX_Config_Codebar.pdf"){
                 Remove-Item "C:\Temp\ScanX_Config_Codebar.pdf"
            }

            if(Test-Path "C:\Temp\Zebra123_CoreScanner_Driver.exe" ){
                 Remove-Item "C:\Temp\Zebra123_CoreScanner_Driver.exe"
                 'Scanner files removed!'
            }

            if(Test-Path "C:\Temp\Primera.2.3.1.exe"){
                 Remove-Item "C:\Temp\Primera.2.3.1.exe"  
                 'LX 500 files removed!'
            }

            if(Test-Path "C:\Temp\DCDSetup1.4.5.1.exe"){
                 Remove-Item "C:\Temp\DCDSetup1.4.5.1.exe"
                 'DYMO files removed!'  
            }

            
            if(Test-Path "C:\Temp\DCDSetup1.3.2.18.exe"){
                 Remove-Item "C:\Temp\DCDSetup1.3.2.18.exe"  
                 'DYMO files removed!'
            }
                        
            if(Test-Path "C:\Temp\zd51.exe"){
                 Remove-Item "C:\Temp\zd51.exe"  
                 'ZD files removed!'
            }

            if(Test-Path "C:\Temp\zd.exe"){
                 Remove-Item "C:\Temp\zd.exe"  
                 'ZD files removed!'
            }

            if(Test-Path "C:\Temp\zd105.exe"){
                 Remove-Item "C:\Temp\zd105.exe" 
                 'ZD files removed!' 
            }

            if(Test-Path "C:\Temp\ZXP73.0.2.exe"){
                 Remove-Item "C:\Temp\ZXP73.0.2.exe"  
                 'ZXP-7 files removed!'
            }
            'Temp folder cleaned!'

        }

        if($MenuChoice -eq 17){
            
            Console-Reset

            # Check service status
            sc.exe query wuauserv

            # Stop process in case it is running

            sc.exe stop wuauserv

            # Set service to disabled
            sc.exe config wuauserv start=disabled

            'Start Value should be 0x4 if really disabled'
            REG.exe QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\wuauserv /v Start

            # Disabled scheduled task
            'Disable scheduled task'
            Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate\'  | Disable-ScheduledTask -ErrorAction SilentlyContinue
        }

        if($MenuChoice -eq 18){
            Clear-Host
            MenuMaker -Selections 'Download and Install API', #1
            'Download and Install Adobe',  #2
            'Download and Install HF Scanner (DS8101) + PDFs', #3
            'Download and Install HF Scanner (DS6707) + PDFs', #4
            'Download and Install DYMO 550 driver', #5
            'Download and Install DYMO 450 driver' -Title 'Choose a silent download and install menu option' -IncludeExit

            $SilentPick = Read-Host "Choose a download menu option"

            while($SilentPick -ne 'X'){

            if($SilentPick -eq 1){
            
                'Parsing download site...'
            
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e2d06108-8cc8-4705-a316-54463dc1d78f"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText

                'Downloading...'
                   
                $Destination = "C:\Temp\api.zip" 
                Invoke-WebRequest -Uri $text -OutFile $Destination
                'Uncompressing...'
                Expand-Archive -LiteralPath 'C:\Temp\api.zip' -DestinationPath C:\Temp
                "Launching API with silent installer params..."
                Start-Process -FilePath "C:\Temp\MSShift.DevicesAPI.Setup.NEW.msi" -ArgumentList "/passive", "/norestart"
                "Success!"

            }

             if($SilentPick -eq 2){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/5da99203-21ba-4aa2-93e6-a60a8a0b3ae3"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\adobe.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching Adobe with silent installer params..."
                Start-Process -FilePath "C:\Temp\adobe.exe" -ArgumentList -sAll
                "Success!"

        }

            if($SilentPick -eq 3){
            
                'Parsing download site...'
                # Download HF driver
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/c862d6fc-fc72-4e77-8347-ab079c8d4fa3"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading driver...'

                $Destination = "C:\Temp\Zebra_CoreScanner_Driver.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                #Downloading PDF's
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/76cdef97-2774-4b11-9adb-14b0220159f5"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading Restore Default PDF...'

                $Destination = "C:\Temp\Restore Default.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e5a5d996-6a66-400b-a2c7-548627642815"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading ScanX_Config_Codebar PDF...'

                $Destination = "C:\Temp\ScanX_Config_Codebar.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching Hands Free Scanner with silent installer params..."
                Start-Process -FilePath "C:\Temp\Zebra_CoreScanner_Driver.exe" -ArgumentList "/S", "/v/qn"
                "Success!"

            }

            if($SilentPick -eq 4){
            
                'Parsing download site...'
                # Download HF driver
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/be6e546f-2bff-4547-ad52-a13442f9a53f"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading driver...'

                $Destination = "C:\Temp\Zebra123_CoreScanner_Driver.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                #Downloading PDF's
                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/76cdef97-2774-4b11-9adb-14b0220159f5"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading Restore Default PDF...'

                $Destination = "C:\Temp\Restore Default.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/e5a5d996-6a66-400b-a2c7-548627642815"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading ScanX_Config_Codebar PDF...'

                $Destination = "C:\Temp\ScanX_Config_Codebar.pdf" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching Hands Free Scanner with silent installer params..."
                Start-Process -FilePath "C:\Temp\Zebra123_CoreScanner_Driver.exe" -ArgumentList "/S", "/v/qn"
                "Success!"

            }

            if($SilentPick -eq 5){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/1ab37806-4228-4eb1-8178-1ba492b0ea0f"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\DCDSetup1.4.5.1.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching DYMO 550 driver with silent installer params..."
                Start-Process -FilePath "C:\Temp\DCDSetup1.4.5.1.exe" -ArgumentList "/S", "/v/qn"
                "Success!"

            }

            if($SilentPick -eq 6){
            
                'Parsing download site...'

                # Retrieve the HTML content of the website
                $response = Invoke-WebRequest -Uri "https://download.msshift.com/link/2f89909d-4539-446b-a76c-1ff7f47954aa"
                # Extract the text content from the parsed HTML
                $text = $response.ParsedHtml.body.innerText
            
                'Downloading...'

                $Destination = "C:\Temp\DCDSetup1.3.2.18.exe" 
                Invoke-WebRequest -Uri $text -OutFile $Destination

                "Launching DYMO 450 driver with silent installer params..."
                Start-Process -FilePath "C:\Temp\DCDSetup1.3.2.18.exe" -ArgumentList "/S", "/v/qn"
                "Success!"

            }

            $SilentPick = Read-Host "Choose another download menu option" 
                
            }
            Print-Menu
        }

        if($MenuChoice -eq 19){

# Contents of the batch and VBS file. 

$batchContent = @"
@echo off
net stop spooler
ping -n 4 127.0.0.1 > nul 
echo Deleting Print Queue...
del %systemroot%\System32\spool\printers\* /Q
echo Queue Deleted.
net start spooler
"@

$vbsContent = @"
CreateObject("Wscript.Shell").Run "C:\Temp\QueueDeletion.bat",0,True
"@

        $batchFilePath = "C:\Temp\QueueDeletion.bat"
        $batchContent | Out-File -FilePath $batchFilePath -Encoding ascii
        "Batch File created in Temp folder..."

        "Creating VBS for silent launch..."
        $vbsFilePath = "C:\Temp\QueueDeletion.vbs"
        $vbsContent | Out-File -FilePath $vbsFilePath -Encoding ascii
        "VBS File created in Temp folder..."

        "Creating Scheduled Task..."
        $action = New-ScheduledTaskAction -Execute "C:\Temp\QueueDeletion.vbs"
        $trigger = New-ScheduledTaskTrigger -Daily -At 11:30AM
        Register-ScheduledTask -TaskName "Print Queue Deletion Task" -Action $action -Trigger $trigger -AsJob -Force -RunLevel Highest

    }

    $MenuChoice = Read-Host "Choose another function menu option"

}

Print-Menu
}

Write-Output "Goodbye!"
Start-Sleep -Seconds 2
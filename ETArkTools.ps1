
function Install-SteamCMD
{
    <#
        .SYNOPSIS
        Downloads the SteamCMD zip to $Path, extracts the EXE and then installs SteamCMD to $Path.

        .PARAMETER Path
        Specifies the path to the directory to install SteamCMD in.

        .EXAMPLE
        PS> Install-SteamCMD -Path D:\SteamCMD -Verbose
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $Path
    )
 
    # Download SteamCMD
    Write-Verbose "Downloading steamcmd.zip to $Path."
    $OutFile = $Path + '\' + 'steamcmd.zip'
    $TestZipPath = Test-Path -Path $OutFile
    if ($TestZipPath)
    {
        Write-Verbose "File steamcmd.zip already exists at $Path."
    }
    else
    {
        try 
        {
            Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $OutFile -ErrorAction Stop
            Write-Verbose 'steamcmd.zip downloaded successfully.' 
        }
        catch
        {
            Write-Verbose "Couldn't download steamcmd.zip."
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    # Extract SteamCMD.zip
    $ExePath = $Path + '\' + 'steamcmd.exe' 
    $TestExePath = Test-Path -Path $ExePath
    Write-Verbose 'Extracting steamcmd.exe from steamcmd.zip.'
    if ($TestExePath)
    {
        Write-Verbose "File steamcmd.exe already exists at $Path."
    }
    else
    {
        try 
        {
            Expand-Archive $OutFile -DestinationPath $Path -ErrorAction Stop
            Write-Verbose 'steamcmd.exe extracted successfully.'   
        }
        catch
        {
            Write-Verbose "Couldn't extract steamcmd.zip."
            Write-Host $_.Exception.Message -ForegroundColor Red
        }  
    }

    # Install SteamCMD
    Write-Verbose 'Installing SteamCMD.'
    try 
    {
        Start-Process -FilePath $ExePath -ArgumentList "+quit" -Wait -ErrorAction Stop
        Write-Verbose 'SteamCMD install complete.'
    }
    catch
    {
        Write-Verbose "SteamCMD install failed."
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Function Install-ARKServer
{
    <#
        .SYNOPSIS
        Runs Install-SteamCMD to install SteamCMD at $PathToSteamCMD and then installs the ARK Server to $PathToARK.

        .PARAMETER PathToSteamCMD
        Specifies the path to the directory to install Ark in.

        .PARAMETER PathToARK
        Specifies the path to the directory to install Ark in.

        .EXAMPLE
        PS> Install-ARKServer -PathToSteamCMD D:\SteamCMD -PathToARK D:\ARK -Verbose
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $PathToSteamCMD,

        [parameter(Mandatory)]
        [String]
        $PathToARK
    )

    # Make sure SteamCMD is installed at requested location.
    $SteamCMDTestPath = Test-Path -Path $PathToSteamCMD
    if ($SteamCMDTestPath -eq $False)
    {
        New-Item -ItemType Directory -Path $PathToSteamCMD  
    }    
    Install-SteamCMD -Path $PathToSteamCMD  

    # Install ARK Server.
    Write-Verbose 'Installing ARK Server.'
    $SteamCMDEXE = $PathToSteamCMD + '/' + 'steamcmd.exe'
    try
    {
        Start-Process $SteamCMDEXE -ArgumentList "+login anonymous +force_install_dir $PathToARK +app_update 376030 +quit" -Wait -ErrorAction Stop
        Write-Verbose 'Ark Server install complete.'
    }
    catch
    {
        Write-Verbose "Ark Server install failed."
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function Update-ARKServer
{
    <#
        .SYNOPSIS
        Shuts down ARK server, checks for updates, if available it installs them then it reboots.

        .PARAMETER PathToSteamCMD
        Specifies the path to the directory to Update SteamCMD in.

        .PARAMETER PathToARK
        Specifies the path to the directory to Update Ark in.

        .EXAMPLE
        PS> Update-ARKServer -PathToSteamCMD D:\SteamCMD -PathToARK D:\ARK -Verbose
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $PathToSteamCMD,

        [parameter(Mandatory)]
        [String]
        $PathToARK
    )

    # Script Variables
    $PathToini = $PathToARK + '\ShooterGame\Saved\Config\WindowsServer\GameuserSettings.ini'
    $BackupPath = $PathToARK + '\ShooterGame\Saved\Config\WindowsServer\Backup\GameuserSettings.ini'
    $GameUserSettingsPath = ($PathToARK + $PathToini)
    $SteamCMDOptions = "+login anonymous +force_install_dir $PathToARK +app_update 376030 +quit"
    $PathToStartupScript = $PathToARK + '\Scripts\Start_ARKServer.bat'

    # Kill the server until it's dead.
    Write-Verbose 'Shutting down the ARK server!'
    do
    {
        Stop-Process -Name ShooterGameServer -Force         
    }
    until ( $null -eq  (Get-Process -Name ShooterGameServer) ) 

    # Backup GameUserSettings.ini to preserve custom config.
    Write-Verbose 'Backing up server configuration files.'
    try 
    {
        Copy-Item -Path $GameUserSettingsPath -Destination $BackupPath -Verbose -ErrorAction Stop
        Write-Verbose 'Server configuration backup complete.'
    }
    catch
    {
        Write-Verbose "Ark Server configuration backup failed."
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    # Launch SteamCMD.exe and update game files.
    Write-Verbose 'Launching SteamCMD to check for updates.'
    try 
    {
        Start-Process -FilePath $PathToSteamCMD -ArgumentList $SteamCMDOptions -ErrorAction Stop
        Write-Verbose 'Waiting for SteamCMD to finish.'
        Wait-Process steamcmd
        Write-Verbose 'SteamCMD update process complete.'
    }
    catch 
    {
        Write-Verbose "Ark Server update failed."
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    # Restore backed up game configration files after update.
    Write-Verbose 'Restoring backed up server configuration files.'
    try
    {
        Copy-Item -Path $BackupPath -Destination $GameUserSettingsPath -Verbose -ErrorAction Stop
        Write-Verbose 'Restore of backed up server configuration files successful.'
    }
    catch 
    {
        Write-Verbose 'Restore of backed up server configuration files failed.'
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    # Start the ARK server back up.
    Write-Verbose 'Starting the ARK server back up!'
    try 
    {
        Start-Process -FilePath $PathToStartupScript
    }
    catch 
    {
        Write-Verbose 'Failed to start the ARK server.'
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function New-ArkServerScript
{
    <#
        .SYNOPSIS
        Creates the startup script for the Ark server.

        .PARAMETER PathToARK
        Specifies the path to the directory Ark is installed in.
        
        .PARAMETER Map
        Specifies the Map you want the Ark server to run.

        .PARAMETER ServerName
        Specifies the name of the Server.

        .PARAMETER ServerPassword
        Specifies the server password.

        .PARAMETER ServerAdminPassword
        Specifies the servers admin password.
        
        .EXAMPLE
        PS> New-ArkServerScript -PathToARK D:\ARK -Map 'TheIsland' -ServerName ETServer -ServerPassword Password123 -ServerAdminPassword Password321 -Verbose
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $PathToARK,

        [parameter(Mandatory)]
        [String]
        [ValidateSet('TheIsland','Ragnarok','Valguero')]
        $Map,

        [parameter(Mandatory)]
        [String]
        $ServerName,

        [parameter(Mandatory)]
        [String]
        $ServerPassword,

        [parameter(Mandatory)]
        [String]
        $ServerAdminPassword
    )

    # Variables
    $BatFile = $PathToArk + '\Scripts\Start_ARKServer.bat'
    $PathToExe = $PathToARK + '\ShooterGame\Binaries\Win64\ShooterGameServer.exe'

    # Create Scripts folder and the Start_ARKServer.bat file.
    try 
    {
        Write-Verbose 'Creating Scripts directory.'
        New-Item -Path "$PathToARK\Scripts" -ItemType Directory -ErrorAction Stop
        Write-Verbose 'Creating Start_ARKServer.bat file.'
        New-Item -Path $BatFile -ErrorAction Stop
        Write-Verbose 'Successfully created the Start_ARKServer.bat file.'
    }
    catch 
    {
        Write-Verbose 'Failed to create the Start_ARKServer.bat file.'
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    # Populate server startup script into Start_ARKServer.bat file.
    try 
    {
        Write-Verbose 'Populating data into Start_ARKServer.bat.'
        $StartupScriptText = "start $PathToExe $($Map)?listen?SessionName=$($ServerName)?ServerPassword=$($ServerPassword)?ServerAdminPassword=$($ServerAdminPassword)?Port=7777?QueryPort=27015?MaxPlayers=20"
        Out-File -FilePath $BatFile -InputObject $StartupScriptText -ErrorAction Stop
        Add-Content $BatFile 'exit' -ErrorAction Stop
        Write-Verbose 'Successfully imported data into Start_ARKServer.bat.' 
    }
    catch 
    {
        Write-Verbose 'Failed to import data into the Start_ARKServer.bat file. Review file manually.'
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function New-ArkScheduledTask
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $PathToStartupScript
    )
    
    $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest    
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Action = New-ScheduledTaskAction -Execute "$PathToStartupScript"

    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName 'Ark Server Startup' -Description 'Runs the Start_ArkServer.bat at server startup.' -Principal $principal
}

function Setup-ArkServer
{
    <#
        .SYNOPSIS
        This is the build function for the toolset. Run this function to run the full Ark Server build process.

        .PARAMETER PathToSteamCMD
        Specifies the path to the directory to install SteamCMD in.

        .PARAMETER PathToARK
        Specifies the path to the directory to install Ark in.
        
        .PARAMETER Map
        Specifies the Map you want the Ark server to run.

        .PARAMETER ServerName
        Specifies the name of the Server.

        .PARAMETER ServerPassword
        Specifies the server password.

        .PARAMETER ServerAdminPassword
        Specifies the servers admin password.

        .EXAMPLE
        PS> Setup-ArkServer -PathToSteamCMD D:\SteamCMD -PathToARK D:\ARK -Verbose

        .EXAMPLE
        PS> Setup-ArkServer -PathToSteamCMD D:\SteamCMD -PathToARK D:\ARK -Map 'TheIsland' -ServerName 'DefaultServer' -ServerPassword 'Password123' -ServerAdminPassword 'Password321' -Verbose
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $PathToSteamCMD,

        [parameter(Mandatory)]
        [String]
        $PathToARK,

        [parameter(Mandatory=$False)]
        [String]
        [ValidateSet('TheIsland','Ragnarok','Valguero')]
        $Map = 'TheIsland',

        [parameter(Mandatory=$False)]
        [String]
        $ServerName = 'Default Server',

        [parameter(Mandatory=$False)]
        [String]
        $ServerPassword = 'Password123',

        [parameter(Mandatory=$False)]
        [String]
        $ServerAdminPassword = 'Password321'
    )

    Install-ARKServer -PathToSteamCMD $PathToSteamCMD -PathToArk $PathToARK

    New-ARKServerScript -PathToArk $PathToARK -Map $Map -ServerName $ServerName -ServerPassword $ServerPassword -ServerAdminPassword $ServerAdminPassword
}
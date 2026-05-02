# Powershell 5.x Script Management UI for RustDesk Multi-Instances with tailscale
#
# Reactored by Gugatec https://github.com/Gugatec/rustdesk-multi-instance
#
# suuhm original script https://github.com/suuhm/rustdesk-multi-instance
#
# Version v10

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

[System.Windows.Forms.Application]::EnableVisualStyles()

[string]$global:AppVersion = "v10"
[string]$global:GitHubUrl = "https://github.com/Gugatec/rustdesk-multi-instance"

[string]$global:IPATH = ""
[string]$global:RustDeskExePath = ""
[string]$global:TailscaleExePath = ""
[bool]$global:TailscaleEnabled = $false
[hashtable]$global:InstanceTailscaleMap = @{}

[string]$global:ToolConfigDir = Join-Path $env:APPDATA "RustDeskMultiInstanceTool"
[string]$global:ToolConfigFile = Join-Path $global:ToolConfigDir "config.json"
[string]$global:DefaultProfileBackup = Join-Path $global:ToolConfigDir "DefaultRustDesk"

Function Show-Message {
    Param(
        [string]$Message,
        [string]$Title = "RustDesk Multi Instance",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $Icon
    ) | Out-Null
}


Function Show-HelpWindow {
    $helpText = @"
RustDesk Multi-Instance Manager Help

1. Open File > Config.
2. Set the RustDesk.exe path.
3. Set the RustDesk instance folder path. This is where each RustDesk profile/instance is stored.
4. Optional: enable Tailscale switching and set tailscale.exe path if it is not found automatically.
5. Create or select a RustDesk instance.
6. If Tailscale is enabled, select a Tailscale account and click Associate Tailscale.
7. Click Switch && Start to activate the selected RustDesk profile, optionally switch Tailscale, and launch RustDesk.

Notes:
- Disable Tailscale functionality if the user only needs RustDesk profile switching.
- Refresh List updates the RustDesk instances shown.
- Remove Instance deletes the selected instance folder after a Yes/No confirmation.
- Refresh Tailscale reloads available Tailscale accounts.
- Restore Default Profile returns to the backed-up default RustDesk profile.
"@

    Show-Message $helpText "Help" ([System.Windows.Forms.MessageBoxIcon]::Information)
}

Function Show-AboutWindow {
    $AboutForm = New-Object System.Windows.Forms.Form
    $AboutForm.Text = "About"
    $AboutForm.Size = New-Object System.Drawing.Size(500, 245)
    $AboutForm.FormBorderStyle = "FixedDialog"
    $AboutForm.MaximizeBox = $false
    $AboutForm.MinimizeBox = $false
    $AboutForm.StartPosition = "CenterParent"

    $TitleLabel = New-Object System.Windows.Forms.Label
    $TitleLabel.Text = "RustDesk Multi-Instance Manager $($global:AppVersion)"
    $TitleLabel.Font = New-Object System.Drawing.Font -ArgumentList $TitleLabel.Font, ([System.Drawing.FontStyle]::Bold)
    $TitleLabel.Size = New-Object System.Drawing.Size(440, 25)
    $TitleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $AboutForm.Controls.Add($TitleLabel)

    $VersionLabel = New-Object System.Windows.Forms.Label
    $VersionLabel.Text = "Version: $($global:AppVersion)"
    $VersionLabel.Size = New-Object System.Drawing.Size(440, 25)
    $VersionLabel.Location = New-Object System.Drawing.Point(20, 55)
    $AboutForm.Controls.Add($VersionLabel)

    $InfoLabel = New-Object System.Windows.Forms.Label
    $InfoLabel.Text = "Multi-instance RustDesk manager with optional Tailscale account switching."
    $InfoLabel.Size = New-Object System.Drawing.Size(440, 40)
    $InfoLabel.Location = New-Object System.Drawing.Point(20, 85)
    $AboutForm.Controls.Add($InfoLabel)

    $GitHubLabel = New-Object System.Windows.Forms.LinkLabel
    $GitHubLabel.Text = $global:GitHubUrl
    $GitHubLabel.Size = New-Object System.Drawing.Size(440, 25)
    $GitHubLabel.Location = New-Object System.Drawing.Point(20, 130)
    $GitHubLabel.add_LinkClicked({
        try {
            Start-Process $global:GitHubUrl
        }
        catch {
            Show-Message "Could not open GitHub link:`n$($_.Exception.Message)" "Open Link Error" ([System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $AboutForm.Controls.Add($GitHubLabel)

    $ButtonClose = New-Object System.Windows.Forms.Button
    $ButtonClose.Text = "Close"
    $ButtonClose.Size = New-Object System.Drawing.Size(100, 32)
    $ButtonClose.Location = New-Object System.Drawing.Point(365, 165)
    $ButtonClose.add_Click({ $AboutForm.Close() })
    $AboutForm.Controls.Add($ButtonClose)

    $AboutForm.ShowDialog() | Out-Null
}

Function Ensure-ToolConfigDir {
    if (!(Test-Path $global:ToolConfigDir)) {
        New-Item -ItemType Directory -Path $global:ToolConfigDir -Force | Out-Null
    }
}

Function Get-RealRustDeskConfigPath {
    return Join-Path $env:APPDATA "RustDesk"
}

Function Get-InstanceRustDeskConfigPath {
    Param([string]$InstancePath)
    return Join-Path $InstancePath "RustDesk"
}

Function Is-ReparsePoint {
    Param([string]$Path)

    if (!(Test-Path $Path)) { return $false }

    $item = Get-Item $Path -Force
    return (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

Function Stop-RustDesk {
    Get-Process rustdesk -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Start-Sleep -Milliseconds 800
}

Function Copy-FolderContents {
    Param(
        [string]$Source,
        [string]$Destination
    )

    if (!(Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

Function Load-ToolConfig {
    if (!(Test-Path $global:ToolConfigFile)) { return }

    try {
        $config = Get-Content $global:ToolConfigFile -Raw | ConvertFrom-Json

        if ($config.RustDeskExePath) {
            $global:RustDeskExePath = [string]$config.RustDeskExePath
        }

        if ($config.InstancePath) {
            $global:IPATH = [string]$config.InstancePath
        }

        if ($config.TailscaleExePath) {
            $global:TailscaleExePath = [string]$config.TailscaleExePath
        }

        $global:InstanceTailscaleMap = @{}
        if ($config.InstanceTailscaleMap) {
            $config.InstanceTailscaleMap.PSObject.Properties | ForEach-Object {
                $global:InstanceTailscaleMap[$_.Name] = [string]$_.Value
            }
        }

        if ($config.PSObject.Properties.Name -contains "TailscaleEnabled") {
            $global:TailscaleEnabled = [System.Convert]::ToBoolean($config.TailscaleEnabled)
        }
        else {
            # Backward compatibility for configs created by v9/v9.1.
            # If the user already configured a Tailscale path or associations, keep Tailscale enabled.
            $global:TailscaleEnabled = (($global:InstanceTailscaleMap.Count -gt 0) -or ![string]::IsNullOrWhiteSpace($global:TailscaleExePath))
        }
    }
    catch {
        Show-Message "Failed to load config:`n$($_.Exception.Message)" "Config Error" ([System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}

Function Save-ToolConfig {
    try {
        Ensure-ToolConfigDir

        $mapObject = New-Object PSObject
        foreach ($key in $global:InstanceTailscaleMap.Keys) {
            $mapObject | Add-Member -MemberType NoteProperty -Name $key -Value $global:InstanceTailscaleMap[$key]
        }

        $config = [PSCustomObject]@{
            RustDeskExePath      = $global:RustDeskExePath
            InstancePath         = $global:IPATH
            TailscaleEnabled     = $global:TailscaleEnabled
            TailscaleExePath     = $global:TailscaleExePath
            InstanceTailscaleMap = $mapObject
        }

        $config | ConvertTo-Json -Depth 5 | Set-Content -Path $global:ToolConfigFile -Encoding UTF8
    }
    catch {
        Show-Message "Failed to save config:`n$($_.Exception.Message)" "Config Error" ([System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

Function Get-ActiveInstanceFile {
    Ensure-ToolConfigDir
    return Join-Path $global:ToolConfigDir "active-instance.txt"
}

Function Get-ActiveInstanceName {
    $file = Get-ActiveInstanceFile

    if (Test-Path $file) {
        return (Get-Content $file -Raw).Trim()
    }

    return ""
}

Function Set-ActiveInstanceName {
    Param([string]$Name)

    $file = Get-ActiveInstanceFile
    Set-Content -Path $file -Value $Name -Encoding UTF8
}

Function Clear-ActiveInstanceName {
    $file = Get-ActiveInstanceFile

    if (Test-Path $file) {
        Remove-Item $file -Force
    }
}

Function Repair-OldJunctionSetup {
    Ensure-ToolConfigDir

    $realPath = Get-RealRustDeskConfigPath

    if ((Test-Path $realPath) -and (Is-ReparsePoint $realPath)) {
        cmd.exe /c "rmdir `"$realPath`"" | Out-Null
    }

    if (!(Test-Path $realPath) -and (Test-Path $global:DefaultProfileBackup)) {
        Move-Item -Path $global:DefaultProfileBackup -Destination $realPath -Force
        Clear-ActiveInstanceName
    }
}

Function Backup-DefaultProfileOnce {
    Ensure-ToolConfigDir

    $realPath = Get-RealRustDeskConfigPath

    if ((Test-Path $realPath) -and !(Test-Path $global:DefaultProfileBackup) -and !(Is-ReparsePoint $realPath)) {
        Copy-Item -Path $realPath -Destination $global:DefaultProfileBackup -Recurse -Force
    }
}

Function Save-CurrentRealProfileToActiveInstance {
    $activeName = Get-ActiveInstanceName

    if ([string]::IsNullOrWhiteSpace($activeName)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($global:IPATH)) {
        return
    }

    $realPath = Get-RealRustDeskConfigPath
    $activeInstancePath = Join-Path $global:IPATH $activeName
    $activeConfigPath = Get-InstanceRustDeskConfigPath $activeInstancePath

    if (!(Test-Path $realPath)) {
        return
    }

    if (Is-ReparsePoint $realPath) {
        return
    }

    if (Test-Path $activeConfigPath) {
        Remove-Item -Path $activeConfigPath -Recurse -Force
    }

    Copy-Item -Path $realPath -Destination $activeConfigPath -Recurse -Force
}

Function Activate-InstanceProfile {
    Param(
        [string]$InstanceName,
        [string]$InstancePath
    )

    Stop-RustDesk
    Repair-OldJunctionSetup
    Backup-DefaultProfileOnce
    Save-CurrentRealProfileToActiveInstance

    $realPath = Get-RealRustDeskConfigPath
    $instanceConfigPath = Get-InstanceRustDeskConfigPath $InstancePath

    if (!(Test-Path $instanceConfigPath)) {
        New-Item -ItemType Directory -Path $instanceConfigPath -Force | Out-Null
    }

    if ((Test-Path $realPath) -and (Is-ReparsePoint $realPath)) {
        cmd.exe /c "rmdir `"$realPath`"" | Out-Null
    }
    elseif (Test-Path $realPath) {
        Remove-Item -Path $realPath -Recurse -Force
    }

    Copy-Item -Path $instanceConfigPath -Destination $realPath -Recurse -Force

    Set-ActiveInstanceName $InstanceName
}

Function Restore-DefaultProfile {
    Stop-RustDesk
    Repair-OldJunctionSetup
    Save-CurrentRealProfileToActiveInstance

    $realPath = Get-RealRustDeskConfigPath

    if (!(Test-Path $global:DefaultProfileBackup)) {
        Show-Message "No default profile backup exists yet." "Restore Default Profile" ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if ((Test-Path $realPath) -and (Is-ReparsePoint $realPath)) {
        cmd.exe /c "rmdir `"$realPath`"" | Out-Null
    }
    elseif (Test-Path $realPath) {
        Remove-Item -Path $realPath -Recurse -Force
    }

    Copy-Item -Path $global:DefaultProfileBackup -Destination $realPath -Recurse -Force
    Clear-ActiveInstanceName

    Show-Message "Default RustDesk profile restored.`n`n$realPath"
}


Function Get-TailscaleExecutable {
    if (![string]::IsNullOrWhiteSpace($global:TailscaleExePath) -and (Test-Path $global:TailscaleExePath)) {
        return $global:TailscaleExePath
    }

    $cmd = Get-Command "tailscale.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $commonPaths = @()
    if (![string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $commonPaths += (Join-Path $env:ProgramFiles "Tailscale\tailscale.exe")
    }
    if (![string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
        $commonPaths += (Join-Path ${env:ProgramFiles(x86)} "Tailscale\tailscale.exe")
    }
    if (![string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $commonPaths += (Join-Path $env:LOCALAPPDATA "Tailscale\tailscale.exe")
    }

    foreach ($path in $commonPaths) {
        if (![string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
            return $path
        }
    }

    return "tailscale.exe"
}

Function Invoke-TailscaleCli {
    Param([string[]]$Arguments)

    $exe = Get-TailscaleExecutable
    $output = @()
    $exitCode = 0

    try {
        $output = & $exe @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    catch {
        return [PSCustomObject]@{
            Success  = $false
            ExitCode = -1
            Output   = $_.Exception.Message
        }
    }

    return [PSCustomObject]@{
        Success  = ($exitCode -eq 0)
        ExitCode = $exitCode
        Output   = ($output | Out-String).Trim()
    }
}

Function Normalize-TailscaleAccountLine {
    Param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return "" }

    $clean = [string]$Line
    $clean = $clean.Replace("`r", " ").Replace("`n", " ").Trim()
    $clean = $clean -replace "\s+", " "
    $clean = $clean -replace "\s+\[ACTIVE\]$", ""
    $clean = $clean -replace "^\*\s+", ""
    $clean = $clean -replace "\s+\*$", ""
    $clean = $clean.Trim()

    return $clean
}

Function Get-TailscaleSwitchKeyFromLine {
    Param([string]$Line)

    $clean = Normalize-TailscaleAccountLine -Line $Line
    if ([string]::IsNullOrWhiteSpace($clean)) { return "" }

    # Newer Tailscale versions can show multiple columns from `tailscale switch --list`,
    # for example: profile-id, login name, and tailnet name. The switch command needs
    # a single profile identifier, account, or nickname, not the entire row.
    $parts = $clean -split "\s+"
    if ($parts.Count -ge 1) {
        return [string]$parts[0]
    }

    return $clean
}


Function Get-TailscaleDisplayEmailFromLine {
    Param([string]$Line)

    $clean = Normalize-TailscaleAccountLine -Line $Line
    if ([string]::IsNullOrWhiteSpace($clean)) { return "" }

    $isActive = (($clean -match "^\*\s+") -or ($clean -match "\s+\*$"))
    $clean = $clean -replace "^\*\s+", ""
    $clean = $clean -replace "\s+\*$", ""
    $clean = $clean.Trim()

    $parts = $clean -split "\s+"
    $email = ""

    foreach ($part in $parts) {
        if ($part -match "^[^\s@]+@[^\s@]+\.[^\s@]+$") {
            $email = $part
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($email)) {
        if ($parts.Count -ge 2) {
            $email = [string]$parts[1]
        }
        else {
            $email = $clean
        }
    }

    if ($isActive) {
        return "$email  [ACTIVE]"
    }

    return $email
}

Function Get-TailscaleDropdownDisplayFromLine {
    Param([string]$Line)

    $clean = Normalize-TailscaleAccountLine -Line $Line
    if ([string]::IsNullOrWhiteSpace($clean)) { return "" }

    $switchKey = Get-TailscaleSwitchKeyFromLine -Line $clean
    $emailDisplay = Get-TailscaleDisplayEmailFromLine -Line $Line
    $isActive = ($emailDisplay -match "\s+\[ACTIVE\]$")
    $email = ($emailDisplay -replace "\s+\[ACTIVE\]$", "").Trim()

    if (![string]::IsNullOrWhiteSpace($switchKey)) {
        if ($isActive) {
            return "$email ($switchKey)  [ACTIVE]"
        }
        return "$email ($switchKey)"
    }

    return $emailDisplay
}

Function Get-TailscaleAccounts {
    $accounts = @()
    $result = Invoke-TailscaleCli -Arguments @("switch", "--list")

    if (!$result.Success) {
        throw "Unable to list Tailscale accounts. Make sure Tailscale is installed and at least one account is logged in.`n`n$($result.Output)"
    }

    $lines = $result.Output -split "`r?`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

        # Skip table headers if a future/current client prints them.
        if ($trimmed -match "^(PROFILE|PROFILE\s+ID|ID\s+|NAME\s+|ACCOUNT\s+)" -and $trimmed -match "(?i)(account|tailnet|user|name)") {
            continue
        }

        $isActive = (($trimmed -match "^\*\s+") -or ($trimmed -match "\s+\*$"))
        $clean = Normalize-TailscaleAccountLine -Line $trimmed
        $switchKey = Get-TailscaleSwitchKeyFromLine -Line $clean

        if (![string]::IsNullOrWhiteSpace($switchKey)) {
            $display = Get-TailscaleDisplayEmailFromLine -Line $trimmed
            $accounts += [PSCustomObject]@{
                Account   = $switchKey
                SwitchKey = $switchKey
                RawLine   = $clean
                IsActive  = $isActive
                Display   = $display
                DropdownDisplay = Get-TailscaleDropdownDisplayFromLine -Line $trimmed
            }
        }
    }

    return $accounts
}

Function Get-InstanceTailscaleAccount {
    Param([string]$InstanceName)

    if ($global:InstanceTailscaleMap.ContainsKey($InstanceName)) {
        return [string]$global:InstanceTailscaleMap[$InstanceName]
    }

    return ""
}

Function Set-InstanceTailscaleAccount {
    Param(
        [string]$InstanceName,
        [string]$Account
    )

    if ([string]::IsNullOrWhiteSpace($InstanceName)) { return }

    $normalizedAccount = Get-TailscaleSwitchKeyFromLine -Line $Account

    if ([string]::IsNullOrWhiteSpace($normalizedAccount)) {
        if ($global:InstanceTailscaleMap.ContainsKey($InstanceName)) {
            $global:InstanceTailscaleMap.Remove($InstanceName)
        }
    }
    else {
        $global:InstanceTailscaleMap[$InstanceName] = $normalizedAccount
    }

    Save-ToolConfig
}

Function Resolve-TailscaleMappingDisplay {
    Param([string]$MappedAccount)

    if (!$global:TailscaleEnabled) { return "<Tailscale disabled>" }
    if ([string]::IsNullOrWhiteSpace($MappedAccount)) { return "<not associated>" }

    try {
        $key = Get-TailscaleSwitchKeyFromLine -Line $MappedAccount
        $accounts = Get-TailscaleAccounts
        $match = $accounts | Where-Object {
            $_.SwitchKey -eq $key -or
            $_.Account -eq $key -or
            (Normalize-TailscaleAccountLine -Line $_.RawLine) -eq (Normalize-TailscaleAccountLine -Line $MappedAccount)
        } | Select-Object -First 1

        if ($null -ne $match) { return $match.Display }
    }
    catch {
        # Keep the list usable even if tailscale.exe is unavailable during GUI refresh.
    }

    return (Get-TailscaleDisplayEmailFromLine -Line $MappedAccount)
}

Function Switch-TailscaleForInstance {
    Param([string]$InstanceName)

    if (!$global:TailscaleEnabled) {
        return
    }

    $account = Get-InstanceTailscaleAccount -InstanceName $InstanceName

    if ([string]::IsNullOrWhiteSpace($account)) {
        throw "No Tailscale account is associated with instance '$InstanceName'. Select the instance, choose a Tailscale account, then click 'Associate Tailscale'."
    }

    $savedKey = Get-TailscaleSwitchKeyFromLine -Line $account
    $accounts = Get-TailscaleAccounts
    $match = $accounts | Where-Object {
        $_.SwitchKey -eq $savedKey -or
        $_.Account -eq $savedKey -or
        (Normalize-TailscaleAccountLine -Line $_.RawLine) -eq (Normalize-TailscaleAccountLine -Line $account)
    } | Select-Object -First 1

    if ($null -eq $match) {
        throw "The Tailscale account '$account' is associated with '$InstanceName', but it is not currently available on this machine. Add/login that Tailscale account first, then refresh the list."
    }

    $switchKey = $match.SwitchKey
    if ([string]::IsNullOrWhiteSpace($switchKey)) {
        $switchKey = $savedKey
    }

    if ($match.IsActive) {
        # Migrate old saved full-row associations to the usable switch key.
        if ($account -ne $switchKey) {
            Set-InstanceTailscaleAccount -InstanceName $InstanceName -Account $switchKey
        }
        return
    }

    $result = Invoke-TailscaleCli -Arguments @("switch", $switchKey)
    if (!$result.Success) {
        throw "Failed to switch Tailscale to '$switchKey'.`n`nSaved association was:`n$account`n`n$($result.Output)"
    }

    # Migrate old saved full-row associations to the usable switch key after a successful switch.
    if ($account -ne $switchKey) {
        Set-InstanceTailscaleAccount -InstanceName $InstanceName -Account $switchKey
    }

    Start-Sleep -Milliseconds 800
}

Function Start-TailscaleLogin {
    try {
        $exe = Get-TailscaleExecutable
        Start-Process -FilePath $exe -ArgumentList @("login")
        Show-Message "Tailscale login was started. Complete the browser login, then click 'Refresh Tailscale'." "Tailscale Login"
    }
    catch {
        Show-Message "Failed to start Tailscale login:`n`n$($_.Exception.Message)" "Tailscale Login Error" ([System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

Function Show-InputBox {
    Param([string]$Prompt)

    return [Microsoft.VisualBasic.Interaction]::InputBox(
        $Prompt,
        "Create RustDesk Instance",
        "instance1"
    )
}

Function Show-ConfigWindow {
    Param([scriptblock]$OnSave)

    $ConfigForm = New-Object System.Windows.Forms.Form
    $ConfigForm.Text = "Configuration"
    $ConfigForm.Size = New-Object System.Drawing.Size(650, 325)
    $ConfigForm.FormBorderStyle = "FixedDialog"
    $ConfigForm.MaximizeBox = $false
    $ConfigForm.StartPosition = "CenterParent"

    $LabelExe = New-Object System.Windows.Forms.Label
    $LabelExe.Text = "RustDesk.exe path:"
    $LabelExe.Size = New-Object System.Drawing.Size(130, 25)
    $LabelExe.Location = New-Object System.Drawing.Point(20, 25)
    $ConfigForm.Controls.Add($LabelExe)

    $TextExe = New-Object System.Windows.Forms.TextBox
    $TextExe.Size = New-Object System.Drawing.Size(370, 25)
    $TextExe.Location = New-Object System.Drawing.Point(155, 22)
    $TextExe.Text = $global:RustDeskExePath
    $ConfigForm.Controls.Add($TextExe)

    $ButtonBrowseExe = New-Object System.Windows.Forms.Button
    $ButtonBrowseExe.Text = "Browse"
    $ButtonBrowseExe.Size = New-Object System.Drawing.Size(80, 25)
    $ButtonBrowseExe.Location = New-Object System.Drawing.Point(535, 21)
    $ButtonBrowseExe.add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "RustDesk Executable|RustDesk.exe|Executable Files (*.exe)|*.exe"
        $openFileDialog.Title = "Select RustDesk.exe"

        if ($TextExe.Text -and (Test-Path $TextExe.Text)) {
            $openFileDialog.InitialDirectory = Split-Path $TextExe.Text -Parent
        }

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $TextExe.Text = $openFileDialog.FileName
        }
    })
    $ConfigForm.Controls.Add($ButtonBrowseExe)

    $LabelInstance = New-Object System.Windows.Forms.Label
    $LabelInstance.Text = "Instance path:"
    $LabelInstance.Size = New-Object System.Drawing.Size(130, 25)
    $LabelInstance.Location = New-Object System.Drawing.Point(20, 70)
    $ConfigForm.Controls.Add($LabelInstance)

    $TextInstance = New-Object System.Windows.Forms.TextBox
    $TextInstance.Size = New-Object System.Drawing.Size(370, 25)
    $TextInstance.Location = New-Object System.Drawing.Point(155, 67)
    $TextInstance.Text = $global:IPATH
    $ConfigForm.Controls.Add($TextInstance)

    $ButtonBrowseInstance = New-Object System.Windows.Forms.Button
    $ButtonBrowseInstance.Text = "Browse"
    $ButtonBrowseInstance.Size = New-Object System.Drawing.Size(80, 25)
    $ButtonBrowseInstance.Location = New-Object System.Drawing.Point(535, 66)
    $ButtonBrowseInstance.add_Click({
        $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowserDialog.Description = "Select or create the parent folder where RustDesk instances will be stored"
        $folderBrowserDialog.ShowNewFolderButton = $true

        if ($TextInstance.Text -and (Test-Path $TextInstance.Text)) {
            $folderBrowserDialog.SelectedPath = $TextInstance.Text
        }

        if ($folderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $TextInstance.Text = $folderBrowserDialog.SelectedPath
        }
    })
    $ConfigForm.Controls.Add($ButtonBrowseInstance)

    $LabelTailscaleExe = New-Object System.Windows.Forms.Label
    $LabelTailscaleExe.Text = "Tailscale.exe path:"
    $LabelTailscaleExe.Size = New-Object System.Drawing.Size(130, 25)
    $LabelTailscaleExe.Location = New-Object System.Drawing.Point(20, 115)
    $ConfigForm.Controls.Add($LabelTailscaleExe)

    $TextTailscaleExe = New-Object System.Windows.Forms.TextBox
    $TextTailscaleExe.Size = New-Object System.Drawing.Size(370, 25)
    $TextTailscaleExe.Location = New-Object System.Drawing.Point(155, 112)
    $TextTailscaleExe.Text = $global:TailscaleExePath
    $ConfigForm.Controls.Add($TextTailscaleExe)

    $ButtonBrowseTailscaleExe = New-Object System.Windows.Forms.Button
    $ButtonBrowseTailscaleExe.Text = "Browse"
    $ButtonBrowseTailscaleExe.Size = New-Object System.Drawing.Size(80, 25)
    $ButtonBrowseTailscaleExe.Location = New-Object System.Drawing.Point(535, 111)
    $ButtonBrowseTailscaleExe.add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "Tailscale Executable|tailscale.exe|Executable Files (*.exe)|*.exe"
        $openFileDialog.Title = "Select tailscale.exe"

        $autoPath = Get-TailscaleExecutable
        if ($TextTailscaleExe.Text -and (Test-Path $TextTailscaleExe.Text)) {
            $openFileDialog.InitialDirectory = Split-Path $TextTailscaleExe.Text -Parent
        }
        elseif ($autoPath -and (Test-Path $autoPath)) {
            $openFileDialog.InitialDirectory = Split-Path $autoPath -Parent
        }

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $TextTailscaleExe.Text = $openFileDialog.FileName
        }
    })
    $ConfigForm.Controls.Add($ButtonBrowseTailscaleExe)

    $CheckTailscaleEnabled = New-Object System.Windows.Forms.CheckBox
    $CheckTailscaleEnabled.Text = "Enable Tailscale switching"
    $CheckTailscaleEnabled.Size = New-Object System.Drawing.Size(220, 25)
    $CheckTailscaleEnabled.Location = New-Object System.Drawing.Point(155, 150)
    $CheckTailscaleEnabled.Checked = $global:TailscaleEnabled
    $ConfigForm.Controls.Add($CheckTailscaleEnabled)

    $ButtonSave = New-Object System.Windows.Forms.Button
    $ButtonSave.Text = "Save"
    $ButtonSave.Size = New-Object System.Drawing.Size(100, 32)
    $ButtonSave.Location = New-Object System.Drawing.Point(310, 215)
    $ButtonSave.add_Click({
        $global:RustDeskExePath = $TextExe.Text.Trim()
        $global:IPATH = $TextInstance.Text.Trim()
        $global:TailscaleExePath = $TextTailscaleExe.Text.Trim()
        $global:TailscaleEnabled = [bool]$CheckTailscaleEnabled.Checked

        Save-ToolConfig

        if ($OnSave) { & $OnSave }

        Show-Message "Configuration saved."
        $ConfigForm.Close()
    })
    $ConfigForm.Controls.Add($ButtonSave)

    $ButtonCancel = New-Object System.Windows.Forms.Button
    $ButtonCancel.Text = "Cancel"
    $ButtonCancel.Size = New-Object System.Drawing.Size(100, 32)
    $ButtonCancel.Location = New-Object System.Drawing.Point(420, 215)
    $ButtonCancel.add_Click({ $ConfigForm.Close() })
    $ConfigForm.Controls.Add($ButtonCancel)

    $ConfigForm.ShowDialog() | Out-Null
}

Function Create-GUI {
    Load-ToolConfig
    Repair-OldJunctionSetup

    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "RustDesk Multi-Instance Manager $($global:AppVersion)"
    $Form.Size = New-Object System.Drawing.Size(650, 675)
    $Form.FormBorderStyle = "FixedDialog"
    $Form.MaximizeBox = $false
    $Form.StartPosition = "CenterScreen"

    $MenuStrip = New-Object System.Windows.Forms.MenuStrip

    $MenuFile = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList "File"
    $MenuConfig = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList "Config"
    $MenuConfig.add_Click({
        Show-ConfigWindow -OnSave {
            UpdateTailscaleControls
            UpdateListView $global:IPATH
        }
    })
    $MenuExit = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList "Exit"
    $MenuExit.add_Click({ $Form.Close() })
    $MenuFile.DropDownItems.Add($MenuConfig) | Out-Null
    $MenuFile.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    $MenuFile.DropDownItems.Add($MenuExit) | Out-Null

    $MenuHelp = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList "Help"
    $MenuHelpInstructions = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList "Help"
    $MenuHelpInstructions.add_Click({ Show-HelpWindow })
    $MenuAbout = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList "About"
    $MenuAbout.add_Click({ Show-AboutWindow })
    $MenuHelp.DropDownItems.Add($MenuHelpInstructions) | Out-Null
    $MenuHelp.DropDownItems.Add($MenuAbout) | Out-Null

    $MenuStrip.Items.Add($MenuFile) | Out-Null
    $MenuStrip.Items.Add($MenuHelp) | Out-Null
    $Form.MainMenuStrip = $MenuStrip
    $Form.Controls.Add($MenuStrip)


    # -----------------------------
    # RustDesk section
    # -----------------------------
    $RustDeskGroup = New-Object System.Windows.Forms.GroupBox
    $RustDeskGroup.Text = ""
    $RustDeskGroup.Size = New-Object System.Drawing.Size(610, 365)
    $RustDeskGroup.Location = New-Object System.Drawing.Point(15, 35)
    $Form.Controls.Add($RustDeskGroup)

    $RustDeskHeaderLabel = New-Object System.Windows.Forms.Label
    $RustDeskHeaderLabel.Text = "RUSTDESK INSTANCES"
    $RustDeskHeaderLabel.Font = New-Object System.Drawing.Font($RustDeskGroup.Font.FontFamily, ($RustDeskGroup.Font.Size + 2), [System.Drawing.FontStyle]::Bold)
    $RustDeskHeaderLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $RustDeskHeaderLabel.Size = New-Object System.Drawing.Size(580, 28)
    $RustDeskHeaderLabel.Location = New-Object System.Drawing.Point(15, 15)
    $RustDeskGroup.Controls.Add($RustDeskHeaderLabel)

    $InstanceGrid = New-Object System.Windows.Forms.DataGridView
    $InstanceGrid.Size = New-Object System.Drawing.Size(580, 205)
    $InstanceGrid.Location = New-Object System.Drawing.Point(15, 50)
    $InstanceGrid.AllowUserToAddRows = $false
    $InstanceGrid.AllowUserToDeleteRows = $false
    $InstanceGrid.AllowUserToResizeRows = $false
    $InstanceGrid.ReadOnly = $true
    $InstanceGrid.MultiSelect = $false
    $InstanceGrid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $InstanceGrid.RowHeadersVisible = $false
    $InstanceGrid.ColumnHeadersVisible = $true
    $InstanceGrid.EnableHeadersVisualStyles = $false
    $InstanceGrid.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $InstanceGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
    $InstanceGrid.BackgroundColor = [System.Drawing.SystemColors]::Window
    $InstanceGrid.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
    $InstanceGrid.GridColor = [System.Drawing.SystemColors]::ControlLight
    $InstanceGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $InstanceGrid.ColumnHeadersHeight = 32
    $InstanceGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font($InstanceGrid.Font.FontFamily, ($InstanceGrid.Font.Size + 1), [System.Drawing.FontStyle]::Regular)
    $InstanceGrid.ColumnHeadersDefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
    $InstanceGrid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.SystemColors]::Control
    $InstanceGrid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.SystemColors]::ControlText
    $InstanceGrid.DefaultCellStyle.SelectionBackColor = [System.Drawing.SystemColors]::Highlight
    $InstanceGrid.DefaultCellStyle.SelectionForeColor = [System.Drawing.SystemColors]::HighlightText

    $RustDeskColumnIndex = $InstanceGrid.Columns.Add("InstanceName", "RUSTDESK INSTANCES")
    $TailscaleColumnIndex = $InstanceGrid.Columns.Add("TailscaleAccount", "TAILSCALE ACCOUNT")
    $InstanceGrid.Columns[$RustDeskColumnIndex].Width = 290
    $InstanceGrid.Columns[$TailscaleColumnIndex].Width = 270
    $InstanceGrid.Columns[$RustDeskColumnIndex].SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
    $InstanceGrid.Columns[$TailscaleColumnIndex].SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
    $InstanceGrid.Columns[$RustDeskColumnIndex].DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleLeft
    $InstanceGrid.Columns[$TailscaleColumnIndex].DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleLeft
    $RustDeskGroup.Controls.Add($InstanceGrid)

    $ButtonCreateInstanz = New-Object System.Windows.Forms.Button
    $ButtonCreateInstanz.Text = "Create Instance"
    $ButtonCreateInstanz.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonCreateInstanz.Location = New-Object System.Drawing.Point(415, 265)
    $ButtonCreateInstanz.add_Click({
        if ([string]::IsNullOrWhiteSpace($global:IPATH)) {
            Show-Message "Please set the Instance Path in Config first." "Missing Instance Path" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        if (!(Test-Path $global:IPATH)) {
            New-Item -ItemType Directory -Path $global:IPATH -Force | Out-Null
        }

        Backup-DefaultProfileOnce

        $instanzName = Show-InputBox -Prompt "Enter Instance Name"

        if ([string]::IsNullOrWhiteSpace($instanzName)) {
            Show-Message "No instance name entered." "Create Instance" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        foreach ($char in $invalidChars) {
            $instanzName = $instanzName.Replace($char, "_")
        }

        $newInstanzPath = Join-Path -Path $global:IPATH -ChildPath $instanzName
        $destinationPath = Get-InstanceRustDeskConfigPath $newInstanzPath

        if (Test-Path $newInstanzPath) {
            Show-Message "Instance '$instanzName' already exists." "Create Instance" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        try {
            New-Item -ItemType Directory -Path $newInstanzPath -Force | Out-Null

            $sourcePath = Get-RealRustDeskConfigPath

            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force
            }
            else {
                New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
            }

            UpdateListView $global:IPATH
            Show-Message "New instance '$instanzName' created successfully.`n`nConfig path:`n$destinationPath"
        }
        catch {
            Show-Message "Failed to create instance:`n$($_.Exception.Message)" "Create Instance Error" ([System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $RustDeskGroup.Controls.Add($ButtonCreateInstanz)

    $ButtonStart = New-Object System.Windows.Forms.Button
    $ButtonStart.Text = "Switch && Start"
    $ButtonStart.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonStart.Location = New-Object System.Drawing.Point(15, 265)
    $ButtonStart.add_Click({
        if ([string]::IsNullOrWhiteSpace($global:RustDeskExePath)) {
            Show-Message "Please set RustDesk.exe path in Config first." "Missing RustDesk.exe" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        if (!(Test-Path $global:RustDeskExePath)) {
            Show-Message "RustDesk.exe was not found:`n$($global:RustDeskExePath)" "Invalid RustDesk.exe" ([System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        $selected = Get-SelectedInstanceNameAndPath
        if ($null -eq $selected) { return }

        try {
            Activate-InstanceProfile -InstanceName $selected.Name -InstancePath $selected.Path
            Switch-TailscaleForInstance -InstanceName $selected.Name
            UpdateListView $global:IPATH
            if ($global:TailscaleEnabled) { RefreshTailscaleAccounts }

            Start-Process -FilePath $global:RustDeskExePath -WorkingDirectory (Split-Path -Path $global:RustDeskExePath -Parent)
        }
        catch {
            Show-Message "Failed to switch/start RustDesk:`n$($_.Exception.Message)" "Start Error" ([System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $RustDeskGroup.Controls.Add($ButtonStart)

    $ButtonRefresh = New-Object System.Windows.Forms.Button
    $ButtonRefresh.Text = "Refresh List"
    $ButtonRefresh.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonRefresh.Location = New-Object System.Drawing.Point(215, 265)
    $ButtonRefresh.add_Click({
        UpdateListView $global:IPATH
    })
    $RustDeskGroup.Controls.Add($ButtonRefresh)

    $ButtonRemoveInstance = New-Object System.Windows.Forms.Button
    $ButtonRemoveInstance.Text = "Remove Instance"
    $ButtonRemoveInstance.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonRemoveInstance.Location = New-Object System.Drawing.Point(415, 305)
    $ButtonRemoveInstance.add_Click({
        $selected = Get-SelectedInstanceNameAndPath
        if ($null -eq $selected) { return }

        if (!(Test-Path $selected.Path)) {
            Show-Message "Instance folder was not found:`n$($selected.Path)" "Remove Instance" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            UpdateListView $global:IPATH
            return
        }

        $activeNote = ""
        if ($selected.Name -eq (Get-ActiveInstanceName)) {
            $activeNote = "`n`nThis instance is currently marked ACTIVE. Removing it will clear the active marker, but it will not delete the currently loaded RustDesk profile in %APPDATA%\RustDesk."
        }

        $confirmMessage = "Delete RustDesk instance '$($selected.Name)'?`n`nThis will permanently delete this folder:`n$($selected.Path)$activeNote`n`nChoose Yes to delete it, or No to cancel."
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $confirmMessage,
            "Confirm Remove Instance",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        try {
            Stop-RustDesk
            Remove-Item -Path $selected.Path -Recurse -Force

            if ($selected.Name -eq (Get-ActiveInstanceName)) {
                Clear-ActiveInstanceName
            }

            if ($global:InstanceTailscaleMap.ContainsKey($selected.Name)) {
                $global:InstanceTailscaleMap.Remove($selected.Name)
                Save-ToolConfig
            }

            UpdateListView $global:IPATH
            Show-Message "Instance '$($selected.Name)' was removed." "Remove Instance" ([System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            Show-Message "Failed to remove instance:`n$($_.Exception.Message)" "Remove Instance Error" ([System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $RustDeskGroup.Controls.Add($ButtonRemoveInstance)


    $ButtonRestoreDefault = New-Object System.Windows.Forms.Button
    $ButtonRestoreDefault.Text = "Restore Default Profile"
    $ButtonRestoreDefault.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonRestoreDefault.Location = New-Object System.Drawing.Point(15, 305)
    $ButtonRestoreDefault.add_Click({
        Restore-DefaultProfile
        UpdateListView $global:IPATH
    })
    $RustDeskGroup.Controls.Add($ButtonRestoreDefault)

    $ButtonOpenConfigFolder = New-Object System.Windows.Forms.Button
    $ButtonOpenConfigFolder.Text = "Open Tool Config Folder"
    $ButtonOpenConfigFolder.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonOpenConfigFolder.Location = New-Object System.Drawing.Point(215, 305)
    $ButtonOpenConfigFolder.add_Click({
        Ensure-ToolConfigDir
        Start-Process explorer.exe $global:ToolConfigDir
    })
    $RustDeskGroup.Controls.Add($ButtonOpenConfigFolder)

    # -----------------------------
    # Tailscale section
    # -----------------------------
    $TailscaleGroup = New-Object System.Windows.Forms.GroupBox
    $TailscaleGroup.Text = ""
    $TailscaleGroup.Size = New-Object System.Drawing.Size(610, 180)
    $TailscaleGroup.Location = New-Object System.Drawing.Point(15, 425)
    $Form.Controls.Add($TailscaleGroup)

    $TailscaleHeaderLabel = New-Object System.Windows.Forms.Label
    $TailscaleHeaderLabel.Text = "TAILSCALE ACCOUNTS"
    $TailscaleHeaderLabel.Font = New-Object System.Drawing.Font($TailscaleGroup.Font.FontFamily, ($TailscaleGroup.Font.Size + 2), [System.Drawing.FontStyle]::Bold)
    $TailscaleHeaderLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $TailscaleHeaderLabel.Size = New-Object System.Drawing.Size(580, 28)
    $TailscaleHeaderLabel.Location = New-Object System.Drawing.Point(15, 15)
    $TailscaleGroup.Controls.Add($TailscaleHeaderLabel)

    $CheckEnableTailscale = New-Object System.Windows.Forms.CheckBox
    $CheckEnableTailscale.Text = "Enable Tailscale functionality"
    $CheckEnableTailscale.Size = New-Object System.Drawing.Size(240, 24)
    $CheckEnableTailscale.Location = New-Object System.Drawing.Point(15, 45)
    $CheckEnableTailscale.Checked = $global:TailscaleEnabled
    $CheckEnableTailscale.add_CheckedChanged({
        $global:TailscaleEnabled = [bool]$CheckEnableTailscale.Checked
        Save-ToolConfig
        UpdateTailscaleControls
        UpdateListView $global:IPATH
        if ($global:TailscaleEnabled) { RefreshTailscaleAccounts }
    })
    $TailscaleGroup.Controls.Add($CheckEnableTailscale)

    $LabelTailscale = New-Object System.Windows.Forms.Label
    $LabelTailscale.Text = "Available Tailscale accounts:"
    $LabelTailscale.Size = New-Object System.Drawing.Size(260, 22)
    $LabelTailscale.Location = New-Object System.Drawing.Point(15, 78)
    $TailscaleGroup.Controls.Add($LabelTailscale)

    $ComboTailscaleAccounts = New-Object System.Windows.Forms.ComboBox
    $ComboTailscaleAccounts.Size = New-Object System.Drawing.Size(380, 25)
    $ComboTailscaleAccounts.Location = New-Object System.Drawing.Point(15, 103)
    $ComboTailscaleAccounts.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $ComboTailscaleAccounts.FormattingEnabled = $true
    $TailscaleGroup.Controls.Add($ComboTailscaleAccounts)

    $ButtonRefreshTailscale = New-Object System.Windows.Forms.Button
    $ButtonRefreshTailscale.Text = "Refresh Tailscale"
    $ButtonRefreshTailscale.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonRefreshTailscale.Location = New-Object System.Drawing.Point(415, 101)
    $TailscaleGroup.Controls.Add($ButtonRefreshTailscale)

    $ButtonAssociateTailscale = New-Object System.Windows.Forms.Button
    $ButtonAssociateTailscale.Text = "Associate Tailscale"
    $ButtonAssociateTailscale.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonAssociateTailscale.Location = New-Object System.Drawing.Point(15, 138)
    $ButtonAssociateTailscale.add_Click({
        if (!$global:TailscaleEnabled) {
            Show-Message "Tailscale functionality is disabled. Enable it first if you want to associate a Tailscale account." "Tailscale Disabled" ([System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        $selected = Get-SelectedInstanceNameAndPath
        if ($null -eq $selected) { return }

        if ($ComboTailscaleAccounts.SelectedItem -eq $null) {
            Show-Message "Please select a Tailscale account first." "No Tailscale Account Selected" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $account = [string]$ComboTailscaleAccounts.SelectedItem.Account
        Set-InstanceTailscaleAccount -InstanceName $selected.Name -Account $account
        UpdateListView $global:IPATH
        Show-Message "Associated '$($selected.Name)' with Tailscale account:`n$account"
    })
    $TailscaleGroup.Controls.Add($ButtonAssociateTailscale)

    $ButtonClearTailscale = New-Object System.Windows.Forms.Button
    $ButtonClearTailscale.Text = "Clear Association"
    $ButtonClearTailscale.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonClearTailscale.Location = New-Object System.Drawing.Point(215, 138)
    $ButtonClearTailscale.add_Click({
        $selected = Get-SelectedInstanceNameAndPath
        if ($null -eq $selected) { return }

        Set-InstanceTailscaleAccount -InstanceName $selected.Name -Account ""
        UpdateListView $global:IPATH
        Show-Message "Cleared Tailscale association for '$($selected.Name)'."
    })
    $TailscaleGroup.Controls.Add($ButtonClearTailscale)

    $ButtonLoginTailscale = New-Object System.Windows.Forms.Button
    $ButtonLoginTailscale.Text = "Add/Login Tailscale Account"
    $ButtonLoginTailscale.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonLoginTailscale.Location = New-Object System.Drawing.Point(415, 138)
    $ButtonLoginTailscale.add_Click({
        Start-TailscaleLogin
        RefreshTailscaleAccounts
    })
    $TailscaleGroup.Controls.Add($ButtonLoginTailscale)

    Function RefreshTailscaleAccounts {
        $ComboTailscaleAccounts.Items.Clear()

        if (!$global:TailscaleEnabled) {
            return
        }

        try {
            $accounts = Get-TailscaleAccounts
            foreach ($account in $accounts) {
                $ComboTailscaleAccounts.Items.Add($account) | Out-Null
            }

            if ($ComboTailscaleAccounts.Items.Count -gt 0) {
                $ComboTailscaleAccounts.SelectedIndex = 0
            }
        }
        catch {
            Show-Message "Failed to list Tailscale accounts:`n$($_.Exception.Message)" "Tailscale Error" ([System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }

    $ComboTailscaleAccounts.add_Format({
        Param($sender, $e)
        if ($e.ListItem -ne $null) {
            if ($e.ListItem.PSObject.Properties.Name -contains "DropdownDisplay") {
                $e.Value = $e.ListItem.DropdownDisplay
            }
            else {
                $e.Value = $e.ListItem.Display
            }
        }
    })

    $ButtonRefreshTailscale.add_Click({ RefreshTailscaleAccounts })

    Function UpdateTailscaleControls {
        $CheckEnableTailscale.Checked = $global:TailscaleEnabled

        $LabelTailscale.Enabled = $global:TailscaleEnabled
        $ComboTailscaleAccounts.Enabled = $global:TailscaleEnabled
        $ButtonAssociateTailscale.Enabled = $global:TailscaleEnabled
        $ButtonRefreshTailscale.Enabled = $global:TailscaleEnabled
        $ButtonLoginTailscale.Enabled = $global:TailscaleEnabled
        $ButtonClearTailscale.Enabled = $global:TailscaleEnabled

        if (!$global:TailscaleEnabled) {
            $ComboTailscaleAccounts.Items.Clear()
        }
    }

    Function UpdateListView {
        Param([string]$path)

        $InstanceGrid.Rows.Clear()

        if ([string]::IsNullOrWhiteSpace($path)) { return }
        if (!(Test-Path $path)) { return }

        $instanzDirs = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

        foreach ($dir in $instanzDirs) {
            $displayName = $dir

            if ($dir -eq (Get-ActiveInstanceName)) {
                $displayName = "$dir  [ACTIVE]"
            }

            $mappedAccount = Get-InstanceTailscaleAccount -InstanceName $dir
            $mappedDisplay = Resolve-TailscaleMappingDisplay -MappedAccount $mappedAccount

            $rowIndex = $InstanceGrid.Rows.Add($displayName, $mappedDisplay)
            $InstanceGrid.Rows[$rowIndex].Tag = $dir
        }

        $InstanceGrid.ClearSelection()
    }

    Function Get-SelectedInstanceNameAndPath {
        if ([string]::IsNullOrWhiteSpace($global:IPATH)) {
            Show-Message "Please set the Instance Path in Config first." "Missing Instance Path" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return $null
        }

        if ($InstanceGrid.SelectedRows.Count -ne 1) {
            Show-Message "Please select one instance from the list." "No Instance Selected" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return $null
        }

        $selectedRow = $InstanceGrid.SelectedRows[0]
        $name = [string]$selectedRow.Tag

        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = ([string]$selectedRow.Cells[0].Value).Replace("  [ACTIVE]", "")
        }

        $path = Join-Path -Path $global:IPATH -ChildPath $name

        return [PSCustomObject]@{
            Name = $name
            Path = $path
        }
    }

    UpdateTailscaleControls
    UpdateListView $global:IPATH
    if ($global:TailscaleEnabled) { RefreshTailscaleAccounts }

    $Form.ShowDialog() | Out-Null
}

Create-GUI

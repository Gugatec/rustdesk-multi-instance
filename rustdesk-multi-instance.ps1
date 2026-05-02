# Managemetn GUI for RustDesk Multi-Instance Selection
#
# Original script by suuhm (c) 2024
#
# Reactored by Gugatec May 2026
#
#Run it on Powershell 5.x

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

[System.Windows.Forms.Application]::EnableVisualStyles()

[string]$global:IPATH = ""
[string]$global:RustDeskExePath = ""

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
    }
    catch {
        Show-Message "Failed to load config:`n$($_.Exception.Message)" "Config Error" ([System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}

Function Save-ToolConfig {
    try {
        Ensure-ToolConfigDir

        $config = [PSCustomObject]@{
            RustDeskExePath = $global:RustDeskExePath
            InstancePath    = $global:IPATH
        }

        $config | ConvertTo-Json | Set-Content -Path $global:ToolConfigFile -Encoding UTF8
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
    $ConfigForm.Size = New-Object System.Drawing.Size(650, 230)
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

    $ButtonSave = New-Object System.Windows.Forms.Button
    $ButtonSave.Text = "Save"
    $ButtonSave.Size = New-Object System.Drawing.Size(100, 32)
    $ButtonSave.Location = New-Object System.Drawing.Point(310, 130)
    $ButtonSave.add_Click({
        $global:RustDeskExePath = $TextExe.Text.Trim()
        $global:IPATH = $TextInstance.Text.Trim()

        Save-ToolConfig

        if ($OnSave) { & $OnSave }

        Show-Message "Configuration saved."
        $ConfigForm.Close()
    })
    $ConfigForm.Controls.Add($ButtonSave)

    $ButtonCancel = New-Object System.Windows.Forms.Button
    $ButtonCancel.Text = "Cancel"
    $ButtonCancel.Size = New-Object System.Drawing.Size(100, 32)
    $ButtonCancel.Location = New-Object System.Drawing.Point(420, 130)
    $ButtonCancel.add_Click({ $ConfigForm.Close() })
    $ConfigForm.Controls.Add($ButtonCancel)

    $ConfigForm.ShowDialog() | Out-Null
}

Function Create-GUI {
    Load-ToolConfig
    Repair-OldJunctionSetup

    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "RustDesk Profile Switcher v8"
    $Form.Size = New-Object System.Drawing.Size(450, 510)
    $Form.FormBorderStyle = "FixedDialog"
    $Form.MaximizeBox = $false
    $Form.StartPosition = "CenterScreen"

    $ButtonConfig = New-Object System.Windows.Forms.Button
    $ButtonConfig.Text = "Config"
    $ButtonConfig.Size = New-Object System.Drawing.Size(390, 30)
    $ButtonConfig.Location = New-Object System.Drawing.Point(20, 20)
    $ButtonConfig.add_Click({
        Show-ConfigWindow -OnSave {
            UpdateListView $global:IPATH
        }
    })
    $Form.Controls.Add($ButtonConfig)

    $ListView = New-Object System.Windows.Forms.ListView
    $ListView.Size = New-Object System.Drawing.Size(390, 180)
    $ListView.Location = New-Object System.Drawing.Point(20, 65)
    $ListView.View = [System.Windows.Forms.View]::Details
    $ListView.FullRowSelect = $true
    $ListView.GridLines = $true
    $ListView.Columns.Add("Instances", 370) | Out-Null
    $Form.Controls.Add($ListView)

    Function UpdateListView {
        Param([string]$path)

        $ListView.Items.Clear()

        if ([string]::IsNullOrWhiteSpace($path)) { return }
        if (!(Test-Path $path)) { return }

        $instanzDirs = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

        foreach ($dir in $instanzDirs) {
            $listViewItem = New-Object System.Windows.Forms.ListViewItem
            $listViewItem.Text = $dir

            if ($dir -eq (Get-ActiveInstanceName)) {
                $listViewItem.Text = "$dir  [ACTIVE]"
            }

            $ListView.Items.Add($listViewItem) | Out-Null
        }
    }

    Function Get-SelectedInstanceNameAndPath {
        if ([string]::IsNullOrWhiteSpace($global:IPATH)) {
            Show-Message "Please set the Instance Path in Config first." "Missing Instance Path" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return $null
        }

        if ($ListView.SelectedItems.Count -ne 1) {
            Show-Message "Please select one instance from the list." "No Instance Selected" ([System.Windows.Forms.MessageBoxIcon]::Warning)
            return $null
        }

        $name = $ListView.SelectedItems[0].Text.Replace("  [ACTIVE]", "")
        $path = Join-Path -Path $global:IPATH -ChildPath $name

        return [PSCustomObject]@{
            Name = $name
            Path = $path
        }
    }

    $ButtonCreateInstanz = New-Object System.Windows.Forms.Button
    $ButtonCreateInstanz.Text = "Create Instance"
    $ButtonCreateInstanz.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonCreateInstanz.Location = New-Object System.Drawing.Point(20, 260)
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
    $Form.Controls.Add($ButtonCreateInstanz)

    $ButtonStart = New-Object System.Windows.Forms.Button
    $ButtonStart.Text = "Switch && Start"
    $ButtonStart.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonStart.Location = New-Object System.Drawing.Point(230, 260)
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
            UpdateListView $global:IPATH

            Start-Process -FilePath $global:RustDeskExePath -WorkingDirectory (Split-Path -Path $global:RustDeskExePath -Parent)
        }
        catch {
            Show-Message "Failed to switch/start RustDesk:`n$($_.Exception.Message)" "Start Error" ([System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $Form.Controls.Add($ButtonStart)

    $ButtonRefresh = New-Object System.Windows.Forms.Button
    $ButtonRefresh.Text = "Refresh List"
    $ButtonRefresh.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonRefresh.Location = New-Object System.Drawing.Point(20, 300)
    $ButtonRefresh.add_Click({
        UpdateListView $global:IPATH
    })
    $Form.Controls.Add($ButtonRefresh)

    $ButtonOpenInstanceFolder = New-Object System.Windows.Forms.Button
    $ButtonOpenInstanceFolder.Text = "Open Instance Folder"
    $ButtonOpenInstanceFolder.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonOpenInstanceFolder.Location = New-Object System.Drawing.Point(230, 300)
    $ButtonOpenInstanceFolder.add_Click({
        $selected = Get-SelectedInstanceNameAndPath
        if ($null -eq $selected) { return }

        if (Test-Path $selected.Path) {
            Start-Process explorer.exe $selected.Path
        }
    })
    $Form.Controls.Add($ButtonOpenInstanceFolder)

    $ButtonOpenConfigFolder = New-Object System.Windows.Forms.Button
    $ButtonOpenConfigFolder.Text = "Open Tool Config Folder"
    $ButtonOpenConfigFolder.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonOpenConfigFolder.Location = New-Object System.Drawing.Point(20, 340)
    $ButtonOpenConfigFolder.add_Click({
        Ensure-ToolConfigDir
        Start-Process explorer.exe $global:ToolConfigDir
    })
    $Form.Controls.Add($ButtonOpenConfigFolder)

    $ButtonRestoreDefault = New-Object System.Windows.Forms.Button
    $ButtonRestoreDefault.Text = "Restore Default Profile"
    $ButtonRestoreDefault.Size = New-Object System.Drawing.Size(180, 30)
    $ButtonRestoreDefault.Location = New-Object System.Drawing.Point(230, 340)
    $ButtonRestoreDefault.add_Click({
        Restore-DefaultProfile
        UpdateListView $global:IPATH
    })
    $Form.Controls.Add($ButtonRestoreDefault)

    $InfoLabel = New-Object System.Windows.Forms.Label
    $InfoLabel.Text = "Rustdesk Multi Instance Manager v8 - This version switches profiles by copying selected instance into the real %APPDATA%\RustDesk folder."
    $InfoLabel.Size = New-Object System.Drawing.Size(390, 50)
    $InfoLabel.Location = New-Object System.Drawing.Point(20, 390)
    $Form.Controls.Add($InfoLabel)

    UpdateListView $global:IPATH

    $Form.ShowDialog() | Out-Null
}

Create-GUI

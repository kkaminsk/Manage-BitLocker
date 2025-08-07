# Manage-BitLocker Application
# This script provides a graphical interface for managing BitLocker encryption status on Windows systems.

# Check for administrative privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Exit
}

# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$global:logFile = Join-Path $PSScriptRoot "Manage-BitLocker.log"
$global:systemDrive = $env:SystemDrive

# Logging function
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $global:logFile -Append
}

# BitLocker status check function
function Get-BitLockerStatus {
    try {
        $bitlockerVolume = Get-BitLockerVolume -MountPoint $global:systemDrive
        if ($bitlockerVolume.VolumeStatus -eq "FullyEncrypted") {
            return "Enabled"
        } else {
            return "Disabled"
        }
    } catch {
        Write-Log "Error checking BitLocker status: $_"
        return "Unknown"
    }
}

# Enable BitLocker function
function Enable-BitLockerEncryption {
    try {
        Enable-BitLocker -MountPoint $global:systemDrive -UsedSpaceOnly -SkipHardwareTest
        Write-Log "BitLocker encryption enabled successfully"
        [System.Windows.Forms.MessageBox]::Show("BitLocker encryption has been enabled.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        Write-Log "Error enabling BitLocker: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to enable BitLocker encryption. Please check the log for details.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Disable BitLocker function
function Disable-BitLockerEncryption {
    try {
        Disable-BitLocker -MountPoint $global:systemDrive
        Write-Log "BitLocker encryption disabled successfully"
        [System.Windows.Forms.MessageBox]::Show("BitLocker encryption has been disabled.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        Write-Log "Error disabling BitLocker: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to disable BitLocker encryption. Please check the log for details.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Manage-BitLocker"
$form.Size = New-Object System.Drawing.Size(400,300)
$form.StartPosition = "CenterScreen"

# Create status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10,20)
$statusLabel.Size = New-Object System.Drawing.Size(380,20)
$form.Controls.Add($statusLabel)

# Create last checked label
$lastCheckedLabel = New-Object System.Windows.Forms.Label
$lastCheckedLabel.Location = New-Object System.Drawing.Point(10,50)
$lastCheckedLabel.Size = New-Object System.Drawing.Size(380,20)
$form.Controls.Add($lastCheckedLabel)

# Create Enable button
$enableButton = New-Object System.Windows.Forms.Button
$enableButton.Location = New-Object System.Drawing.Point(10,100)
$enableButton.Size = New-Object System.Drawing.Size(120,40)
$enableButton.Text = "Enable BitLocker"
$enableButton.Add_Click({
    Enable-BitLockerEncryption
    UpdateStatus
})
$form.Controls.Add($enableButton)

# Create Disable button
$disableButton = New-Object System.Windows.Forms.Button
$disableButton.Location = New-Object System.Drawing.Point(140,100)
$disableButton.Size = New-Object System.Drawing.Size(120,40)
$disableButton.Text = "Disable BitLocker"
$disableButton.Add_Click({
    Disable-BitLockerEncryption
    UpdateStatus
})
$form.Controls.Add($disableButton)

# Create Refresh button
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(270,100)
$refreshButton.Size = New-Object System.Drawing.Size(120,40)
$refreshButton.Text = "Refresh Status"
$refreshButton.Add_Click({
    UpdateStatus
})
$form.Controls.Add($refreshButton)

# Create Exit button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(150,200)
$exitButton.Size = New-Object System.Drawing.Size(100,40)
$exitButton.Text = "Exit"
$exitButton.Add_Click({
    $form.Close()
})
$form.Controls.Add($exitButton)

# Function to update status
function UpdateStatus {
    $status = Get-BitLockerStatus
    $statusLabel.Text = "BitLocker Status: $status"
    $lastCheckedLabel.Text = "Last Checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "BitLocker status checked: $status"
}

# Initial status update
UpdateStatus

# Log application start
Write-Log "Manage-BitLocker application started"

# Show the form
$form.Add_Closing({ Write-Log "Manage-BitLocker application exited" })
$form.ShowDialog()

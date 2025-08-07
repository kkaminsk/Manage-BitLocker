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
        $bitlockerVolume = Get-BitLockerVolume -MountPoint $global:systemDrive | Where-Object { $_.VolumeType -eq 'OperatingSystem' }
        if ($bitlockerVolume) {
            return $bitlockerVolume.VolumeStatus
        } else {
            return "Not Found"
        }
    } catch {
        Write-Log "Error checking BitLocker status: $_"
        return "Error"
    }
}

# Function to check for and eject CD-ROM media
function Check-And-Eject-CDROMs {
    $cdRomDrives = Get-WmiObject Win32_CDROMDrive | Where-Object { $_.MediaLoaded -eq $true }
    if ($cdRomDrives) {
        $message = "The following CD/DVD drives have media loaded:`n`n"
        $cdRomDrives | ForEach-Object { $message += "$($_.Drive) - $($_.VolumeName)`n" }
        $message += "`nClick OK to eject all media. This is required before enabling BitLocker."
        $result = [System.Windows.Forms.MessageBox]::Show($message, "Media Detected", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $cdRomDrives | ForEach-Object { 
                try {
                    $drive = New-Object -ComObject Shell.Application
                    $drive.Namespace(17).ParseName($_.Drive).InvokeVerb("Eject")
                    Write-Log "Ejected media from drive $($_.Drive)"
                } catch {
                    Write-Log "Failed to eject media from drive $($_.Drive): $_"
                }
            }
            return $true
        } else {
            return $false
        }
    }
    return $true
}

# Function to handle system reboot
function Restart-SystemForBitLocker {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "A system restart is required to complete the BitLocker setup. Would you like to restart now?",
        "Restart Required",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "User initiated system restart for BitLocker setup"
        Restart-Computer -Force
    } else {
        Write-Log "User postponed system restart for BitLocker setup"
        [System.Windows.Forms.MessageBox]::Show(
            "Please remember to restart your computer to complete the BitLocker setup.",
            "Restart Postponed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
    }
}

# Enable BitLocker function
function Enable-BitLockerEncryption {
    try {
        $bitlockerVolume = Get-BitLockerVolume -MountPoint $global:systemDrive
        if ($bitlockerVolume.VolumeStatus -eq "DecryptionInProgress") {
            Write-Log "BitLocker decryption in progress. Cannot enable encryption at this time."
            [System.Windows.Forms.MessageBox]::Show("BitLocker decryption is currently in progress. Please wait for the decryption to finish before enabling BitLocker.", "Decryption in Progress", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        } else {
            if (Check-And-Eject-CDROMs) {
                try {
                    Enable-BitLocker -MountPoint $global:systemDrive -EncryptionMethod XtsAes256 -UsedSpaceOnly
                    Write-Log "BitLocker encryption enabled successfully"
                    [System.Windows.Forms.MessageBox]::Show("BitLocker encryption has been enabled.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } catch {
                    if ($_.Exception.Message -like "*Restart the computer to run a hardware test*") {
                        Write-Log "BitLocker requires a system restart to run hardware tests"
                        Restart-SystemForBitLocker
                    } else {
                        throw
                    }
                }
            } else {
                Write-Log "BitLocker encryption cancelled due to media in CD/DVD drives"
                [System.Windows.Forms.MessageBox]::Show("BitLocker encryption has been cancelled. Please eject all CD/DVD media and try again.", "Cancelled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
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
    $bitlockerVolume = Get-BitLockerVolume -MountPoint $global:systemDrive | Where-Object { $_.VolumeType -eq 'OperatingSystem' }
    if ($bitlockerVolume) {
        $status = $bitlockerVolume.VolumeStatus
        $encryptionPercentage = $bitlockerVolume.EncryptionPercentage
        $statusLabel.Text = "BitLocker Status: $status (Encryption: $encryptionPercentage%)"
    } else {
        $statusLabel.Text = "BitLocker Status: Not Found"
    }
    $lastCheckedLabel.Text = "Last Checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "BitLocker status checked: $($statusLabel.Text)"
}

# Initial status update
UpdateStatus

# Log application start
Write-Log "Manage-BitLocker application started"

# Show the form
$form.Add_Closing({ Write-Log "Manage-BitLocker application exited" })
$form.ShowDialog()

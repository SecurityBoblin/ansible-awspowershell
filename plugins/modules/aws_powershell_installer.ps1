#!powershell

# Copyright: (c) 2025, Your Name <your.email@example.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        modules = @{
            type = "list"
            elements = "str"
            required = $false
            default = @("AWS.Tools.S3", "AWS.Tools.EC2")
        }
        install_type = @{
            type = "str"
            choices = "modular", "monolithic"
            default = "modular"
        }
        state = @{
            type = "str"
            choices = "present", "absent", "latest"
            default = "present"
        }
        force = @{ type = "bool"; default = $false }
        allow_clobber = @{ type = "bool"; default = $true }
        skip_publisher_check = @{ type = "bool"; default = $false }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$modules_to_install = $module.Params.modules
$install_type = $module.Params.install_type
$state = $module.Params.state
$force = $module.Params.force
$allow_clobber = $module.Params.allow_clobber
$skip_publisher_check = $module.Params.skip_publisher_check

$module.Result.changed = $false
$module.Result.installed_modules = @()
$module.Result.removed_modules = @()
$module.Result.updated_modules = @()
$module.Result.skipped_modules = @()

# Function to get installed AWS modules
function Get-InstalledAWSModules {
    $installed = @{}

    if ($install_type -eq "monolithic") {
        $awsMod = Get-Module -ListAvailable -Name AWSPowerShell | Select-Object -First 1
        if ($awsMod) {
            $installed["AWSPowerShell"] = $awsMod.Version.ToString()
        }
    } else {
        # Check installer
        $installer = Get-Module -ListAvailable -Name AWS.Tools.Installer | Select-Object -First 1
        if ($installer) {
            $installed["AWS.Tools.Installer"] = $installer.Version.ToString()
        }

        # Check requested modules
        foreach ($modName in $modules_to_install) {
            $mod = Get-Module -ListAvailable -Name $modName | Select-Object -First 1
            if ($mod) {
                $installed[$modName] = $mod.Version.ToString()
            }
        }
    }

    return $installed
}

# Function to install AWS.Tools.Installer
function Install-AWSToolsInstallerModule {
    param([bool]$CheckMode)

    $installer = Get-Module -ListAvailable -Name AWS.Tools.Installer | Select-Object -First 1

    if (-not $installer) {
        if (-not $CheckMode) {
            $installParams = @{
                Name = "AWS.Tools.Installer"
                Force = $force
                AllowClobber = $allow_clobber
                ErrorAction = "Stop"
            }

            if ($skip_publisher_check) {
                $installParams.SkipPublisherCheck = $true
            }

            Install-Module @installParams
        }
        return $true
    }

    return $false
}

# Function to install modular AWS.Tools modules
function Install-ModularModules {
    param([bool]$CheckMode)

    $changed = $false
    $results = @{
        installed = @()
        updated = @()
        skipped = @()
    }

    # First ensure AWS.Tools.Installer is available
    $installerChanged = Install-AWSToolsInstallerModule -CheckMode $CheckMode
    if ($installerChanged) {
        $changed = $true
        $results.installed += "AWS.Tools.Installer"
    }

    # Import AWS.Tools.Installer if not in check mode
    if (-not $CheckMode) {
        Import-Module AWS.Tools.Installer -ErrorAction Stop
    }

    foreach ($modName in $modules_to_install) {
        $existingMod = Get-Module -ListAvailable -Name $modName | Select-Object -First 1

        if ($state -eq "present") {
            if (-not $existingMod) {
                if (-not $CheckMode) {
                    Install-AWSToolsModule -Name $modName -Force:$force -ErrorAction Stop
                }
                $results.installed += $modName
                $changed = $true
            } else {
                $results.skipped += "$modName (already installed v$($existingMod.Version))"
            }
        }
        elseif ($state -eq "latest") {
            if (-not $CheckMode) {
                Install-AWSToolsModule -Name $modName -Force -ErrorAction Stop
            }
            if ($existingMod) {
                $results.updated += "$modName (from v$($existingMod.Version))"
            } else {
                $results.installed += $modName
            }
            $changed = $true
        }
        elseif ($state -eq "absent") {
            if ($existingMod) {
                if (-not $CheckMode) {
                    Uninstall-AWSToolsModule -Name $modName -ErrorAction Stop
                }
                $results.installed += $modName
                $changed = $true
            } else {
                $results.skipped += "$modName (not installed)"
            }
        }
    }

    return @{
        changed = $changed
        results = $results
    }
}

# Function to install monolithic AWSPowerShell module
function Install-MonolithicModule {
    param([bool]$CheckMode)

    $changed = $false
    $results = @{
        installed = @()
        updated = @()
        skipped = @()
    }

    $existingMod = Get-Module -ListAvailable -Name AWSPowerShell | Select-Object -First 1

    if ($state -eq "present") {
        if (-not $existingMod) {
            if (-not $CheckMode) {
                $installParams = @{
                    Name = "AWSPowerShell"
                    Force = $force
                    AllowClobber = $allow_clobber
                    ErrorAction = "Stop"
                }

                if ($skip_publisher_check) {
                    $installParams.SkipPublisherCheck = $true
                }

                Install-Module @installParams
            }
            $results.installed += "AWSPowerShell"
            $changed = $true
        } else {
            $results.skipped += "AWSPowerShell (already installed v$($existingMod.Version))"
        }
    }
    elseif ($state -eq "latest") {
        if (-not $CheckMode) {
            $installParams = @{
                Name = "AWSPowerShell"
                Force = $true
                AllowClobber = $allow_clobber
                ErrorAction = "Stop"
            }

            if ($skip_publisher_check) {
                $installParams.SkipPublisherCheck = $true
            }

            Update-Module @installParams
        }
        if ($existingMod) {
            $results.updated += "AWSPowerShell (from v$($existingMod.Version))"
        } else {
            $results.installed += "AWSPowerShell"
        }
        $changed = $true
    }
    elseif ($state -eq "absent") {
        if ($existingMod) {
            if (-not $CheckMode) {
                Uninstall-Module -Name AWSPowerShell -AllVersions -Force -ErrorAction Stop
            }
            $results.installed += "AWSPowerShell"
            $changed = $true
        } else {
            $results.skipped += "AWSPowerShell (not installed)"
        }
    }

    return @{
        changed = $changed
        results = $results
    }
}

try {
    # Get initial state
    $initialModules = Get-InstalledAWSModules
    $module.Result.initial_state = $initialModules

    # Perform installation/removal
    if ($install_type -eq "modular") {
        $result = Install-ModularModules -CheckMode $module.CheckMode
    } else {
        $result = Install-MonolithicModule -CheckMode $module.CheckMode
    }

    $module.Result.changed = $result.changed
    $module.Result.installed_modules = $result.results.installed
    $module.Result.updated_modules = $result.results.updated
    $module.Result.skipped_modules = $result.results.skipped
    $module.Result.removed_modules = $result.results.removed

    # Get final state
    if (-not $module.CheckMode) {
        $finalModules = Get-InstalledAWSModules
        $module.Result.final_state = $finalModules
    }

    # Build summary message
    if ($module.Result.changed) {
        $msgParts = @()
        if ($result.results.installed.Count -gt 0) {
            $msgParts += "Installed: $($result.results.installed -join ', ')"
        }
        if ($result.results.updated.Count -gt 0) {
            $msgParts += "Updated: $($result.results.updated -join ', ')"
        }
        if ($result.results.removed.Count -gt 0) {
            $msgParts += "Removed: $($result.results.removed -join ', ')"
        }
        $module.Result.msg = $msgParts -join "; "
    } else {
        $module.Result.msg = "No changes required. Skipped: $($result.results.skipped -join ', ')"
    }

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()

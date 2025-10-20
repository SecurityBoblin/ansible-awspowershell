#!powershell

# Copyright: (c) 2025, Your Name <your.email@example.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        bucket = @{ type = "str"; required = $true }
        key = @{ type = "str"; required = $true }
        src = @{ type = "path"; required = $false }
        dest = @{ type = "path"; required = $false }
        state = @{
            type = "str"
            choices = "present", "absent", "download"
            default = "present"
        }
        aws_access_key = @{ type = "str"; required = $false; no_log = $true }
        aws_secret_key = @{ type = "str"; required = $false; no_log = $true }
        region = @{ type = "str"; required = $false; default = "us-east-1" }
        overwrite = @{ type = "bool"; default = $true }
    }
    required_if = @(
        @("state", "present", @("src")),
        @("state", "download", @("dest"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$bucket = $module.Params.bucket
$key = $module.Params.key
$src = $module.Params.src
$dest = $module.Params.dest
$state = $module.Params.state
$aws_access_key = $module.Params.aws_access_key
$aws_secret_key = $module.Params.aws_secret_key
$region = $module.Params.region
$overwrite = $module.Params.overwrite

$module.Result.changed = $false

# Function to check PowerShell module prerequisites
function Test-AWSPowerShellModule {
    param($Module, [string]$RequiredModule)

    $debugInfo = @{
        powershell_version = $PSVersionTable.PSVersion.ToString()
        required_module = $RequiredModule
        module_found = $false
        module_version = $null
        module_path = $null
        available_aws_modules = @()
        error = $null
    }

    try {
        # Get all available AWS modules
        $allAwsModules = Get-Module -ListAvailable -Name AWS* | Select-Object Name, Version, Path
        $debugInfo.available_aws_modules = $allAwsModules | ForEach-Object {
            @{
                name = $_.Name
                version = $_.Version.ToString()
                path = $_.Path
            }
        }

        # Check for specific required module
        $moduleInfo = Get-Module -ListAvailable -Name $RequiredModule | Select-Object -First 1
        if ($moduleInfo) {
            $debugInfo.module_found = $true
            $debugInfo.module_version = $moduleInfo.Version.ToString()
            $debugInfo.module_path = $moduleInfo.Path
            return $debugInfo
        }

        # Check for AWSPowerShell as fallback
        $awsPowerShell = Get-Module -ListAvailable -Name AWSPowerShell | Select-Object -First 1
        if ($awsPowerShell) {
            $debugInfo.required_module = "AWSPowerShell"
            $debugInfo.module_found = $true
            $debugInfo.module_version = $awsPowerShell.Version.ToString()
            $debugInfo.module_path = $awsPowerShell.Path
            return $debugInfo
        }

        # No suitable module found
        $debugInfo.error = "Neither $RequiredModule nor AWSPowerShell module is installed"
        return $debugInfo

    } catch {
        $debugInfo.error = $_.Exception.Message
        return $debugInfo
    }
}

# Function to set AWS credentials
function Set-AWSCredentials {
    param($Module)

    # Precheck: Verify AWS PowerShell module is available
    $moduleCheck = Test-AWSPowerShellModule -Module $Module -RequiredModule "AWS.Tools.S3"

    if (-not $moduleCheck.module_found) {
        $errorMsg = @"
AWS PowerShell module is not installed or not accessible.

Debug Information:
  PowerShell Version: $($moduleCheck.powershell_version)
  Required Module: $($moduleCheck.required_module)
  Module Found: $($moduleCheck.module_found)
  Error: $($moduleCheck.error)

Available AWS Modules: $($moduleCheck.available_aws_modules.Count)
$($moduleCheck.available_aws_modules | ForEach-Object { "  - $($_.name) (v$($_.version))" } | Out-String)

Installation Instructions:
  Option 1 (Modular - Recommended):
    Install-Module -Name AWS.Tools.Installer -Force
    Install-AWSToolsModule AWS.Tools.S3 -Force

  Option 2 (Monolithic):
    Install-Module -Name AWSPowerShell -Force

  Or use the aws_powershell_installer module from this collection.
"@
        $Module.FailJson($errorMsg)
    }

    # Add debug output to result
    $Module.Result.debug_info = @{
        aws_module = $moduleCheck.required_module
        module_version = $moduleCheck.module_version
        module_path = $moduleCheck.module_path
    }

    # Import the appropriate module
    try {
        if ($moduleCheck.required_module -eq "AWS.Tools.S3") {
            Import-Module AWS.Tools.S3 -ErrorAction Stop
        } else {
            Import-Module AWSPowerShell -ErrorAction Stop
        }
    } catch {
        $Module.FailJson("Failed to import AWS PowerShell module: $($_.Exception.Message)")
    }

    # Set credentials if provided
    if ($Module.Params.aws_access_key -and $Module.Params.aws_secret_key) {
        $secureSecret = ConvertTo-SecureString $Module.Params.aws_secret_key -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($Module.Params.aws_access_key, $secureSecret)
        Set-AWSCredential -AccessKey $Module.Params.aws_access_key -SecretKey $Module.Params.aws_secret_key -StoreAs ansible_temp
        $script:CredentialParam = @{ ProfileName = "ansible_temp" }
        $Module.Result.debug_info.credential_source = "module_parameters"
    }
    # Check for environment variables
    elseif ($env:AWS_ACCESS_KEY_ID -and $env:AWS_SECRET_ACCESS_KEY) {
        Set-AWSCredential -AccessKey $env:AWS_ACCESS_KEY_ID -SecretKey $env:AWS_SECRET_ACCESS_KEY -StoreAs ansible_temp_env
        $script:CredentialParam = @{ ProfileName = "ansible_temp_env" }
        $Module.Result.debug_info.credential_source = "environment_variables"
    }
    # Otherwise, rely on IAM role (default AWS PowerShell behavior)
    else {
        # No credentials set - AWS PowerShell will automatically use IAM role from instance metadata
        $script:CredentialParam = @{}
        $Module.Result.debug_info.credential_source = "iam_role"
    }
}

try {
    Set-AWSCredentials -Module $module

    # Common parameters for AWS cmdlets
    $awsParams = @{
        BucketName = $bucket
        Region = $region
    }

    if ($script:CredentialParam.Count -gt 0) {
        $awsParams += $script:CredentialParam
    }

    switch ($state) {
        "present" {
            # Upload file to S3
            if (-not (Test-Path -Path $src)) {
                $module.FailJson("Source file does not exist: $src")
            }

            # Check if object exists
            try {
                $existingObject = Get-S3Object @awsParams -Key $key -ErrorAction SilentlyContinue
                $objectExists = $null -ne $existingObject
            } catch {
                $objectExists = $false
            }

            if ($objectExists -and -not $overwrite) {
                $module.Result.msg = "Object already exists and overwrite is false"
            } else {
                if (-not $module.CheckMode) {
                    Write-S3Object @awsParams -File $src -Key $key -ErrorAction Stop
                }
                $module.Result.changed = $true
                $module.Result.msg = "File uploaded successfully to s3://$bucket/$key"
            }
        }

        "download" {
            # Download file from S3
            # Check if object exists
            try {
                $existingObject = Get-S3Object @awsParams -Key $key -ErrorAction Stop
            } catch {
                $module.FailJson("Object does not exist: s3://$bucket/$key")
            }

            # Check if destination file exists
            if ((Test-Path -Path $dest) -and -not $overwrite) {
                $module.Result.msg = "Destination file already exists and overwrite is false"
            } else {
                if (-not $module.CheckMode) {
                    Read-S3Object @awsParams -Key $key -File $dest -ErrorAction Stop
                }
                $module.Result.changed = $true
                $module.Result.msg = "File downloaded successfully from s3://$bucket/$key to $dest"
            }
        }

        "absent" {
            # Delete object from S3
            try {
                $existingObject = Get-S3Object @awsParams -Key $key -ErrorAction SilentlyContinue
                if ($null -ne $existingObject) {
                    if (-not $module.CheckMode) {
                        Remove-S3Object @awsParams -Key $key -Force -ErrorAction Stop
                    }
                    $module.Result.changed = $true
                    $module.Result.msg = "Object deleted successfully from s3://$bucket/$key"
                } else {
                    $module.Result.msg = "Object does not exist: s3://$bucket/$key"
                }
            } catch {
                $module.FailJson("Failed to delete object: $_")
            }
        }
    }

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()

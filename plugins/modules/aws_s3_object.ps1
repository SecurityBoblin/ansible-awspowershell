#!powershell

# Copyright: (c) 2025, Your Name <your.email@example.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

# WANT_JSON
# POWERSHELL_COMMON

<#
.SYNOPSIS
Manage S3 objects (upload, download, delete)

.DESCRIPTION
This module manages S3 objects using AWS PowerShell cmdlets.
It supports uploading files to S3, downloading files from S3, and deleting S3 objects.
Requires AWS.Tools.S3 or AWSPowerShell module to be installed on the target Windows host.

.PARAMETER bucket
The name of the S3 bucket.
Required: yes

.PARAMETER key
The S3 object key (path within the bucket).
Required: yes

.PARAMETER src
Local file path for upload. Required when state=present.

.PARAMETER dest
Local file path for download. Required when state=download.

.PARAMETER state
Desired state: present (upload), download, or absent (delete).
Default: present

.PARAMETER aws_access_key
AWS access key ID. If not provided, uses environment variables or IAM role.

.PARAMETER aws_secret_key
AWS secret access key. If not provided, uses environment variables or IAM role.

.PARAMETER region
AWS region.
Default: us-east-1

.PARAMETER overwrite
Whether to overwrite existing files/objects.
Default: true

.EXAMPLE
# Upload file to S3
- name: Upload file
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/data.json
    src: C:\temp\data.json
    state: present

.EXAMPLE
# Download file from S3
- name: Download file
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/data.json
    dest: C:\downloads\data.json
    state: download

.EXAMPLE
# Delete S3 object
- name: Delete object
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/old-data.json
    state: absent

.NOTES
Module: aws_s3_object
Author: Community
Version: 1.0.0
Requirements: AWS.Tools.S3 or AWSPowerShell module
#>

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
                $existingObject = Get-S3Object @awsParams -Key $key -ErrorAction Stop
                $objectExists = $true
            } catch {
                # Distinguish between "not found" and other errors
                $errorCode = $_.Exception.ErrorCode
                $errorMessage = $_.Exception.Message

                if ($errorCode -eq "NotFound" -or $errorMessage -match "NotFound|does not exist|The specified key does not exist") {
                    $objectExists = $false
                } elseif ($errorCode -eq "NoSuchBucket" -or $errorMessage -match "NoSuchBucket|bucket.*does not exist") {
                    $module.FailJson("Bucket does not exist: $bucket. Error: $errorMessage")
                } elseif ($errorCode -eq "AccessDenied" -or $errorMessage -match "Access Denied|Forbidden|403") {
                    $module.FailJson("Access denied when checking object existence in bucket '$bucket'. Verify IAM permissions (s3:GetObject, s3:ListBucket). Error: $errorMessage")
                } else {
                    # Other errors (network issues, invalid credentials, etc.)
                    $module.FailJson("Failed to check if S3 object exists at s3://$bucket/$key. Error: $errorMessage")
                }
            }

            if ($objectExists -and -not $overwrite) {
                $module.Result.msg = "Object already exists and overwrite is false"
            } else {
                # Upload with detailed error handling
                try {
                    if (-not $module.CheckMode) {
                        Write-S3Object @awsParams -File $src -Key $key -ErrorAction Stop
                    }
                    $module.Result.changed = $true
                    $module.Result.msg = "File uploaded successfully to s3://$bucket/$key"
                } catch {
                    $errorCode = $_.Exception.ErrorCode
                    $errorMessage = $_.Exception.Message

                    if ($errorCode -eq "NoSuchBucket" -or $errorMessage -match "NoSuchBucket|bucket.*does not exist") {
                        $module.FailJson("Failed to upload: Bucket '$bucket' does not exist. Error: $errorMessage")
                    } elseif ($errorCode -eq "AccessDenied" -or $errorMessage -match "Access Denied|Forbidden|403") {
                        $module.FailJson("Failed to upload: Access denied to bucket '$bucket'. Verify IAM permissions (s3:PutObject). Error: $errorMessage")
                    } elseif ($errorCode -eq "InvalidAccessKeyId" -or $errorMessage -match "InvalidAccessKeyId|invalid.*access key") {
                        $module.FailJson("Failed to upload: Invalid AWS access key ID. Verify credentials. Error: $errorMessage")
                    } elseif ($errorCode -eq "SignatureDoesNotMatch" -or $errorMessage -match "SignatureDoesNotMatch|signature.*not match") {
                        $module.FailJson("Failed to upload: AWS secret key does not match access key. Verify credentials. Error: $errorMessage")
                    } elseif ($errorMessage -match "Could not find a part of the path|FileNotFoundException") {
                        $module.FailJson("Failed to upload: Source file '$src' could not be read. Verify file path and permissions. Error: $errorMessage")
                    } elseif ($errorMessage -match "network|timeout|connection") {
                        $module.FailJson("Failed to upload: Network error occurred. Check connectivity to AWS S3. Error: $errorMessage")
                    } else {
                        $module.FailJson("Failed to upload file to s3://$bucket/$key. Error: $errorMessage", $_)
                    }
                }
            }
        }

        "download" {
            # Download file from S3
            # Check if object exists with detailed error handling
            try {
                $existingObject = Get-S3Object @awsParams -Key $key -ErrorAction Stop
            } catch {
                $errorCode = $_.Exception.ErrorCode
                $errorMessage = $_.Exception.Message

                if ($errorCode -eq "NotFound" -or $errorMessage -match "NotFound|does not exist|The specified key does not exist") {
                    $module.FailJson("Failed to download: Object does not exist at s3://$bucket/$key")
                } elseif ($errorCode -eq "NoSuchBucket" -or $errorMessage -match "NoSuchBucket|bucket.*does not exist") {
                    $module.FailJson("Failed to download: Bucket '$bucket' does not exist. Error: $errorMessage")
                } elseif ($errorCode -eq "AccessDenied" -or $errorMessage -match "Access Denied|Forbidden|403") {
                    $module.FailJson("Failed to download: Access denied to object at s3://$bucket/$key. Verify IAM permissions (s3:GetObject). Error: $errorMessage")
                } else {
                    $module.FailJson("Failed to check if S3 object exists at s3://$bucket/$key. Error: $errorMessage")
                }
            }

            # Check if destination file exists
            if ((Test-Path -Path $dest) -and -not $overwrite) {
                $module.Result.msg = "Destination file already exists and overwrite is false"
            } else {
                # Download with detailed error handling
                try {
                    if (-not $module.CheckMode) {
                        Read-S3Object @awsParams -Key $key -File $dest -ErrorAction Stop
                    }
                    $module.Result.changed = $true
                    $module.Result.msg = "File downloaded successfully from s3://$bucket/$key to $dest"
                } catch {
                    $errorCode = $_.Exception.ErrorCode
                    $errorMessage = $_.Exception.Message

                    if ($errorCode -eq "AccessDenied" -or $errorMessage -match "Access Denied|Forbidden|403") {
                        $module.FailJson("Failed to download: Access denied to object at s3://$bucket/$key. Verify IAM permissions (s3:GetObject). Error: $errorMessage")
                    } elseif ($errorCode -eq "InvalidAccessKeyId" -or $errorMessage -match "InvalidAccessKeyId|invalid.*access key") {
                        $module.FailJson("Failed to download: Invalid AWS access key ID. Verify credentials. Error: $errorMessage")
                    } elseif ($errorCode -eq "SignatureDoesNotMatch" -or $errorMessage -match "SignatureDoesNotMatch|signature.*not match") {
                        $module.FailJson("Failed to download: AWS secret key does not match access key. Verify credentials. Error: $errorMessage")
                    } elseif ($errorMessage -match "Could not find a part of the path|DirectoryNotFoundException|UnauthorizedAccessException") {
                        $module.FailJson("Failed to download: Cannot write to destination path '$dest'. Verify directory exists and permissions are correct. Error: $errorMessage")
                    } elseif ($errorMessage -match "network|timeout|connection") {
                        $module.FailJson("Failed to download: Network error occurred. Check connectivity to AWS S3. Error: $errorMessage")
                    } else {
                        $module.FailJson("Failed to download file from s3://$bucket/$key to $dest. Error: $errorMessage", $_)
                    }
                }
            }
        }

        "absent" {
            # Delete object from S3
            try {
                # Check if object exists with detailed error handling
                try {
                    $existingObject = Get-S3Object @awsParams -Key $key -ErrorAction Stop
                    $objectExists = $true
                } catch {
                    $errorCode = $_.Exception.ErrorCode
                    $errorMessage = $_.Exception.Message

                    if ($errorCode -eq "NotFound" -or $errorMessage -match "NotFound|does not exist|The specified key does not exist") {
                        $objectExists = $false
                    } elseif ($errorCode -eq "NoSuchBucket" -or $errorMessage -match "NoSuchBucket|bucket.*does not exist") {
                        $module.FailJson("Failed to delete: Bucket '$bucket' does not exist. Error: $errorMessage")
                    } elseif ($errorCode -eq "AccessDenied" -or $errorMessage -match "Access Denied|Forbidden|403") {
                        $module.FailJson("Failed to delete: Access denied when checking object at s3://$bucket/$key. Verify IAM permissions (s3:GetObject, s3:DeleteObject). Error: $errorMessage")
                    } else {
                        $module.FailJson("Failed to check if S3 object exists at s3://$bucket/$key. Error: $errorMessage")
                    }
                }

                if ($objectExists) {
                    # Delete with detailed error handling
                    try {
                        if (-not $module.CheckMode) {
                            Remove-S3Object @awsParams -Key $key -Force -ErrorAction Stop
                        }
                        $module.Result.changed = $true
                        $module.Result.msg = "Object deleted successfully from s3://$bucket/$key"
                    } catch {
                        $errorCode = $_.Exception.ErrorCode
                        $errorMessage = $_.Exception.Message

                        if ($errorCode -eq "AccessDenied" -or $errorMessage -match "Access Denied|Forbidden|403") {
                            $module.FailJson("Failed to delete: Access denied to object at s3://$bucket/$key. Verify IAM permissions (s3:DeleteObject). Error: $errorMessage")
                        } elseif ($errorCode -eq "InvalidAccessKeyId" -or $errorMessage -match "InvalidAccessKeyId|invalid.*access key") {
                            $module.FailJson("Failed to delete: Invalid AWS access key ID. Verify credentials. Error: $errorMessage")
                        } elseif ($errorCode -eq "SignatureDoesNotMatch" -or $errorMessage -match "SignatureDoesNotMatch|signature.*not match") {
                            $module.FailJson("Failed to delete: AWS secret key does not match access key. Verify credentials. Error: $errorMessage")
                        } elseif ($errorMessage -match "network|timeout|connection") {
                            $module.FailJson("Failed to delete: Network error occurred. Check connectivity to AWS S3. Error: $errorMessage")
                        } else {
                            $module.FailJson("Failed to delete object from s3://$bucket/$key. Error: $errorMessage", $_)
                        }
                    }
                } else {
                    $module.Result.msg = "Object does not exist: s3://$bucket/$key"
                }
            } catch {
                # Catch-all for unexpected errors
                $module.FailJson("Unexpected error during delete operation: $($_.Exception.Message)", $_)
            }
        }
    }

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()

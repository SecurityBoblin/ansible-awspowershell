#!powershell

# Copyright: (c) 2025, Your Name <your.email@example.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        instance_id = @{ type = "str"; required = $true }
        tags = @{ type = "dict"; required = $false }
        state = @{
            type = "str"
            choices = "present", "absent", "read"
            default = "read"
        }
        purge_tags = @{ type = "bool"; default = $false }
        aws_access_key = @{ type = "str"; required = $false; no_log = $true }
        aws_secret_key = @{ type = "str"; required = $false; no_log = $true }
        region = @{ type = "str"; required = $false; default = "us-east-1" }
    }
    required_if = @(
        @("state", "present", @("tags")),
        @("state", "absent", @("tags"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$instance_id = $module.Params.instance_id
$tags = $module.Params.tags
$state = $module.Params.state
$purge_tags = $module.Params.purge_tags
$aws_access_key = $module.Params.aws_access_key
$aws_secret_key = $module.Params.aws_secret_key
$region = $module.Params.region

$module.Result.changed = $false
$module.Result.tags = @{}
$module.Result.instance_id = $instance_id

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
    $moduleCheck = Test-AWSPowerShellModule -Module $Module -RequiredModule "AWS.Tools.EC2"

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
    Install-AWSToolsModule AWS.Tools.EC2 -Force

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
        if ($moduleCheck.required_module -eq "AWS.Tools.EC2") {
            Import-Module AWS.Tools.EC2 -ErrorAction Stop
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
        Set-AWSCredential -AccessKey $Module.Params.aws_access_key -SecretKey $Module.Params.aws_secret_key -StoreAs ansible_temp_ec2
        $script:CredentialParam = @{ ProfileName = "ansible_temp_ec2" }
        $Module.Result.debug_info.credential_source = "module_parameters"
    }
    # Check for environment variables
    elseif ($env:AWS_ACCESS_KEY_ID -and $env:AWS_SECRET_ACCESS_KEY) {
        Set-AWSCredential -AccessKey $env:AWS_ACCESS_KEY_ID -SecretKey $env:AWS_SECRET_ACCESS_KEY -StoreAs ansible_temp_ec2_env
        $script:CredentialParam = @{ ProfileName = "ansible_temp_ec2_env" }
        $Module.Result.debug_info.credential_source = "environment_variables"
    }
    # Otherwise, rely on IAM role (default AWS PowerShell behavior)
    else {
        # No credentials set - AWS PowerShell will automatically use IAM role from instance metadata
        $script:CredentialParam = @{}
        $Module.Result.debug_info.credential_source = "iam_role"
    }
}

# Function to get current tags
function Get-CurrentTags {
    param($InstanceId, $AwsParams)

    try {
        $instance = Get-EC2Instance @AwsParams -InstanceId $InstanceId -ErrorAction Stop
        if ($null -eq $instance -or $instance.Instances.Count -eq 0) {
            return $null
        }

        $currentTags = @{}
        foreach ($tag in $instance.Instances[0].Tags) {
            $currentTags[$tag.Key] = $tag.Value
        }
        return $currentTags
    } catch {
        return $null
    }
}

# Function to compare tags
function Compare-Tags {
    param($CurrentTags, $DesiredTags)

    if ($null -eq $CurrentTags) {
        $CurrentTags = @{}
    }

    $different = $false
    foreach ($key in $DesiredTags.Keys) {
        if (-not $CurrentTags.ContainsKey($key) -or $CurrentTags[$key] -ne $DesiredTags[$key]) {
            $different = $true
            break
        }
    }

    return $different
}

try {
    Set-AWSCredentials -Module $module

    # Common parameters for AWS cmdlets
    $awsParams = @{
        Region = $region
    }

    if ($script:CredentialParam.Count -gt 0) {
        $awsParams += $script:CredentialParam
    }

    # Verify instance exists and get current tags
    $currentTags = Get-CurrentTags -InstanceId $instance_id -AwsParams $awsParams

    if ($null -eq $currentTags -and $state -ne "read") {
        $module.FailJson("Instance not found: $instance_id")
    }

    switch ($state) {
        "read" {
            # Read instance tags and metadata
            if ($null -eq $currentTags) {
                $module.FailJson("Instance not found: $instance_id")
            }

            $module.Result.tags = $currentTags
            $module.Result.msg = "Retrieved tags for instance $instance_id"

            # Get instance metadata
            try {
                $instance = Get-EC2Instance @awsParams -InstanceId $instance_id -ErrorAction Stop
                $instanceData = $instance.Instances[0]

                $module.Result.metadata = @{
                    instance_type = $instanceData.InstanceType
                    state = $instanceData.State.Name
                    availability_zone = $instanceData.Placement.AvailabilityZone
                    private_ip = $instanceData.PrivateIpAddress
                    public_ip = $instanceData.PublicIpAddress
                    launch_time = $instanceData.LaunchTime
                    vpc_id = $instanceData.VpcId
                    subnet_id = $instanceData.SubnetId
                }
            } catch {
                $module.FailJson("Failed to retrieve instance metadata: $($_.Exception.Message)")
            }
        }

        "present" {
            # Set/update tags
            $tagsChanged = Compare-Tags -CurrentTags $currentTags -DesiredTags $tags

            if ($purge_tags) {
                # Remove all tags not in desired state
                $tagsToRemove = @()
                foreach ($key in $currentTags.Keys) {
                    if (-not $tags.ContainsKey($key)) {
                        $tagsToRemove += $key
                    }
                }

                if ($tagsToRemove.Count -gt 0) {
                    $tagsChanged = $true
                    if (-not $module.CheckMode) {
                        foreach ($key in $tagsToRemove) {
                            Remove-EC2Tag @awsParams -Resource $instance_id -Tag @{ Key = $key } -Force -ErrorAction Stop
                        }
                    }
                }
            }

            if ($tagsChanged) {
                if (-not $module.CheckMode) {
                    # Create tag objects
                    $ec2Tags = @()
                    foreach ($key in $tags.Keys) {
                        $ec2Tags += @{ Key = $key; Value = $tags[$key] }
                    }
                    New-EC2Tag @awsParams -Resource $instance_id -Tag $ec2Tags -ErrorAction Stop
                }
                $module.Result.changed = $true
                $module.Result.msg = "Tags updated successfully for instance $instance_id"
            } else {
                $module.Result.msg = "Tags are already in desired state"
            }

            # Return current tags
            $module.Result.tags = Get-CurrentTags -InstanceId $instance_id -AwsParams $awsParams
        }

        "absent" {
            # Remove specified tags
            $tagsToRemove = @()
            foreach ($key in $tags.Keys) {
                if ($currentTags.ContainsKey($key)) {
                    $tagsToRemove += $key
                }
            }

            if ($tagsToRemove.Count -gt 0) {
                if (-not $module.CheckMode) {
                    foreach ($key in $tagsToRemove) {
                        Remove-EC2Tag @awsParams -Resource $instance_id -Tag @{ Key = $key } -Force -ErrorAction Stop
                    }
                }
                $module.Result.changed = $true
                $module.Result.msg = "Tags removed successfully from instance $instance_id"
            } else {
                $module.Result.msg = "Specified tags do not exist on instance"
            }

            # Return current tags
            $module.Result.tags = Get-CurrentTags -InstanceId $instance_id -AwsParams $awsParams
        }
    }

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()

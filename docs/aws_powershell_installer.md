# aws_powershell_installer

Install, update, or remove AWS PowerShell modules on Windows hosts.

## Synopsis

- Installs AWS.Tools.Installer and specified AWS.Tools modules (modular approach)
- Or installs the monolithic AWSPowerShell module
- Supports installing, updating to latest, or removing modules
- Handles dependencies automatically

## Requirements

- PowerShell 5.1 or later
- Internet connection for downloading modules from PowerShell Gallery
- Administrator privileges (recommended for system-wide installation)

## Parameters

| Parameter | Required | Default | Choices | Description |
|-----------|----------|---------|---------|-------------|
| modules | no | ["AWS.Tools.S3", "AWS.Tools.EC2"] | | List of AWS.Tools modules to install. Only used with install_type=modular. |
| install_type | no | modular | modular, monolithic | Type of installation. Modular uses AWS.Tools.*, monolithic uses AWSPowerShell. |
| state | no | present | present, absent, latest | Desired state. present=install if missing, absent=remove, latest=update to latest version. |
| force | no | false | | Force installation even if module exists. |
| allow_clobber | no | true | | Allow module to override existing commands. |
| skip_publisher_check | no | false | | Skip publisher validation check. |

## Return Values

| Key | Type | Description |
|-----|------|-------------|
| changed | boolean | Whether any changes were made |
| installed_modules | list | List of newly installed modules |
| updated_modules | list | List of updated modules |
| removed_modules | list | List of removed modules |
| skipped_modules | list | List of modules that didn't need changes |
| initial_state | dict | Installed modules before operation |
| final_state | dict | Installed modules after operation |
| msg | string | Summary message |

## Examples

### Install modular AWS.Tools modules (recommended)

```yaml
- name: Install AWS PowerShell modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
      - AWS.Tools.EC2
      - AWS.Tools.SecurityToken
    state: present
```

### Install monolithic AWSPowerShell module

```yaml
- name: Install AWSPowerShell module
  community.awspowershell.aws_powershell_installer:
    install_type: monolithic
    state: present
```

### Update modules to latest version

```yaml
- name: Update AWS PowerShell modules to latest
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
      - AWS.Tools.EC2
    state: latest
```

### Remove AWS PowerShell modules

```yaml
- name: Remove AWS PowerShell modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
    state: absent
```

### Force reinstall modules

```yaml
- name: Force reinstall AWS modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
      - AWS.Tools.EC2
    state: present
    force: yes
```

### Install specific modules for your use case

```yaml
# For Lambda development
- name: Install Lambda modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.Lambda
      - AWS.Tools.CloudWatchLogs
      - AWS.Tools.IAM
    state: present

# For RDS management
- name: Install RDS modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.RDS
      - AWS.Tools.SecretsManager
    state: present
```

## Complete Playbook Example

```yaml
---
- name: Setup AWS PowerShell environment
  hosts: windows_servers
  gather_facts: no

  tasks:
    - name: Install AWS PowerShell modules
      community.awspowershell.aws_powershell_installer:
        modules:
          - AWS.Tools.S3
          - AWS.Tools.EC2
          - AWS.Tools.SecurityToken
        state: present
      register: install_result

    - name: Display installation result
      debug:
        msg: |
          Changed: {{ install_result.changed }}
          Installed: {{ install_result.installed_modules }}
          Skipped: {{ install_result.skipped_modules }}

    - name: Verify S3 module is available
      win_shell: |
        Import-Module AWS.Tools.S3
        (Get-Module AWS.Tools.S3).Version.ToString()
      register: s3_version

    - name: Show S3 module version
      debug:
        msg: "AWS.Tools.S3 version: {{ s3_version.stdout | trim }}"
```

## Notes

### Modular vs Monolithic

**Modular (AWS.Tools.*) - Recommended:**
- Smaller download size
- Faster import times
- Install only what you need
- Better for production environments

**Monolithic (AWSPowerShell):**
- Single large module with all AWS services
- Simpler to manage (one module)
- Larger footprint (~500MB vs ~10-50MB per module)
- Better for development/testing

### Available AWS.Tools Modules

Common modules you might need:
- `AWS.Tools.S3` - S3 storage operations
- `AWS.Tools.EC2` - EC2 instance management
- `AWS.Tools.SecurityToken` - STS credentials (needed for IAM role operations)
- `AWS.Tools.Lambda` - Lambda function management
- `AWS.Tools.CloudFormation` - CloudFormation stack operations
- `AWS.Tools.RDS` - RDS database management
- `AWS.Tools.CloudWatch` - CloudWatch metrics and logs
- `AWS.Tools.IAM` - IAM user and role management
- `AWS.Tools.DynamoDB` - DynamoDB operations
- `AWS.Tools.SNS` - SNS notifications
- `AWS.Tools.SQS` - SQS queue operations
- `AWS.Tools.SecretsManager` - Secrets Manager operations

For a complete list: https://www.powershellgallery.com/packages?q=AWS.Tools

### Check Mode

This module supports check mode (--check). When run in check mode, it will report what changes would be made without actually installing or removing modules.

### Idempotency

The module is idempotent:
- `state: present` - Only installs if not already present
- `state: latest` - Always checks for and installs updates
- `state: absent` - Only removes if currently installed

### Installation Location

Modules are installed in the PowerShell modules directory:
- User scope: `$env:USERPROFILE\Documents\PowerShell\Modules`
- System scope: `$env:ProgramFiles\PowerShell\Modules`

By default, Install-Module installs to the current user's scope unless run with administrator privileges.

## Troubleshooting

### "Unable to download from URI"

The host needs internet access to PowerShell Gallery. Check firewall rules and proxy settings.

### "Package 'AWS.Tools.X' failed to install"

Ensure you have the latest PowerShellGet:
```powershell
Install-Module -Name PowerShellGet -Force -AllowClobber
```

### "Installation requires the latest version of PowerShellGet"

Update PowerShellGet first:
```yaml
- name: Update PowerShellGet
  win_shell: Install-Module -Name PowerShellGet -Force -AllowClobber -SkipPublisherCheck
```

### Module not found after installation

Restart PowerShell or reimport the module path:
```yaml
- name: Refresh module path
  win_shell: |
    $env:PSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
```

## See Also

- [aws_s3_object](aws_s3_object.md) - Manage S3 objects
- [aws_ec2_tags](aws_ec2_tags.md) - Manage EC2 tags
- [AWS Tools for PowerShell Documentation](https://docs.aws.amazon.com/powershell/)

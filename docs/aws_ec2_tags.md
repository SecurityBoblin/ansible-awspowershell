# aws_ec2_tags Module

## Synopsis

Manage EC2 instance tags and retrieve instance metadata using AWS PowerShell cmdlets.

## Requirements

- AWS.Tools.EC2 or AWSPowerShell module installed on the target Windows host
- PowerShell 5.1 or later
- Appropriate AWS credentials or IAM role

## Parameters

| Parameter | Type | Required | Default | Choices | Description |
|-----------|------|----------|---------|---------|-------------|
| instance_id | str | yes | - | - | EC2 instance ID (e.g., i-1234567890abcdef0) |
| tags | dict | no | - | - | Dictionary of tags to set or remove (required for state=present or absent) |
| state | str | no | read | read, present, absent | Desired state - read metadata, set tags, or remove tags |
| purge_tags | bool | no | false | - | Remove tags not specified in 'tags' parameter (only with state=present) |
| aws_access_key | str | no | - | - | AWS access key ID. If not set, uses environment variable or IAM role |
| aws_secret_key | str | no | - | - | AWS secret access key. If not set, uses environment variable or IAM role |
| region | str | no | us-east-1 | - | AWS region |

## Authentication

The module supports three authentication methods (in order of precedence):

1. **Module Parameters**: Use `aws_access_key` and `aws_secret_key` parameters
2. **Environment Variables**: Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
3. **IAM Role**: Automatically uses EC2 instance IAM role (default AWS PowerShell behavior)

## Examples

### Read instance metadata and tags

```yaml
- name: Get instance information
  securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: read
    region: us-west-2
  register: instance_info

- name: Display instance tags
  debug:
    var: instance_info.tags

- name: Display instance metadata
  debug:
    var: instance_info.metadata
```

### Set tags on an instance

```yaml
- name: Set instance tags
  securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    tags:
      Environment: Production
      Application: WebServer
      Owner: DevOps
    region: us-west-2
```

### Update tags with purge

```yaml
- name: Replace all tags
  securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    purge_tags: yes
    tags:
      Name: my-instance
      Team: Engineering
    region: us-west-2
  # This will remove all existing tags except Name and Team
```

### Remove specific tags

```yaml
- name: Remove tags
  securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: absent
    tags:
      OldTag: ""
      TemporaryTag: ""
    region: us-west-2
  # Tag values are ignored when removing, only keys matter
```

### Using IAM role authentication

```yaml
- name: Set tags using IAM role
  securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    tags:
      Backup: Daily
      Monitoring: Enabled
  # No credentials needed when running on EC2 with IAM role
```

### Set tags with explicit credentials

```yaml
- name: Set tags with credentials
  securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    aws_access_key: "{{ aws_access_key }}"
    aws_secret_key: "{{ aws_secret_key }}"
    tags:
      Project: MyProject
      CostCenter: "12345"
    region: eu-west-1
```

## Return Values

| Key | Type | Description |
|-----|------|-------------|
| changed | bool | Whether the module made changes |
| msg | str | Message describing what happened |
| tags | dict | Current tags on the instance |
| instance_id | str | The instance ID that was queried |
| metadata | dict | Instance metadata (only returned when state=read) |

### Metadata Dictionary (state=read)

| Key | Type | Description |
|-----|------|-------------|
| instance_type | str | Instance type (e.g., t2.micro) |
| state | str | Instance state (running, stopped, etc.) |
| availability_zone | str | AZ where instance is running |
| private_ip | str | Private IP address |
| public_ip | str | Public IP address (if assigned) |
| launch_time | str | Instance launch timestamp |
| vpc_id | str | VPC ID |
| subnet_id | str | Subnet ID |

## Notes

- The module uses AWS PowerShell cmdlets (Get-EC2Instance, New-EC2Tag, Remove-EC2Tag)
- Check mode is supported
- When using IAM roles, ensure the instance has appropriate EC2 permissions (ec2:DescribeInstances, ec2:CreateTags, ec2:DeleteTags)
- The module will automatically import AWS.Tools.EC2 or AWSPowerShell module
- When state=absent, tag values in the tags parameter are ignored (only keys are used)

## Author

Your Name (@yourusername)

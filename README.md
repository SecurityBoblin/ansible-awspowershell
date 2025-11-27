# Ansible Collection: securityboblin.awspowershell

An Ansible collection for managing AWS resources using AWS PowerShell cmdlets on Windows hosts.

## Description

This collection provides Ansible modules that leverage AWS PowerShell cmdlets to manage AWS resources. Unlike Python-based AWS modules, these modules run directly on Windows hosts using PowerShell, making them ideal for Windows-centric environments.

### Modules Included

- **aws_s3_object** - Upload, download, and delete objects in Amazon S3 buckets
- **aws_ec2_tags** - Read EC2 instance metadata and manage instance tags

### Key Features

- **Native PowerShell**: Runs AWS PowerShell cmdlets directly on Windows targets
- **Flexible Authentication**: Supports IAM roles (default), environment variables, and explicit credentials
- **Check Mode**: All modules support Ansible check mode for safe testing
- **Idempotent**: Modules are designed to be idempotent and report changes accurately
- **Windows-First**: Built specifically for Windows environments with AWS PowerShell

## Requirements

### Control Node
- Ansible 2.14 or later
- `ansible.windows` collection

### Target Windows Hosts
- Windows Server 2012 R2 or later / Windows 10+
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS PowerShell module:
  - AWS.Tools.S3 and AWS.Tools.EC2 (modular, recommended), OR
  - AWSPowerShell (monolithic)

## Installation

### Install the Collection

```bash
# From Ansible Galaxy (when published)
ansible-galaxy collection install securityboblin.awspowershell

# From tarball
ansible-galaxy collection install securityboblin-awspowershell-1.0.0.tar.gz

# From source
ansible-galaxy collection install . --force
```

### Install AWS PowerShell on Target Hosts

```powershell
# Option 1: Modular (recommended - smaller, faster)
Install-Module -Name AWS.Tools.Installer -Force
Install-AWSToolsModule AWS.Tools.S3, AWS.Tools.EC2

# Option 2: Monolithic (simpler but larger)
Install-Module -Name AWSPowerShell -Force
```

## Quick Start

### Upload a File to S3

```yaml
---
- name: Upload files to S3
  hosts: windows_servers
  tasks:
    - name: Upload configuration file
      securityboblin.awspowershell.aws_s3_object:
        bucket: my-bucket
        key: configs/app-config.json
        src: C:\temp\app-config.json
        state: present
        region: us-west-2
```

### Manage EC2 Instance Tags

```yaml
---
- name: Tag EC2 instances
  hosts: localhost
  tasks:
    - name: Add tags to instance
      securityboblin.awspowershell.aws_ec2_tags:
        instance_id: i-1234567890abcdef0
        state: present
        region: us-east-1
        tags:
          Environment: Production
          ManagedBy: Ansible
          Owner: DevOps
```

## Authentication

The modules support three authentication methods (in order of precedence):

### 1. IAM Role (Recommended - Default)

When running on EC2 instances with an attached IAM role, no configuration is needed. AWS PowerShell automatically uses instance credentials.

```yaml
- name: Upload using IAM role
  securityboblin.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: file.txt
    src: C:\data\file.txt
    state: present
  # No credentials needed!
```

### 2. Environment Variables

Set AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

```yaml
- name: Upload using environment variables
  securityboblin.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: file.txt
    src: C:\data\file.txt
    state: present
  # Uses environment variables automatically
```

### 3. Module Parameters

Provide credentials directly (use Ansible Vault for security):

```yaml
- name: Upload with explicit credentials
  securityboblin.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: file.txt
    src: C:\data\file.txt
    state: present
    aws_access_key: "{{ vault_aws_access_key }}"
    aws_secret_key: "{{ vault_aws_secret_key }}"
```

## Modules

### aws_s3_object

Manage S3 objects (upload, download, delete).

**Parameters:**
- `bucket` (required): S3 bucket name
- `key` (required): S3 object key
- `src`: Local file path for upload
- `dest`: Local file path for download
- `state`: present (upload), download, or absent (delete)
- `overwrite`: Whether to overwrite existing files/objects (default: true)
- `region`: AWS region (default: us-east-1)

**Examples:**

```yaml
# Upload file
- securityboblin.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: data/file.txt
    src: C:\temp\file.txt
    state: present

# Download file
- securityboblin.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: data/file.txt
    dest: C:\downloads\file.txt
    state: download

# Delete object
- securityboblin.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: data/old-file.txt
    state: absent
```

[Full documentation](docs/aws_s3_object.md)

### aws_ec2_tags

Read EC2 instance metadata and manage tags.

**Parameters:**
- `instance_id` (required): EC2 instance ID
- `tags`: Dictionary of tags
- `state`: read (default), present, or absent
- `purge_tags`: Remove tags not in 'tags' parameter (default: false)
- `region`: AWS region (default: us-east-1)

**Examples:**

```yaml
# Read instance information
- securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: read
  register: instance_info

# Set tags
- securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    tags:
      Environment: Production
      Owner: DevOps

# Remove tags
- securityboblin.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: absent
    tags:
      OldTag: ""
```

[Full documentation](docs/aws_ec2_tags.md)

## IAM Permissions

### S3 Operations

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name/*",
        "arn:aws:s3:::your-bucket-name"
      ]
    }
  ]
}
```

### EC2 Tag Operations

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    }
  ]
}
```

## Example Playbooks

### Complete S3 Management

```yaml
---
- name: Manage application files in S3
  hosts: windows_app_servers
  vars:
    app_bucket: my-application-data
    backup_bucket: my-application-backups

  tasks:
    - name: Upload application data
      securityboblin.awspowershell.aws_s3_object:
        bucket: "{{ app_bucket }}"
        key: "data/{{ inventory_hostname }}/{{ item | basename }}"
        src: "{{ item }}"
        state: present
        region: us-west-2
      with_fileglob:
        - C:\AppData\*.json

    - name: Download shared configuration
      securityboblin.awspowershell.aws_s3_object:
        bucket: "{{ app_bucket }}"
        key: config/shared-config.json
        dest: C:\Config\shared-config.json
        state: download
        region: us-west-2

    - name: Backup to S3
      securityboblin.awspowershell.aws_s3_object:
        bucket: "{{ backup_bucket }}"
        key: "backups/{{ ansible_date_time.date }}/{{ inventory_hostname }}.zip"
        src: C:\Backups\full-backup.zip
        state: present
        region: us-west-2
```

### EC2 Instance Inventory and Tagging

```yaml
---
- name: EC2 instance management
  hosts: localhost
  gather_facts: no

  vars:
    managed_instances:
      - i-1234567890abcdef0
      - i-0987654321fedcba0

  tasks:
    - name: Gather instance information
      securityboblin.awspowershell.aws_ec2_tags:
        instance_id: "{{ item }}"
        state: read
        region: us-east-1
      loop: "{{ managed_instances }}"
      register: instances

    - name: Display instance metadata
      debug:
        msg: |
          Instance: {{ item.instance_id }}
          Type: {{ item.metadata.instance_type }}
          State: {{ item.metadata.state }}
          Private IP: {{ item.metadata.private_ip }}
          Tags: {{ item.tags }}
      loop: "{{ instances.results }}"

    - name: Standardize tags
      securityboblin.awspowershell.aws_ec2_tags:
        instance_id: "{{ item }}"
        state: present
        tags:
          Environment: Production
          ManagedBy: Ansible
          CostCenter: IT-Infrastructure
          LastUpdated: "{{ ansible_date_time.iso8601 }}"
        region: us-east-1
      loop: "{{ managed_instances }}"
```

## Testing

Run integration tests:

```bash
# Configure test environment
cp tests/integration/integration_config.yml.example tests/integration/integration_config.yml
# Edit integration_config.yml with your test bucket and instance ID

# Run tests
ansible-test integration aws_s3_object
ansible-test integration aws_ec2_tags
```

## Troubleshooting

### Module not found
```bash
ansible-galaxy collection list | grep awspowershell
ansible-galaxy collection install securityboblin.awspowershell --force
```

### AWS PowerShell not installed
```powershell
# On Windows target
Install-Module -Name AWS.Tools.S3, AWS.Tools.EC2 -Force
```

### Access Denied errors
- Verify IAM permissions
- Check bucket policies
- Test credentials: `aws sts get-caller-identity`

### WinRM connection issues
```yaml
# In inventory
ansible_connection: winrm
ansible_winrm_transport: ntlm
ansible_winrm_server_cert_validation: ignore
```

## Documentation

- **docs/aws_s3_object.md** - Full S3 module documentation
- **docs/aws_ec2_tags.md** - Full EC2 tags module documentation

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Update documentation
5. Submit a pull request

## Support

- Review documentation in the `docs/` directory
- Open an issue on GitHub with:
  - Ansible version
  - Collection version
  - PowerShell version
  - Sanitized playbook and error output

## License


## Author

Marius Rometsch (@SecurityBoblin)

## Links

- [Ansible Collections](https://docs.ansible.com/ansible/latest/user_guide/collections_using.html)
- [AWS PowerShell Documentation](https://docs.aws.amazon.com/powershell/)
- [Ansible Windows Modules](https://docs.ansible.com/ansible/latest/user_guide/windows.html)

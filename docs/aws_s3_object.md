# aws_s3_object Module

## Synopsis

Manage S3 objects (upload, download, delete) using AWS PowerShell cmdlets.

## Requirements

- AWS.Tools.S3 or AWSPowerShell module installed on the target Windows host
- PowerShell 5.1 or later
- Appropriate AWS credentials or IAM role

## Parameters

| Parameter | Type | Required | Default | Choices | Description |
|-----------|------|----------|---------|---------|-------------|
| bucket | str | yes | - | - | Name of the S3 bucket |
| key | str | yes | - | - | S3 object key (path within bucket) |
| src | path | no | - | - | Local file path to upload (required when state=present) |
| dest | path | no | - | - | Local file path to download to (required when state=download) |
| state | str | no | present | present, absent, download | Desired state of the S3 object |
| aws_access_key | str | no | - | - | AWS access key ID. If not set, uses environment variable or IAM role |
| aws_secret_key | str | no | - | - | AWS secret access key. If not set, uses environment variable or IAM role |
| region | str | no | us-east-1 | - | AWS region |
| overwrite | bool | no | true | - | Whether to overwrite existing files/objects |

## Authentication

The module supports three authentication methods (in order of precedence):

1. **Module Parameters**: Use `aws_access_key` and `aws_secret_key` parameters
2. **Environment Variables**: Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
3. **IAM Role**: Automatically uses EC2 instance IAM role (default AWS PowerShell behavior)

## Examples

### Upload a file to S3

```yaml
- name: Upload file to S3
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: path/to/file.txt
    src: /local/path/file.txt
    state: present
    region: us-west-2
```

### Upload with explicit credentials

```yaml
- name: Upload file with credentials
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/data.json
    src: /tmp/data.json
    aws_access_key: "{{ aws_access_key }}"
    aws_secret_key: "{{ aws_secret_key }}"
    region: us-east-1
```

### Download a file from S3

```yaml
- name: Download file from S3
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: path/to/file.txt
    dest: C:\downloads\file.txt
    state: download
    region: us-west-2
```

### Delete an object from S3

```yaml
- name: Delete S3 object
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: path/to/old-file.txt
    state: absent
    region: us-west-2
```

### Using IAM role (no credentials needed)

```yaml
- name: Upload using IAM role
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: data/report.pdf
    src: /reports/report.pdf
    state: present
  # No aws_access_key/aws_secret_key needed when running on EC2 with IAM role
```

## Return Values

| Key | Type | Description |
|-----|------|-------------|
| changed | bool | Whether the module made changes |
| msg | str | Message describing what happened |

## Notes

- The module uses AWS PowerShell cmdlets (Write-S3Object, Read-S3Object, Remove-S3Object, Get-S3Object)
- Check mode is supported
- When using IAM roles, ensure the instance has appropriate S3 permissions
- The module will automatically import AWS.Tools.S3 or AWSPowerShell module

## Author

Your Name (@yourusername)

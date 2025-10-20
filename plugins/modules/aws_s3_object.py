#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2025, Your Name <your.email@example.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: aws_s3_object
short_description: Manage S3 objects (upload, download, delete)
description:
  - This module manages S3 objects using AWS PowerShell cmdlets.
  - It supports uploading files to S3, downloading files from S3, and deleting S3 objects.
  - Requires AWS.Tools.S3 or AWSPowerShell module to be installed on the target Windows host.
version_added: "1.0.0"
options:
  bucket:
    description:
      - The name of the S3 bucket.
    type: str
    required: true
  key:
    description:
      - The S3 object key (path within the bucket).
    type: str
    required: true
  src:
    description:
      - Local file path for upload.
      - Required when I(state=present).
    type: path
    required: false
  dest:
    description:
      - Local file path for download.
      - Required when I(state=download).
    type: path
    required: false
  state:
    description:
      - Desired state of the S3 object.
      - C(present) uploads the file to S3.
      - C(download) downloads the file from S3.
      - C(absent) deletes the object from S3.
    type: str
    choices: [ present, download, absent ]
    default: present
  aws_access_key:
    description:
      - AWS access key ID.
      - If not provided, uses environment variables or IAM role.
    type: str
    required: false
  aws_secret_key:
    description:
      - AWS secret access key.
      - If not provided, uses environment variables or IAM role.
    type: str
    required: false
    no_log: true
  region:
    description:
      - AWS region.
    type: str
    default: us-east-1
  overwrite:
    description:
      - Whether to overwrite existing files/objects.
    type: bool
    default: true
author:
  - Community
requirements:
  - AWS.Tools.S3 or AWSPowerShell module must be installed on the target Windows host
  - PowerShell 5.1 or later
notes:
  - This module uses AWS PowerShell cmdlets (Get-S3Object, Write-S3Object, Read-S3Object, Remove-S3Object).
  - Authentication can be provided via module parameters, environment variables, or IAM role.
  - The module includes comprehensive prechecks and debug output.
  - Use the C(aws_powershell_installer) module to install required AWS PowerShell modules.
seealso:
  - module: community.awspowershell.aws_powershell_installer
  - module: community.awspowershell.aws_ec2_tags
'''

EXAMPLES = r'''
- name: Upload file to S3
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/data.json
    src: C:\temp\data.json
    state: present
    region: us-west-2

- name: Download file from S3
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/data.json
    dest: C:\downloads\data.json
    state: download
    region: us-west-2

- name: Delete S3 object
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/old-data.json
    state: absent
    region: us-west-2

- name: Upload with explicit credentials
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: secure/data.json
    src: C:\secure\data.json
    state: present
    aws_access_key: "{{ aws_access_key }}"
    aws_secret_key: "{{ aws_secret_key }}"
    region: us-east-1

- name: Upload without overwrite
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/data.json
    src: C:\temp\data.json
    state: present
    overwrite: false

- name: Upload and view debug info
  community.awspowershell.aws_s3_object:
    bucket: my-bucket
    key: uploads/data.json
    src: C:\temp\data.json
    state: present
  register: result

- name: Display debug information
  debug:
    var: result.debug_info
'''

RETURN = r'''
changed:
  description: Whether any changes were made
  returned: always
  type: bool
  sample: true
msg:
  description: Human-readable message about the operation
  returned: always
  type: str
  sample: "File uploaded successfully to s3://my-bucket/uploads/data.json"
debug_info:
  description: Debug information about AWS module and credentials
  returned: always
  type: dict
  contains:
    aws_module:
      description: Name of the AWS PowerShell module being used
      type: str
      sample: "AWS.Tools.S3"
    module_version:
      description: Version of the AWS PowerShell module
      type: str
      sample: "4.1.450"
    module_path:
      description: Path to the AWS PowerShell module
      type: str
      sample: "C:\\Program Files\\PowerShell\\Modules\\AWS.Tools.S3\\4.1.450\\AWS.Tools.S3.psd1"
    credential_source:
      description: Source of AWS credentials
      type: str
      sample: "iam_role"
      choices: [ module_parameters, environment_variables, iam_role ]
'''

#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2025, Your Name <your.email@example.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: aws_ec2_tags
short_description: Read instance metadata and manage EC2 instance tags
description:
  - This module reads EC2 instance metadata and manages EC2 instance tags using AWS PowerShell cmdlets.
  - It supports reading instance information, setting tags, and removing tags.
  - Requires AWS.Tools.EC2 or AWSPowerShell module to be installed on the target Windows host.
version_added: "1.0.0"
options:
  instance_id:
    description:
      - The EC2 instance ID.
    type: str
    required: true
  tags:
    description:
      - Dictionary of tags to set or remove.
      - Required when I(state=present) or I(state=absent).
    type: dict
    required: false
  state:
    description:
      - Desired state.
      - C(read) retrieves instance metadata and current tags.
      - C(present) sets or updates tags on the instance.
      - C(absent) removes specified tags from the instance.
    type: str
    choices: [ read, present, absent ]
    default: read
  purge_tags:
    description:
      - Remove tags not specified in the I(tags) parameter when I(state=present).
      - When C(true), only tags specified in I(tags) will remain on the instance.
    type: bool
    default: false
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
author:
  - Community
requirements:
  - AWS.Tools.EC2 or AWSPowerShell module must be installed on the target Windows host
  - PowerShell 5.1 or later
notes:
  - This module uses AWS PowerShell cmdlets (Get-EC2Instance, New-EC2Tag, Remove-EC2Tag).
  - Authentication can be provided via module parameters, environment variables, or IAM role.
  - The module includes comprehensive prechecks and debug output.
  - Use the C(aws_powershell_installer) module to install required AWS PowerShell modules.
seealso:
  - module: community.awspowershell.aws_powershell_installer
  - module: community.awspowershell.aws_s3_object
'''

EXAMPLES = r'''
- name: Read instance metadata and tags
  community.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: read
    region: us-east-1
  register: instance_info

- name: Display instance information
  debug:
    var: instance_info

- name: Set tags on instance
  community.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    region: us-east-1
    tags:
      Environment: Production
      Application: WebServer
      Owner: DevOps

- name: Update specific tag
  community.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    region: us-east-1
    tags:
      Environment: Staging

- name: Remove specific tags
  community.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: absent
    region: us-east-1
    tags:
      OldTag: ""
      TempTag: ""

- name: Replace all tags (purge)
  community.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    purge_tags: yes
    region: us-east-1
    tags:
      Name: my-instance
      Team: Engineering

- name: Set tags with explicit credentials
  community.awspowershell.aws_ec2_tags:
    instance_id: i-1234567890abcdef0
    state: present
    aws_access_key: "{{ aws_access_key }}"
    aws_secret_key: "{{ aws_secret_key }}"
    region: us-east-1
    tags:
      Environment: Production
'''

RETURN = r'''
changed:
  description: Whether any changes were made
  returned: always
  type: bool
  sample: true
instance_id:
  description: The EC2 instance ID
  returned: always
  type: str
  sample: "i-1234567890abcdef0"
tags:
  description: Current tags on the instance after the operation
  returned: always
  type: dict
  sample:
    Name: "my-instance"
    Environment: "Production"
    Application: "WebServer"
metadata:
  description: EC2 instance metadata
  returned: when state=read
  type: dict
  contains:
    instance_type:
      description: EC2 instance type
      type: str
      sample: "t3.medium"
    state:
      description: Current instance state
      type: str
      sample: "running"
    availability_zone:
      description: Availability zone
      type: str
      sample: "us-east-1a"
    private_ip:
      description: Private IP address
      type: str
      sample: "10.0.1.50"
    public_ip:
      description: Public IP address (if assigned)
      type: str
      sample: "54.123.45.67"
    launch_time:
      description: Instance launch timestamp
      type: str
      sample: "2025-01-15T10:30:00Z"
debug_info:
  description: Debug information about AWS module and credentials
  returned: always
  type: dict
  contains:
    aws_module:
      description: Name of the AWS PowerShell module being used
      type: str
      sample: "AWS.Tools.EC2"
    module_version:
      description: Version of the AWS PowerShell module
      type: str
      sample: "4.1.450"
    module_path:
      description: Path to the AWS PowerShell module
      type: str
      sample: "C:\\Program Files\\PowerShell\\Modules\\AWS.Tools.EC2\\4.1.450\\AWS.Tools.EC2.psd1"
    credential_source:
      description: Source of AWS credentials
      type: str
      sample: "iam_role"
      choices: [ module_parameters, environment_variables, iam_role ]
'''

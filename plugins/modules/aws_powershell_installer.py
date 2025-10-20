#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2025, Your Name <your.email@example.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: aws_powershell_installer
short_description: Install, update, or remove AWS PowerShell modules
description:
  - This module installs, updates, or removes AWS PowerShell modules on Windows hosts.
  - It supports both modular installation (AWS.Tools.*) and monolithic installation (AWSPowerShell).
  - The module automatically installs AWS.Tools.Installer when using modular mode.
  - Modular installation is recommended for production use (smaller, faster).
version_added: "1.0.0"
options:
  modules:
    description:
      - List of AWS.Tools modules to install.
      - Only used with I(install_type=modular).
      - Common modules include AWS.Tools.S3, AWS.Tools.EC2, AWS.Tools.SecurityToken.
    type: list
    elements: str
    default: [ "AWS.Tools.S3", "AWS.Tools.EC2" ]
  install_type:
    description:
      - Type of installation.
      - C(modular) installs specific AWS.Tools.* modules (recommended, smaller footprint).
      - C(monolithic) installs the complete AWSPowerShell module (~500MB, includes all AWS services).
    type: str
    choices: [ modular, monolithic ]
    default: modular
  state:
    description:
      - Desired state of the modules.
      - C(present) installs modules if they are missing.
      - C(absent) removes installed modules.
      - C(latest) updates modules to the latest version.
    type: str
    choices: [ present, absent, latest ]
    default: present
  force:
    description:
      - Force installation even if the module already exists.
      - Useful for reinstalling or repairing modules.
    type: bool
    default: false
  allow_clobber:
    description:
      - Allow the module to override existing PowerShell commands.
      - Usually safe to enable for AWS modules.
    type: bool
    default: true
  skip_publisher_check:
    description:
      - Skip publisher validation check during installation.
      - Use with caution; only enable if you trust the source.
    type: bool
    default: false
author:
  - Community
requirements:
  - PowerShell 5.1 or later
  - Internet connection to PowerShell Gallery
  - Administrator privileges recommended for system-wide installation
notes:
  - This module uses PowerShell's Install-Module, Update-Module, and Uninstall-Module cmdlets.
  - For modular installations, AWS.Tools.Installer is automatically installed if not present.
  - The module is idempotent - it only makes changes when necessary.
  - Supports check mode for testing changes before applying them.
  - Modular installation is recommended over monolithic for production use.
seealso:
  - module: community.awspowershell.aws_s3_object
  - module: community.awspowershell.aws_ec2_tags
  - name: AWS Tools for PowerShell
    description: Official AWS PowerShell documentation
    link: https://docs.aws.amazon.com/powershell/
'''

EXAMPLES = r'''
- name: Install modular AWS.Tools modules (recommended)
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
      - AWS.Tools.EC2
      - AWS.Tools.SecurityToken
    state: present

- name: Install monolithic AWSPowerShell module
  community.awspowershell.aws_powershell_installer:
    install_type: monolithic
    state: present

- name: Update AWS PowerShell modules to latest version
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
      - AWS.Tools.EC2
    state: latest

- name: Remove AWS PowerShell modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
    state: absent

- name: Force reinstall modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.S3
      - AWS.Tools.EC2
    state: present
    force: yes

- name: Install Lambda development modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.Lambda
      - AWS.Tools.CloudWatchLogs
      - AWS.Tools.IAM
    state: present

- name: Install RDS management modules
  community.awspowershell.aws_powershell_installer:
    modules:
      - AWS.Tools.RDS
      - AWS.Tools.SecretsManager
    state: present

- name: Complete setup workflow
  block:
    - name: Install AWS modules
      community.awspowershell.aws_powershell_installer:
        modules:
          - AWS.Tools.S3
          - AWS.Tools.EC2
        state: present
      register: install_result

    - name: Display installation result
      debug:
        var: install_result

    - name: Verify module is available
      win_shell: |
        Import-Module AWS.Tools.S3
        (Get-Module AWS.Tools.S3).Version.ToString()
      register: version_check

    - name: Show module version
      debug:
        msg: "AWS.Tools.S3 version: {{ version_check.stdout | trim }}"
'''

RETURN = r'''
changed:
  description: Whether any changes were made
  returned: always
  type: bool
  sample: true
installed_modules:
  description: List of newly installed modules
  returned: always
  type: list
  elements: str
  sample: [ "AWS.Tools.Installer", "AWS.Tools.S3", "AWS.Tools.EC2" ]
updated_modules:
  description: List of updated modules
  returned: always
  type: list
  elements: str
  sample: [ "AWS.Tools.S3 (from v4.1.450)" ]
removed_modules:
  description: List of removed modules
  returned: always
  type: list
  elements: str
  sample: [ "AWS.Tools.S3" ]
skipped_modules:
  description: List of modules that didn't need changes
  returned: always
  type: list
  elements: str
  sample: [ "AWS.Tools.EC2 (already installed v4.1.450)" ]
initial_state:
  description: Installed AWS modules before the operation
  returned: always
  type: dict
  sample:
    AWS.Tools.Installer: "1.0.2.5"
    AWS.Tools.S3: "4.1.450"
final_state:
  description: Installed AWS modules after the operation
  returned: when not in check mode
  type: dict
  sample:
    AWS.Tools.Installer: "1.0.2.5"
    AWS.Tools.S3: "4.1.450"
    AWS.Tools.EC2: "4.1.450"
msg:
  description: Human-readable summary of the operation
  returned: always
  type: str
  sample: "Installed: AWS.Tools.Installer, AWS.Tools.S3, AWS.Tools.EC2"
'''

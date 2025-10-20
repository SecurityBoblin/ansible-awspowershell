#!/bin/bash
#
# Setup and Test Script for Ansible AWS PowerShell Collection
#
# This script builds, installs, and optionally tests the collection.
#
# Usage:
#   ./setup_and_test.sh              # Build and install only
#   ./setup_and_test.sh --test       # Build, install, and run quick test
#   ./setup_and_test.sh --full-test  # Build, install, and run full test suite

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "Ansible AWS PowerShell Collection Setup"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
echo ""

if ! command -v ansible &> /dev/null; then
    echo -e "${RED}Error: Ansible is not installed${NC}"
    echo "Install with: pip install ansible"
    exit 1
fi

echo -e "${GREEN}✓${NC} Ansible found: $(ansible --version | head -n1)"

if ! command -v ansible-galaxy &> /dev/null; then
    echo -e "${RED}Error: ansible-galaxy is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} ansible-galaxy found"
echo ""

# Step 2: Build the collection
echo "Step 2: Building collection..."
echo ""

# Remove old builds
rm -f *.tar.gz

# Build
if ansible-galaxy collection build; then
    echo -e "${GREEN}✓${NC} Collection built successfully"
else
    echo -e "${RED}Error: Collection build failed${NC}"
    exit 1
fi

# Find the built tarball
TARBALL=$(ls -t community-awspowershell-*.tar.gz 2>/dev/null | head -n1)

if [ -z "$TARBALL" ]; then
    echo -e "${RED}Error: Could not find built collection tarball${NC}"
    exit 1
fi

echo "  Built: $TARBALL"
echo ""

# Step 3: Install the collection
echo "Step 3: Installing collection..."
echo ""

if ansible-galaxy collection install "$TARBALL" --force; then
    echo -e "${GREEN}✓${NC} Collection installed successfully"
else
    echo -e "${RED}Error: Collection installation failed${NC}"
    exit 1
fi

# Verify installation
INSTALL_PATH=$(ansible-galaxy collection list | grep "community.awspowershell" | awk '{print $1}' || echo "")

if [ -n "$INSTALL_PATH" ]; then
    echo "  Installed at: ~/.ansible/collections/ansible_collections/community/awspowershell"
else
    echo -e "${YELLOW}Warning: Could not verify installation path${NC}"
fi
echo ""

# Step 4: Check AWS credentials (optional)
echo "Step 4: Checking AWS credentials..."
echo ""

if command -v aws &> /dev/null; then
    if aws sts get-caller-identity &> /dev/null; then
        echo -e "${GREEN}✓${NC} AWS credentials configured"
        aws sts get-caller-identity --output json | grep -E "(UserId|Account|Arn)" || true
    else
        echo -e "${YELLOW}!${NC} AWS credentials not configured (optional for basic setup)"
        echo "  To configure: aws configure"
        echo "  Or set: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    fi
else
    echo -e "${YELLOW}!${NC} AWS CLI not installed (optional)"
fi
echo ""

# Step 5: Installation complete
echo "========================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================="
echo ""
echo "Collection: community.awspowershell v1.0.0"
echo "Modules:"
echo "  - community.awspowershell.aws_s3_object"
echo "  - community.awspowershell.aws_ec2_tags"
echo ""

# Step 6: Run tests if requested
if [ "$1" == "--test" ]; then
    echo "========================================="
    echo "Running Quick Test"
    echo "========================================="
    echo ""
    echo -e "${YELLOW}Note: Edit quick_test.yml to set your bucket and instance ID${NC}"
    echo ""
    read -p "Press Enter to continue with test, or Ctrl+C to cancel..."
    echo ""

    ansible-playbook quick_test.yml -v

elif [ "$1" == "--full-test" ]; then
    echo "========================================="
    echo "Running Full Test Suite"
    echo "========================================="
    echo ""
    echo -e "${YELLOW}Note: Edit tests/integration/integration_config.yml first${NC}"
    echo ""
    read -p "Press Enter to continue with tests, or Ctrl+C to cancel..."
    echo ""

    ansible-playbook run_tests.yml -v
else
    echo "Next steps:"
    echo ""
    echo "1. Quick test (manual edit required):"
    echo "   Edit quick_test.yml and set your bucket/instance"
    echo "   Then run: ansible-playbook quick_test.yml -v"
    echo ""
    echo "2. Full test suite:"
    echo "   Edit tests/integration/integration_config.yml"
    echo "   Then run: ansible-playbook run_tests.yml"
    echo ""
    echo "3. Use in your playbooks:"
    echo "   See README.md for examples"
    echo ""
    echo "Documentation:"
    echo "  - README.md - Quick start and examples"
    echo ""
fi

echo "========================================="

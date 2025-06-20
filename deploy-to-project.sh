#!/bin/bash
# Quick deployment script for Claude Workflow Framework with Redis file building
# Usage: ./deploy-to-project.sh <target-project-directory>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <target-project-directory>"
    echo ""
    echo "Example: $0 /path/to/my-project"
    echo "         $0 ~/my-new-app"
    echo ""
    echo "This will install the Claude Workflow Framework with Redis-enhanced"
    echo "file building into the specified project directory."
    exit 1
fi

TARGET_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Claude Workflow Framework Deployment ==="
echo "Framework source: $SCRIPT_DIR"
echo "Target project: $TARGET_DIR"
echo ""

# Validate target directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist."
    read -p "Create directory '$TARGET_DIR'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$TARGET_DIR"
        echo "✓ Created directory: $TARGET_DIR"
    else
        echo "Deployment cancelled."
        exit 1
    fi
fi

# Run the installation script
echo "Installing framework..."
"$SCRIPT_DIR/install-framework.sh" "$TARGET_DIR"

# Change to target directory and run setup
echo ""
echo "=== Running Initial Setup ==="
cd "$TARGET_DIR"

# Run coordination setup
if [ -f ".claude/scripts/setup-coordination.sh" ]; then
    ./.claude/scripts/setup-coordination.sh
else
    echo "Warning: Setup script not found, skipping initial setup"
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Your project is now equipped with:"
echo "✓ Redis-enhanced file building system"
echo "✓ Automatic worker coordination"
echo "✓ Work recovery mechanisms"
echo "✓ Service dependency management"
echo ""
echo "To start using the enhanced coordination:"
echo ""
echo "1. Start Redis coordination services:"
echo "   docker-compose -f docker-compose.coordination.yml up -d"
echo ""
echo "2. Start the workflow coordinator:"
echo "   ./.claude/scripts/workflow-coordinator.sh start"
echo ""
echo "3. Test Redis file operations:"
echo "   ./.claude/scripts/workflow-coordinator.sh test-file-ops"
echo ""
echo "4. Load coordination utilities in your shell:"
echo "   source .claude/scripts/coordination-utils.sh"
echo ""
echo "5. Check system status:"
echo "   ./.claude/scripts/workflow-coordinator.sh status"
echo ""
echo "For more information, see: .claude/README.md"
echo ""
echo "Happy coding with enhanced Claude coordination! 🚀"
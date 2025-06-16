# Claude Framework Installer (Swift)

A Swift command-line application that automates the installation and setup of the Claude Workflow Framework.

## Features

- Automatic framework detection
- Interactive CLI interface
- Project type detection (Node.js, Python, Go, Rust)
- Automatic configuration generation
- Complete setup automation
- Progress logging

## Building

```bash
swift build -c release
```

## Running

### Direct execution:
```bash
swift run claude-installer
```

### Or build and run:
```bash
swift build -c release
./.build/release/claude-installer
```

## Usage

1. Run the installer
2. Enter the target directory path (or press Enter for current directory)
3. Confirm installation
4. The installer will:
   - Detect the framework location
   - Create .claude directory structure
   - Copy all framework files
   - Generate configuration files
   - Set up coordination scripts
   - Create Docker compose file
   - Generate agent ID

## What it does

- Creates `.claude/` directory with full framework structure
- Installs coordination utilities
- Sets up project-specific configuration
- Generates unique agent ID
- Creates ready-to-use scripts

After installation, you can immediately use:
```bash
source .claude/scripts/coordination-utils.sh
claude-status
```
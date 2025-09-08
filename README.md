# Gemini CLI Manager for Termux

A comprehensive management tool for installing, updating, and managing the Google Gemini CLI on Termux.

## Features

- **Install**: Install any available version of the Gemini CLI
- **Update**: Update to the latest version of the Gemini CLI
- **Delete**: Completely remove the Gemini CLI installation
- **List**: Fetch and display all available versions from the npm registry
- Interactive menu or command-line interface
- Smart version checking to avoid unnecessary reinstalls
- Force options for automation

## Prerequisites

- Termux installed on your Android device
- Internet connection for downloading packages

## Installation

The manager script is ready to use. Simply navigate to the directory and run:

```bash
cd ~/gemini-cli-manager
bash gemini-manager.sh
```

or download via curl and run
```bash
curl -OL https://raw.githubusercontent.com/breixopd/gemini-cli-manager/refs/heads/master/gemini-manager.sh;bash gemini-manager.sh
```

## Usage

### Interactive Mode

Run the script without arguments to use the interactive menu:

```bash
bash gemini-manager.sh
```

This will display a menu with options:
1. Install Gemini CLI
2. Update Gemini CLI
3. List available versions
4. Delete Gemini CLI
5. Exit

### Command Line Interface

You can also use command-line arguments for automation:

```bash
# Install a specific version
bash gemini-manager.sh install 0.3.2

# Install latest version (will prompt for version selection)
bash gemini-manager.sh install

# Update to the latest version
bash gemini-manager.sh update

# List all available versions
bash gemini-manager.sh list

# Delete the installation
bash gemini-manager.sh delete

# Force delete (no confirmation prompt)
bash gemini-manager.sh --force delete
```

## How It Works

1. **Installation Process**:
   - Updates Termux packages
   - Installs required dependencies (Node.js, Python, Rust, etc.)
   - Downloads the specified version from npm registry
   - Compiles ripgrep from source (required dependency)
   - Creates a wrapper script in `/data/data/com.termux/files/usr/bin/gemini`

2. **Version Management**:
   - Fetches the latest available versions from the npm registry
   - Compares installed version with latest available
   - Prevents unnecessary reinstalls of the same version

3. **Update Process**:
   - Checks current installed version
   - Fetches latest version from npm registry
   - Updates only if a newer version is available

4. **Deletion**:
   - Removes the installation directory
   - Removes the wrapper script
   - Can be forced for automation scripts

## Available Versions

The list command fetches all available versions from the npm registry. Some notable versions include:
- 0.3.2 (Stable release)
- 0.4.x (Preview releases)
- 0.5.x (Nightly builds)

## Authentication

After installation, you'll need to authenticate with your Google account:

```bash
gemini auth
```

## Troubleshooting

If you encounter issues:

1. **Installation fails**: Ensure you have sufficient storage space and a stable internet connection
2. **Command not found**: Verify the wrapper script was created in `/data/data/com.termux/files/usr/bin/`
3. **Permission denied**: Ensure the script has execute permissions (`chmod +x gemini-manager.sh`)

## License

This tool is provided as-is without any warranty. Use at your own risk.

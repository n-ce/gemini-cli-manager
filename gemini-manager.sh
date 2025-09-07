#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Gemini CLI Manager for Termux
#
# This script provides a complete management system for the Gemini CLI:
# - Install (with version selection)
# - Update (to latest version)
# - Delete (complete removal)
# - List (fetch and display available versions)
# ==============================================================================

# --- Configuration ---
INSTALL_DIR="$HOME/.gemini-cli"
RIPGREP_SRC_DIR="/data/data/com.termux/files/usr/tmp/ripgrep-src"
TARGET_BIN_DIR="/data/data/com.termux/files/usr/bin"
TARGET_EXECUTABLE="$TARGET_BIN_DIR/gemini"

# Default versions (will be updated by list command)
AVAILABLE_VERSIONS=("0.3.2" "0.3.1" "0.3.0" "0.2.1" "0.2.0")

# --- Helper Functions ---
print_info() { echo -e "\033[1;34m[*] $1\033[0m"; }
print_success() { echo -e "\033[1;32m[+] $1\033[0m"; }
print_error() { echo -e "\033[1;31m[!] $1\033[0m"; }
print_warning() { echo -e "\033[1;33m[!] $1\033[0m"; }

# --- Cleanup ---
cleanup() {
    # Only cleanup if we're doing an install operation
    if [ "$1" = "install" ]; then
        print_info "Cleaning up temporary build files..."
        rm -rf "$RIPGREP_SRC_DIR"
        print_success "Cleanup complete."
    fi
}
# trap cleanup EXIT

# --- Check if installed ---
is_installed() {
    if [ -d "$INSTALL_DIR" ] && [ -f "$TARGET_EXECUTABLE" ] && command -v gemini &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

# --- Get current version ---
get_current_version() {
    if is_installed; then
        gemini --version 2>/dev/null
    else
        echo "not_installed"
    fi
}

# --- Fetch available versions from npm registry ---
fetch_versions() {
    print_info "Fetching available versions from npm registry..."
    
    # Try to fetch versions from npm registry
    if command -v curl &> /dev/null; then
        # Fetch package info from npm registry
        RESPONSE=$(curl -s "https://registry.npmjs.org/@google/gemini-cli" 2>/dev/null)
        
        if [ -n "$RESPONSE" ] && echo "$RESPONSE" | grep -q "versions"; then
            # Extract versions using jq
            if command -v jq &> /dev/null; then
                # Get all versions and sort them
                VERSIONS=$(echo "$RESPONSE" | jq -r '.versions | keys | .[]' 2>/dev/null | sort -Vr)
                
                if [ -n "$VERSIONS" ]; then
                    # Convert to array
                    mapfile -t AVAILABLE_VERSIONS <<< "$VERSIONS"
                    print_success "Found ${#AVAILABLE_VERSIONS[@]} available versions:"
                    return 0
                fi
            else
                # Fallback: parse with grep and sed
                VERSIONS=$(echo "$RESPONSE" | grep -o '"[0-9]*\.[0-9]*\.[0-9]*"' | sed 's/"//g' | sort -Vr | uniq)
                if [ -n "$VERSIONS" ]; then
                    mapfile -t AVAILABLE_VERSIONS <<< "$VERSIONS"
                    print_success "Found ${#AVAILABLE_VERSIONS[@]} available versions:"
                    return 0
                fi
            fi
        fi
    fi
    
    # Fallback to default versions if fetch fails
    print_warning "Could not fetch versions from registry. Using default versions."
    return 1
}

# --- List available versions ---
list_versions() {
    # Try to fetch latest versions
    fetch_versions
    
    echo
    print_info "Available Gemini CLI versions:"
    for i in "${!AVAILABLE_VERSIONS[@]}"; do
        if [ $i -eq 0 ]; then
            echo "  $((i+1)). ${AVAILABLE_VERSIONS[$i]} (Latest)"
        else
            echo "  $((i+1)). ${AVAILABLE_VERSIONS[$i]}"
        fi
    done
    echo
    
    # Show current installed version if applicable
    if is_installed; then
        CURRENT_VERSION=$(get_current_version)
        print_success "Currently installed: v$CURRENT_VERSION"
    else
        print_warning "Not currently installed"
    fi
}

# --- Version Selection ---
select_version() {
    # Fetch latest versions before selection
    fetch_versions
    
    echo
    print_info "Available Gemini CLI versions:"
    for i in "${!AVAILABLE_VERSIONS[@]}"; do
        if [ $i -eq 0 ]; then
            echo "  $((i+1)). ${AVAILABLE_VERSIONS[$i]} (Recommended)"
        else
            echo "  $((i+1)). ${AVAILABLE_VERSIONS[$i]}"
        fi
    done
    echo
    read -p "Select version (1-${#AVAILABLE_VERSIONS[@]}): " version_choice
    
    case $version_choice in
        1|2|3|4|5|6|7|8|9|[1-9][0-9]*)
            if [ $version_choice -ge 1 ] && [ $version_choice -le ${#AVAILABLE_VERSIONS[@]} ]; then
                SELECTED_VERSION="${AVAILABLE_VERSIONS[$((version_choice-1))]}"
                print_success "Selected version: $SELECTED_VERSION"
            else
                print_warning "Invalid choice. Using latest version."
                SELECTED_VERSION="${AVAILABLE_VERSIONS[0]}"
                print_success "Selected version: $SELECTED_VERSION"
            fi
            ;;
        *)
            print_warning "Invalid choice. Using latest version."
            SELECTED_VERSION="${AVAILABLE_VERSIONS[0]}"
            print_success "Selected version: $SELECTED_VERSION"
            ;;
    esac
}

# --- Install Function ---
install_gemini() {
    # Check if already installed
    if is_installed; then
        CURRENT_VERSION=$(get_current_version)
        if [ -n "$SELECTED_VERSION" ] && [ "$CURRENT_VERSION" = "$SELECTED_VERSION" ]; then
            print_info "Gemini CLI v$SELECTED_VERSION is already installed."
            return 0
        elif [ -z "$SELECTED_VERSION" ]; then
            print_info "Gemini CLI v$CURRENT_VERSION is already installed."
            if [ "$FORCE_OPERATION" != "true" ]; then
                read -p "Do you want to reinstall? (y/N): " reinstall
                case $reinstall in
                    [yY]|[yY][eE][sS])
                        print_info "Reinstalling Gemini CLI..."
                        ;;
                    *)
                        print_info "Installation cancelled."
                        return 0
                        ;;
                esac
            else
                print_info "Reinstalling Gemini CLI (forced)..."
            fi
        fi
    fi
    
    if [ -z "$SELECTED_VERSION" ]; then
        select_version
    fi
    
    clear
    echo -e "\033[1;35m===================================================\033[0m"
    echo -e "\033[1;35m  Installing Gemini CLI v$SELECTED_VERSION for Termux"
    echo -e "\033[1;35m===================================================\033[0m"
    echo

    # Step 1: Install dependencies
    print_info "Updating packages and installing dependencies..."
    pkg update -y && pkg upgrade -y > /dev/null 2>&1
    pkg install -y nodejs python make clang git rust jq > /dev/null 2>&1
    print_success "All dependencies are installed."
    echo

    # Step 2: Set up installation directory
    print_info "Setting up installation directory at $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    print_success "Directory created."
    echo

    # Step 3: Download and extract package
    GEMINI_PKG_URL="https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-$SELECTED_VERSION.tgz"
    print_info "Downloading Gemini CLI v$SELECTED_VERSION..."
    if curl -fLo gemini-cli.tgz "$GEMINI_PKG_URL"; then
        tar -xzf gemini-cli.tgz
        cd package
        print_success "Download and extraction complete."
    else
        print_error "Failed to download Gemini CLI package."
        cleanup install
        exit 1
    fi
    echo

    # Step 4: Install dependencies locally
    print_info "Installing npm dependencies..."
    if npm install --ignore-scripts --no-audit --fund false; then
        print_success "Dependencies installed successfully."
    else
        print_error "Failed to install dependencies. Aborting."
        cleanup install
        exit 1
    fi
    echo

    # Step 5: Patch and compile ripgrep
    RIPGREP_PATCH_SCRIPT_PATH="node_modules/@lvce-editor/ripgrep/src/postinstall.cjs"
    print_info "Patching '@lvce-editor/ripgrep' to build from source..."
    rm -f "node_modules/@lvce-editor/ripgrep/src/postinstall.js"
    cat << EOF > "$RIPGREP_PATCH_SCRIPT_PATH"
const { execSync } = require('child_process');
const { renameSync, existsSync, mkdirSync } = require('fs');
const path = require('path');
try {
  const BIN_DIR = path.join(__dirname, '../bin');
  execSync('rm -rf $RIPGREP_SRC_DIR && git clone --depth 1 --branch 13.0.0 https://github.com/BurntSushi/ripgrep.git $RIPGREP_SRC_DIR', { stdio: 'inherit' });
  execSync('cd $RIPGREP_SRC_DIR && cargo build --release --target aarch64-linux-android', { stdio: 'inherit' });
  const compiledBinaryPath = path.join('$RIPGREP_SRC_DIR', 'target', 'aarch64-linux-android', 'release', 'rg');
  if (!existsSync(BIN_DIR)) mkdirSync(BIN_DIR, { recursive: true });
  renameSync(compiledBinaryPath, path.join(BIN_DIR, 'rg'));
  console.log('[+] Ripgrep compiled and moved successfully.');
} catch (error) { console.error('[!] Failed to compile ripgrep:', error); process.exit(1); }
EOF

    print_info "Executing the patched build script for ripgrep..."
    if node "$RIPGREP_PATCH_SCRIPT_PATH"; then
        print_success "Ripgrep compiled successfully."
    else
        print_error "Failed to compile ripgrep."
        cleanup install
        exit 1
    fi
    echo

    # Step 6: Create the Command Wrapper
    print_info "Creating system-wide command wrapper..."
    # Remove any existing gemini command
    rm -f "$TARGET_EXECUTABLE"

    # Create the wrapper script
    cat << EOF > "$TARGET_EXECUTABLE"
#!/data/data/com.termux/files/usr/bin/bash
# Wrapper script for the Gemini CLI
# This executes the main JS file from its permanent location.

node "$HOME/.gemini-cli/package/dist/index.js" "\$@"
EOF

    chmod +x "$TARGET_EXECUTABLE"
    print_success "Command wrapper created at $TARGET_EXECUTABLE."
    echo

    # Step 7: Final Verification
    print_info "Verifying installation..."
    if command -v gemini &> /dev/null; then
        VERSION=$(gemini --version)
        if [ -n "$VERSION" ]; then
            print_success "Verification successful! Gemini CLI v$VERSION is ready."
            echo
            echo -e "\033[1;33m-----------------------------------------\033[0m"
            echo -e "\033[1;33m           NEXT STEP: AUTHENTICATE\033[0m"
            echo -e "\033[1;33m-----------------------------------------\033[0m"
            echo -e "To use the CLI, run: \033[1;32mgemini auth\033[0m"
            echo -e "\033[1;33m-----------------------------------------\033[0m"
        else
            print_error "Verification failed: Command exists but failed to execute."
            cleanup install
            exit 1
        fi
    else
        print_error "Verification failed: The 'gemini' command was not found."
        cleanup install
        exit 1
    fi
    echo
    
    cleanup install
}

# --- Update Function ---
update_gemini() {
    print_info "Checking current version..."
    if is_installed; then
        CURRENT_VERSION=$(get_current_version)
        print_info "Current version: $CURRENT_VERSION"
        
        # Fetch latest versions
        fetch_versions
        LATEST_VERSION="${AVAILABLE_VERSIONS[0]}"
        print_info "Latest version: $LATEST_VERSION"
        
        if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
            print_success "Gemini CLI is already up to date."
            return 0
        else
            print_info "Updating to latest version..."
            SELECTED_VERSION="$LATEST_VERSION"
            install_gemini
        fi
    else
        print_error "Gemini CLI is not installed. Run install first."
        exit 1
    fi
}

# --- Delete Function ---
delete_gemini() {
    if ! is_installed; then
        print_info "Gemini CLI is not installed."
        return 0
    fi
    
    if [ "$FORCE_OPERATION" = "true" ]; then
        print_info "Removing Gemini CLI (forced)..."
        rm -rf "$INSTALL_DIR"
        rm -f "$TARGET_EXECUTABLE"
        print_success "Gemini CLI has been removed from your system."
        return 0
    fi
    
    print_warning "This will completely remove Gemini CLI from your system."
    read -p "Are you sure you want to continue? (y/N): " confirm
    case $confirm in
        [yY]|[yY][eE][sS])
            print_info "Removing Gemini CLI..."
            rm -rf "$INSTALL_DIR"
            rm -f "$TARGET_EXECUTABLE"
            print_success "Gemini CLI has been removed from your system."
            ;;
        *)
            print_info "Operation cancelled."
            ;;
    esac
}

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "\033[1;35m===================================================\033[0m"
    echo -e "\033[1;35m        Gemini CLI Manager for Termux"
    echo -e "\033[1;35m===================================================\033[0m"
    echo
    
    # Show current status
    if is_installed; then
        CURRENT_VERSION=$(get_current_version)
        print_success "Status: Installed (v$CURRENT_VERSION)"
    else
        print_warning "Status: Not installed"
    fi
    
    echo
    echo "1. Install Gemini CLI"
    echo "2. Update Gemini CLI"
    echo "3. List available versions"
    echo "4. Delete Gemini CLI"
    echo "5. Exit"
    echo
    read -p "Enter your choice (1-5): " choice

    case $choice in
        1)
            install_gemini
            read -p "Press Enter to continue..."
            show_menu
            ;;
        2)
            update_gemini
            read -p "Press Enter to continue..."
            show_menu
            ;;
        3)
            list_versions
            read -p "Press Enter to continue..."
            show_menu
            ;;
        4)
            delete_gemini
            read -p "Press Enter to continue..."
            show_menu
            ;;
        5)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option. Please try again."
            sleep 2
            show_menu
            ;;
    esac
}

# --- CLI Command Handler ---
# Parse command line arguments
FORCE_OPERATION="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_OPERATION="true"
            shift
            ;;
        install|update|delete|list)
            OPERATION="$1"
            shift
            if [ "$OPERATION" = "install" ] && [ -n "$1" ]; then
                VERSION_ARG="$1"
                shift
            fi
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Execute the requested operation
case "$OPERATION" in
    install)
        if [ -n "$VERSION_ARG" ]; then
            # Set the selected version directly
            SELECTED_VERSION="$VERSION_ARG"
        fi
        install_gemini
        ;;
    update)
        update_gemini
        ;;
    delete)
        delete_gemini
        ;;
    list)
        list_versions
        ;;
    *)
        # Show interactive menu if no valid command provided
        show_menu
        ;;
esac
#!/bin/bash

# Universal Screenshot Wrapper Script
# Creates aliases for GNOME screenshot commands to work with various desktop environments
# Usage: sudo ./screenshot_wrapper.sh [distro] [options]
# Supported distros: fedora, ubuntu, arch, opensuse, debian

set -e

# Screenshot commands that automation tools commonly use
COMMANDS=("gnome-screenshot" "import" "xwd" "scrot")

# Function to detect desktop environment
detect_desktop() {
    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
        echo "kde"
    elif [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        echo "gnome"
    elif [ "$XDG_CURRENT_DESKTOP" = "XFCE" ]; then
        echo "xfce"
    elif [ "$XDG_CURRENT_DESKTOP" = "MATE" ]; then
        echo "mate"
    else
        echo "unknown"
    fi
}

# Function to install required screenshot tool based on distro
install_screenshot_tool() {
    local distro="$1"
    local tool="$2"
    
    case "$distro" in
        fedora)
            sudo dnf install -y "$tool"
            ;;
        ubuntu|debian)
            sudo apt update && sudo apt install -y "$tool"
            ;;
        arch)
            sudo pacman -S --noconfirm "$tool"
            ;;
        opensuse)
            sudo zypper install -y "$tool"
            ;;
        *)
            echo "Warning: Unknown distro. Please install $tool manually."
            ;;
    esac
}

# Function to create wrapper script
create_wrapper() {
    local cmd="$1"
    local target="$2"
    local wrapper_path="/usr/local/bin/$cmd"

    echo "Creating wrapper for $cmd using $target..."

    sudo tee "$wrapper_path" > /dev/null << 'EOF'
#!/bin/bash
# Auto-generated wrapper script

OUTPUT_FILE="${1:-/tmp/screenshot.png}"
WINDOW_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            shift
            OUTPUT_FILE="$1"
            ;;
        --file=*)
            OUTPUT_FILE="${1#*=}"
            ;;
        -w|--window)
            WINDOW_MODE=true
            ;;
        --delay=*)
            DELAY="${1#*=}"
            ;;
        -d|--delay)
            shift
            DELAY="$1"
            ;;
    esac
    shift
done

# Execute appropriate screenshot command
TARGET_CMD="TARGET_PLACEHOLDER"
if [ "$WINDOW_MODE" = true ]; then
    if command -v spectacle >/dev/null 2>&1; then
        spectacle -a -b -o "$OUTPUT_FILE" ${DELAY:+-d $DELAY}
    elif command -v flameshot >/dev/null 2>&1; then
        flameshot gui --raw > "$OUTPUT_FILE"
    elif command -v maim >/dev/null 2>&1; then
        maim -s "$OUTPUT_FILE"
    else
        $TARGET_CMD -f -b -o "$OUTPUT_FILE"
    fi
else
    if command -v spectacle >/dev/null 2>&1; then
        spectacle -f -b -o "$OUTPUT_FILE" ${DELAY:+-d $DELAY}
    elif command -v flameshot >/dev/null 2>&1; then
        flameshot full --raw > "$OUTPUT_FILE"
    elif command -v maim >/dev/null 2>&1; then
        maim "$OUTPUT_FILE"
    elif command -v scrot >/dev/null 2>&1; then
        scrot "$OUTPUT_FILE"
    else
        $TARGET_CMD -f -b -o "$OUTPUT_FILE"
    fi
fi
EOF

    # Replace placeholder with actual target command
    sudo sed -i "s/TARGET_PLACEHOLDER/$target/g" "$wrapper_path"
    sudo chmod +x "$wrapper_path"
    echo "✓ Wrapper for $cmd created"
}

# Function to show usage
show_usage() {
    cat << EOF
Universal Screenshot Wrapper Script

Usage: sudo $0 [DISTRO] [OPTIONS]

DISTRO OPTIONS:
  fedora     - Fedora Linux (uses Spectacle for KDE)
  ubuntu     - Ubuntu Linux (uses GNOME Screenshot or Flameshot)
  arch       - Arch Linux (uses Flameshot)
  opensuse   - openSUSE (uses Spectacle for KDE)
  debian     - Debian (uses GNOME Screenshot or Flameshot)
  auto       - Auto-detect distribution (default)

OPTIONS:
  --install-deps    Install required screenshot tools
  --remove          Remove all created wrappers
  --test            Test wrapper functionality
  --help            Show this help message

EXAMPLES:
  sudo $0 fedora --install-deps
  sudo $0 ubuntu
  sudo $0 auto --test

This script creates wrapper scripts that redirect GNOME screenshot commands
to work with various desktop environments and distributions.
EOF
}

# Function to remove wrappers
remove_wrappers() {
    echo "Removing screenshot wrappers..."
    for cmd in "${COMMANDS[@]}"; do
        if [ -f "/usr/local/bin/$cmd" ]; then
            sudo rm "/usr/local/bin/$cmd"
            echo "✓ Removed wrapper for $cmd"
        fi
    done
    echo "All wrappers removed."
}

# Function to test wrappers
test_wrappers() {
    echo "Testing screenshot wrappers..."
    for cmd in "${COMMANDS[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "Testing $cmd..."
            if "$cmd" -f "/tmp/test_$cmd.png" 2>/dev/null; then
                echo "✓ $cmd wrapper working"
                rm -f "/tmp/test_$cmd.png"
            else
                echo "✗ $cmd wrapper failed"
            fi
        fi
    done
}

# Main script logic
main() {
    local distro="${1:-auto}"
    local install_deps=false
    local remove_mode=false
    local test_mode=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-deps)
                install_deps=true
                ;;
            --remove)
                remove_mode=true
                ;;
            --test)
                test_mode=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
        esac
        shift
    done

    # Handle special modes
    if [ "$remove_mode" = true ]; then
        remove_wrappers
        exit 0
    fi

    if [ "$test_mode" = true ]; then
        test_wrappers
        exit 0
    fi

    # Auto-detect distribution if needed
    if [ "$distro" = "auto" ]; then
        if [ -f /etc/fedora-release ]; then
            distro="fedora"
        elif [ -f /etc/ubuntu-release ] || [ -f /etc/debian_version ]; then
            distro="ubuntu"
        elif [ -f /etc/arch-release ]; then
            distro="arch"
        elif [ -f /etc/SuSE-release ]; then
            distro="opensuse"
        else
            distro="fedora"  # Default fallback
        fi
        echo "Auto-detected distribution: $distro"
    fi

    # Determine target screenshot tool based on distro and desktop
    local desktop=$(detect_desktop)
    local target_cmd

    case "$distro-$desktop" in
        fedora-kde|opensuse-kde)
            target_cmd="spectacle"
            [ "$install_deps" = true ] && install_screenshot_tool "$distro" "spectacle"
            ;;
        ubuntu-*|debian-*)
            target_cmd="flameshot"
            [ "$install_deps" = true ] && install_screenshot_tool "$distro" "flameshot"
            ;;
        arch-*)
            target_cmd="flameshot"
            [ "$install_deps" = true ] && install_screenshot_tool "$distro" "flameshot"
            ;;
        *-gnome)
            target_cmd="gnome-screenshot"
            ;;
        *)
            target_cmd="spectacle"  # Safe default
            echo "Warning: Unknown combination $distro-$desktop, using spectacle as default"
            ;;
    esac

    echo "Setting up screenshot wrappers for $distro ($desktop desktop)..."
    echo "Target screenshot tool: $target_cmd"

    # Create wrappers for all commands
    for cmd in "${COMMANDS[@]}"; do
        create_wrapper "$cmd" "$target_cmd"
    done

    # Update PATH if needed
    if ! echo "$PATH" | grep -q '/usr/local/bin'; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
        echo "✓ Added /usr/local/bin to PATH"
        echo "Note: Open a new terminal or run 'source ~/.bashrc' to activate"
    else
        echo "✓ /usr/local/bin already in PATH"
    fi

    echo ""
    echo "🎉 Screenshot wrapper setup complete for $distro!"
    echo "All automation tools should now work with your native screenshot tools."
    echo ""
    echo "To test: run '$0 --test'"
    echo "To remove: run 'sudo $0 --remove'"
}

# Run main function with all arguments
main "$@"

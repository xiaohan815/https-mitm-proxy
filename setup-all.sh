#!/bin/bash

# HTTPS MITM Proxy - Universal Setup Script
# Automatically detects OS and runs the appropriate setup script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        # WSL (Windows Subsystem for Linux)
        echo "wsl"
    else
        echo "unknown"
    fi
}

# Main setup function
main() {
    print_info "HTTPS MITM Proxy - Universal Setup"
    echo ""
    
    # Detect OS
    OS=$(detect_os)
    print_info "Detected operating system: $OS"
    echo ""
    
    # Run appropriate setup script
    case $OS in
        linux)
            print_info "Running Linux setup script..."
            if [[ -f "./setup-linux.sh" ]]; then
                chmod +x ./setup-linux.sh
                ./setup-linux.sh
            else
                print_error "setup-linux.sh not found!"
                exit 1
            fi
            ;;
        
        macos)
            print_info "Running macOS setup script..."
            if [[ -f "./setup-macos.sh" ]]; then
                chmod +x ./setup-macos.sh
                ./setup-macos.sh
            else
                print_error "setup-macos.sh not found!"
                exit 1
            fi
            ;;
        
        windows|wsl)
            print_warning "Windows detected!"
            echo ""
            if [[ "$OS" == "wsl" ]]; then
                print_info "You are running WSL (Windows Subsystem for Linux)"
                print_info "You can either:"
                echo "  1. Run the Linux setup: ./setup-linux.sh"
                echo "  2. Run the Windows setup in PowerShell: ./setup-windows.ps1"
            else
                print_info "Please run the Windows setup script in PowerShell:"
                echo ""
                echo "  powershell -ExecutionPolicy Bypass -File ./setup-windows.ps1"
                echo ""
                print_info "Or if you're in Git Bash/MSYS2, you can try:"
                echo "  ./setup-windows.ps1"
            fi
            exit 0
            ;;
        
        unknown)
            print_error "Unable to detect operating system!"
            echo ""
            print_info "Please manually run the appropriate setup script:"
            echo "  - Linux:   ./setup-linux.sh"
            echo "  - macOS:   ./setup-macos.sh"
            echo "  - Windows: ./setup-windows.ps1"
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Setup completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Review the .env file and adjust settings if needed"
    echo "  2. Start the proxy: npm start"
    echo "  3. Test the connection: ./test-connection.sh"
}

# Run main function
main "$@"

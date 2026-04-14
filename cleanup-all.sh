#!/bin/bash

# HTTPS MITM Proxy - Universal Cleanup Script
# Automatically detects OS and runs the appropriate cleanup script

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

# Main cleanup function
main() {
    print_warning "HTTPS MITM Proxy - Universal Cleanup"
    echo ""
    print_warning "This will remove all proxy configurations and certificates!"
    echo ""
    
    # Ask for confirmation
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled."
        exit 0
    fi
    
    echo ""
    
    # Detect OS
    OS=$(detect_os)
    print_info "Detected operating system: $OS"
    echo ""
    
    # Run appropriate cleanup script
    case $OS in
        linux)
            print_info "Running Linux cleanup script..."
            if [[ -f "./cleanup-linux.sh" ]]; then
                chmod +x ./cleanup-linux.sh
                ./cleanup-linux.sh
            else
                print_error "cleanup-linux.sh not found!"
                exit 1
            fi
            ;;
        
        macos)
            print_info "Running macOS cleanup script..."
            if [[ -f "./cleanup-macos.sh" ]]; then
                chmod +x ./cleanup-macos.sh
                ./cleanup-macos.sh
            else
                print_error "cleanup-macos.sh not found!"
                exit 1
            fi
            ;;
        
        windows|wsl)
            print_warning "Windows detected!"
            echo ""
            if [[ "$OS" == "wsl" ]]; then
                print_info "You are running WSL (Windows Subsystem for Linux)"
                print_info "You can either:"
                echo "  1. Run the Linux cleanup: ./cleanup-linux.sh"
                echo "  2. Run the Windows cleanup in PowerShell: ./cleanup-windows.ps1"
            else
                print_info "Please run the Windows cleanup script in PowerShell:"
                echo ""
                echo "  powershell -ExecutionPolicy Bypass -File ./cleanup-windows.ps1"
                echo ""
                print_info "Or if you're in Git Bash/MSYS2, you can try:"
                echo "  ./cleanup-windows.ps1"
            fi
            exit 0
            ;;
        
        unknown)
            print_error "Unable to detect operating system!"
            echo ""
            print_info "Please manually run the appropriate cleanup script:"
            echo "  - Linux:   ./cleanup-linux.sh"
            echo "  - macOS:   ./cleanup-macos.sh"
            echo "  - Windows: ./cleanup-windows.ps1"
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Cleanup completed successfully!"
}

# Run main function
main "$@"

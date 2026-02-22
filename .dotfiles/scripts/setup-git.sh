#!/bin/bash
# Setup Git Configuration - Run manually after bootstrap
# Configures git user.name and user.email from GitHub CLI

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

echo "========================================"
echo "  Git Configuration Setup"
echo "========================================"
echo ""

# Check if already configured
current_name=$(git config --global user.name 2>/dev/null || echo "")
current_email=$(git config --global user.email 2>/dev/null || echo "")

if [[ -n "$current_name" && -n "$current_email" ]]; then
    log_info "Git is already configured:"
    log_info "  Name: $current_name"
    log_info "  Email: $current_email"
    echo ""
    read -p "Do you want to reconfigure? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Keeping existing configuration."
        exit 0
    fi
fi

# Method 1: Try GitHub CLI
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null 2>&1; then
        log_info "Fetching git config from GitHub..."
        
        github_name=$(gh api user --jq '.name' 2>/dev/null || echo "")
        github_login=$(gh api user --jq '.login' 2>/dev/null || echo "")
        github_email=$(gh api user --jq '.email' 2>/dev/null || echo "")
        
        # Use name if available, otherwise login
        if [[ -n "$github_name" ]]; then
            suggested_name="$github_name"
        else
            suggested_name="$github_login"
        fi
        
        if [[ -n "$suggested_name" && -n "$github_email" ]]; then
            echo ""
            log_info "Found GitHub profile:"
            echo "  Name: $suggested_name"
            echo "  Email: $github_email"
            echo ""
            read -p "Use these settings? (Y/n): " -n 1 -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                git config --global user.name "$suggested_name"
                git config --global user.email "$github_email"
                log_info "Git configured successfully!"
                exit 0
            fi
        fi
    else
        log_warn "GitHub CLI not authenticated."
        log_info "Run \`gh auth login\` first if you want to use GitHub profile."
        echo ""
    fi
fi

# Method 2: Manual input
echo "Please enter your git configuration:"
echo ""

read -r -p "Full Name: " git_name
read -r -p "Email: " git_email

if [[ -z "$git_name" || -z "$git_email" ]]; then
    log_error "Both name and email are required."
    exit 1
fi

echo ""
log_info "Setting git configuration..."
git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global init.defaultBranch main

echo ""
log_info "Git configured successfully!"
log_info "  Name: $(git config --global user.name)"
log_info "  Email: $(git config --global user.email)"
log_info "  Default branch: $(git config --global init.defaultBranch)"

echo ""
echo "You can change these settings anytime with:"
echo "  git config --global user.name 'Your Name'"
echo "  git config --global user.email 'your@email.com'"

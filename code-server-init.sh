#!/bin/bash
set -e

# code-server-init.sh
# Initializes code-server with extensions and CLI tools for data science environment

# Ensure system directories are in PATH (critical for restricted environments)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add local installation directories to PATH (relative to script location)
export PATH="$SCRIPT_DIR/bin:$SCRIPT_DIR/node/bin:$SCRIPT_DIR/gh/bin:$SCRIPT_DIR/google-cloud-sdk/bin:$PATH"


# Use absolute paths for core utilities (for extremely restricted environments)
TAR="/bin/tar"
RM="/bin/rm"
MV="/bin/mv"

# Fallback to command if absolute paths don't exist
command -v tar &> /dev/null && TAR="tar"
command -v rm &> /dev/null && RM="rm"
command -v mv &> /dev/null && MV="mv"

echo "========================================"
echo "Code-Server Initialization Script"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if code-server is installed
if ! command -v code-server &> /dev/null; then
    print_error "code-server is not installed or not in PATH"
    print_status "Install code-server first: https://github.com/coder/code-server"
    exit 1
fi

print_status "code-server found: $(code-server --version | head -n 1)"

# This script works without sudo - all installations are local
print_status "Running in no-sudo mode - all tools install to current directory"

# ========================================
# Install VS Code Extensions
# ========================================
echo ""
print_status "Installing VS Code extensions..."

EXTENSIONS=(
    "marimo-team.vscode-marimo"
    "anthropic.claude-code"
    "mtxr.sqltools"
    "mtxr.sqltools-driver-pg"
)

for ext in "${EXTENSIONS[@]}"; do
    print_status "Installing extension: ${ext}"
    if code-server --install-extension "${ext}" --force; then
        print_status "✓ Successfully installed ${ext}"
    else
        print_warning "Failed to install ${ext}"
    fi
done

# ========================================
# Install CLI Tools
# ========================================
echo ""
print_status "Installing CLI tools..."

# Install gcloud (Google Cloud SDK)
echo ""
print_status "Installing gcloud CLI..."
if command -v gcloud &> /dev/null; then
    print_warning "gcloud is already installed: $(gcloud --version | head -n 1)"
else
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "Detected Linux, installing gcloud..."

        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            GCLOUD_ARCH="x86_64"
        elif [ "$ARCH" = "aarch64" ]; then
            GCLOUD_ARCH="arm"
        else
            GCLOUD_ARCH="x86_64"
        fi

        GCLOUD_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${GCLOUD_ARCH}.tar.gz"

        print_status "Downloading gcloud SDK from ${GCLOUD_URL}..."
        if curl -fsSL "${GCLOUD_URL}" -o /tmp/google-cloud-sdk.tar.gz 2>/dev/null; then
            $TAR -xzf /tmp/google-cloud-sdk.tar.gz -C "$SCRIPT_DIR/"
            "$SCRIPT_DIR/google-cloud-sdk/install.sh" --quiet --usage-reporting=false --path-update=false
            $RM /tmp/google-cloud-sdk.tar.gz
            print_status "✓ gcloud installed to $SCRIPT_DIR/google-cloud-sdk"
            gcloud --version
        else
            print_error "Failed to download gcloud SDK"
            print_warning "SSL certificate verification may have failed"
            print_warning "Options to fix:"
            echo "  Debian/Ubuntu:"
            echo "    sudo apt-get update && sudo apt-get install ca-certificates"
            echo "    sudo update-ca-certificates"
            echo "  RHEL/Fedora/CentOS:"
            echo "    sudo dnf install ca-certificates"
            echo "    sudo update-ca-trust"
            echo "  Or try: pip install --upgrade certifi"
            echo "  Manual download: https://cloud.google.com/sdk/docs/install"
            print_error "Skipping gcloud installation"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "Detected macOS, installing gcloud..."
        if command -v brew &> /dev/null; then
            brew install --cask google-cloud-sdk
            print_status "✓ gcloud installed via Homebrew"
        else
            print_warning "Homebrew not found. Install manually: https://cloud.google.com/sdk/docs/install"
        fi
    else
        print_warning "Unknown OS. Install gcloud manually: https://cloud.google.com/sdk/docs/install"
    fi
fi

# Install gh (GitHub CLI)
echo ""
print_status "Installing gh CLI..."
if command -v gh &> /dev/null; then
    print_warning "gh is already installed: $(gh --version | head -n 1)"
else
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "Detected Linux, installing gh to $SCRIPT_DIR/gh..."

        GH_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        GH_VERSION=${GH_VERSION#v}
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            GH_ARCH="amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            GH_ARCH="arm64"
        else
            print_error "Unsupported architecture: $ARCH"
            print_warning "Install gh manually: https://github.com/cli/cli#installation"
            GH_ARCH=""
        fi

        if [ -n "$GH_ARCH" ]; then
            curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" | $TAR -xz -C "$SCRIPT_DIR/"
            $MV "$SCRIPT_DIR/gh_${GH_VERSION}_linux_${GH_ARCH}" "$SCRIPT_DIR/gh"
            print_status "✓ gh installed to $SCRIPT_DIR/gh/bin/gh"
            gh --version
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "Detected macOS, installing gh..."
        if command -v brew &> /dev/null; then
            brew install gh
            print_status "✓ gh installed via Homebrew"
        else
            print_warning "Homebrew not found. Install manually: https://github.com/cli/cli#installation"
        fi
    else
        print_warning "Unknown OS. Install gh manually: https://github.com/cli/cli#installation"
    fi
fi

# Install npm (Node.js) if needed
echo ""
print_status "Checking for npm (Node.js)..."
if ! command -v npm &> /dev/null; then
    print_warning "npm not found, installing Node.js locally..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "Detected Linux, installing Node.js to $SCRIPT_DIR/node..."

        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            NODE_ARCH="x64"
        elif [ "$ARCH" = "aarch64" ]; then
            NODE_ARCH="arm64"
        else
            NODE_ARCH="x64"
        fi

        # Use latest LTS version
        NODE_VERSION="v20.11.1"
        NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"

        print_status "Downloading Node.js ${NODE_VERSION} from nodejs.org..."
        if curl -fsSL "${NODE_URL}" -o /tmp/node.tar.xz 2>/dev/null; then
            $TAR -xJf /tmp/node.tar.xz -C "$SCRIPT_DIR/"
            $MV "$SCRIPT_DIR/node-${NODE_VERSION}-linux-${NODE_ARCH}" "$SCRIPT_DIR/node"
            $RM /tmp/node.tar.xz

            # Add node/bin to PATH for this session
            export PATH="$SCRIPT_DIR/node/bin:$PATH"
            export PATH="/opt/app-root/src/node:$PATH"

            print_status "✓ Node.js installed to $SCRIPT_DIR/node"
            print_status "node version: $(node --version)"
            print_status "npm version: $(npm --version)"
        else
            print_error "Failed to download Node.js"
            print_warning "Install manually or use nvm:"
            echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
            echo "  nvm install node"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install node
            print_status "✓ Node.js installed via Homebrew"
        else
            print_warning "Homebrew not found. Install Node.js manually: https://nodejs.org/"
        fi
    fi
else
    print_status "npm found: $(npm --version)"
fi

# Install claude-code CLI
echo ""
print_status "Installing claude-code CLI..."
if command -v claude &> /dev/null; then
    print_warning "claude-code is already installed: $(claude --version 2>/dev/null || echo 'version unknown')"
else
    if command -v npm &> /dev/null; then
        print_status "Installing claude-code via npm..."
        if npm install -g @anthropic-ai/claude-code; then
            print_status "✓ claude-code installed via npm"
            # Set Vertex AI environment variables for this session
            export ANTHROPIC_VERTEX_PROJECT_ID=itpc-gcp-ai-eng-claude
            export CLAUDE_CODE_USE_VERTEX=1
            export CLOUD_ML_REGION=global
            export NODE_TLS_REJECT_UNAUTHORIZED=0
            print_status "Vertex AI configuration set for this session"
            claude --version
        else
            print_error "Failed to install claude-code via npm"
            print_warning "Try manual installation: npm install -g @anthropic-ai/claude-code"
        fi
    else
        print_error "npm not available - cannot install claude-code"
        print_warning "Install Node.js first, then run: npm install -g @anthropic-ai/claude-code"
    fi
fi

# ========================================
# Update ~/.bashrc Idempotently
# ========================================
echo ""
print_status "Updating ~/.bashrc with configuration..."

# Remove old configuration block if it exists
sed -i.bak '/# BEGIN code-server config/,/# END code-server config/d' ~/.bashrc 2>/dev/null || true

# Write new configuration block with expanded SCRIPT_DIR
cat >> ~/.bashrc << EOF_BASHRC
# BEGIN code-server config
export PATH="$PATH:\$PATH"
export ANTHROPIC_VERTEX_PROJECT_ID=itpc-gcp-ai-eng-claude
export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION=global
export NODE_TLS_REJECT_UNAUTHORIZED=0
# END code-server config
EOF_BASHRC

print_status "✓ ~/.bashrc updated (restart shell or run 'source ~/.bashrc' to apply)"

# ========================================
# Configure VS Code Settings for Claude Code
# ========================================
echo ""
print_status "Configuring VS Code settings for Claude Code..."

VSCODE_SETTINGS_DIR="$HOME/.local/share/code-server/User"
VSCODE_SETTINGS_FILE="$VSCODE_SETTINGS_DIR/settings.json"

# Create directory if it doesn't exist
mkdir -p "$VSCODE_SETTINGS_DIR"

# Check if settings.json exists
if [ -f "$VSCODE_SETTINGS_FILE" ]; then
    print_status "Updating existing settings.json..."

    # Backup existing settings
    cp "$VSCODE_SETTINGS_FILE" "$VSCODE_SETTINGS_FILE.bak"

    # Use Python to update JSON (handles JSONC format with comments)
    if command -v python3 &> /dev/null; then
        VSCODE_SETTINGS_FILE="$VSCODE_SETTINGS_FILE" PATH_VALUE="$PATH" python3 << 'PYTHON_EOF'
import json
import os
import sys
import re

settings_file = os.environ['VSCODE_SETTINGS_FILE']
path_value = os.environ['PATH_VALUE']

def strip_jsonc_comments(text):
    """Remove comments and trailing commas from JSONC (JSON with Comments)"""
    result = []
    in_string = False
    in_single_comment = False
    in_multi_comment = False
    escape_next = False
    i = 0

    while i < len(text):
        char = text[i]
        next_char = text[i + 1] if i + 1 < len(text) else ''

        # Handle string state
        if in_string:
            result.append(char)
            if escape_next:
                escape_next = False
            elif char == '\\':
                escape_next = True
            elif char == '"':
                in_string = False
            i += 1
            continue

        # Handle multi-line comment state
        if in_multi_comment:
            if char == '*' and next_char == '/':
                in_multi_comment = False
                i += 2
            else:
                i += 1
            continue

        # Handle single-line comment state
        if in_single_comment:
            if char == '\n':
                in_single_comment = False
                result.append(char)  # Keep the newline
            i += 1
            continue

        # Check for comment starts
        if char == '/' and next_char == '/':
            in_single_comment = True
            i += 2
            continue

        if char == '/' and next_char == '*':
            in_multi_comment = True
            i += 2
            continue

        # Check for string start
        if char == '"':
            in_string = True
            result.append(char)
            i += 1
            continue

        # Regular character
        result.append(char)
        i += 1

    # Join and remove trailing commas
    cleaned = ''.join(result)
    cleaned = re.sub(r',(\s*[}\]])', r'\1', cleaned)
    return cleaned

try:
    with open(settings_file, 'r') as f:
        content = f.read()

    # Try parsing as standard JSON first
    try:
        settings = json.loads(content)
    except json.JSONDecodeError:
        # If that fails, try stripping JSONC comments
        cleaned_content = strip_jsonc_comments(content)
        try:
            settings = json.loads(cleaned_content)
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON in {settings_file}: {e}", file=sys.stderr)
            print(f"Content preview: {cleaned_content[:200]}", file=sys.stderr)
            sys.exit(1)

except FileNotFoundError:
    settings = {}

# Build environment variables as a list of objects
env_vars = [
    {'name': 'PATH', 'value': path_value},
    {'name': 'CLAUDE_CODE_USE_VERTEX', 'value': "1"},
    {'name': 'CLOUD_ML_REGION', 'value': "global"},
    {'name': 'ANTHROPIC_VERTEX_PROJECT_ID', 'value': "itpc-gcp-ai-eng-claude"}
]

settings['claudeCode.environmentVariables'] = env_vars
settings['claudeCode.disableLoginPrompt'] = True

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("✓ Updated claudeCode settings using Python")
PYTHON_EOF
    else
        print_error "Python3 not available - cannot update settings.json"
        print_warning "Manually add to settings.json:"
        echo "  \"claudeCode.environmentVariables\": ["
        echo "    {\"name\": \"PATH\", \"value\": \"$PATH\"},"
        echo "    {\"name\": \"CLAUDE_CODE_USE_VERTEX\", \"value\": \"1\"},"
        echo "    {\"name\": \"CLOUD_ML_REGION\", \"value\": \"global\"},"
        echo "    {\"name\": \"ANTHROPIC_VERTEX_PROJECT_ID\", \"value\": \"itpc-gcp-ai-eng-claude\"}"
        echo "  ],"
        echo "  \"claudeCode.disableLoginPrompt\": true"
    fi
else
    print_status "Creating new settings.json..."

    # Create new settings.json with Claude Code configuration
    cat > "$VSCODE_SETTINGS_FILE" << EOF
{
  "claudeCode.environmentVariables": [
    {"name": "PATH", "value": "$PATH"},
    {"name": "CLAUDE_CODE_USE_VERTEX", "value": "1"},
    {"name": "CLOUD_ML_REGION", "value": "global"},
    {"name": "ANTHROPIC_VERTEX_PROJECT_ID", "value": "itpc-gcp-ai-eng-claude"}
  ],
  "claudeCode.disableLoginPrompt": true
}
EOF
    print_status "✓ Created settings.json with claudeCode configuration"
fi

# ========================================
# Summary
# ========================================
echo ""
echo "========================================"
print_status "Installation Summary"
echo "========================================"

echo ""
echo "VS Code Extensions:"
for ext in "${EXTENSIONS[@]}"; do
    if code-server --list-extensions | grep -qi "^${ext}$"; then
        echo -e "  ${GREEN}✓${NC} ${ext}"
    else
        echo -e "  ${RED}✗${NC} ${ext}"
    fi
done

echo ""
echo "CLI Tools:"
command -v gcloud &> /dev/null && echo -e "  ${GREEN}✓${NC} gcloud" || echo -e "  ${RED}✗${NC} gcloud"
command -v gh &> /dev/null && echo -e "  ${GREEN}✓${NC} gh" || echo -e "  ${RED}✗${NC} gh"
command -v claude &> /dev/null && echo -e "  ${GREEN}✓${NC} claude" || echo -e "  ${RED}✗${NC} claude"

echo ""
print_status "Initialization complete!"

# Check if local installations were done
LOCAL_INSTALL_DIRS=()
[ -d "$SCRIPT_DIR/bin" ] && [ -n "$(ls -A $SCRIPT_DIR/bin 2>/dev/null)" ] && LOCAL_INSTALL_DIRS+=("$SCRIPT_DIR/bin")
[ -d "$SCRIPT_DIR/gh/bin" ] && [ -n "$(ls -A $SCRIPT_DIR/gh/bin 2>/dev/null)" ] && LOCAL_INSTALL_DIRS+=("$SCRIPT_DIR/gh/bin")
[ -d "$SCRIPT_DIR/google-cloud-sdk/bin" ] && [ -n "$(ls -A $SCRIPT_DIR/google-cloud-sdk/bin 2>/dev/null)" ] && LOCAL_INSTALL_DIRS+=("$SCRIPT_DIR/google-cloud-sdk/bin")

if [ ${#LOCAL_INSTALL_DIRS[@]} -gt 0 ]; then
    echo ""
    print_warning "Tools were installed to local directories"
fi

echo "========================================"

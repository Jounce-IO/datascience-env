#!/bin/bash
set -e

# code-server-init.sh
# Initializes code-server with extensions and CLI tools for data science environment

# Ensure system directories are in PATH (critical for restricted environments)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
echo 'export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"' >> ~/.bashrc

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "export SCRIPT_DIR=$SCRIPT_DIR" >> ~/.bashrc

# Add local installation directories to PATH (relative to script location)
export PATH="$SCRIPT_DIR/bin:$SCRIPT_DIR/node/bin:$SCRIPT_DIR/gh/bin:$SCRIPT_DIR/google-cloud-sdk/bin:$PATH"
echo 'export PATH="'$SCRIPT_DIR'/bin:'$SCRIPT_DIR'/node/bin:/opt/app-root/src/node:node/bin:'$SCRIPT_DIR'/gh/bin:'$SCRIPT_DIR'/google-cloud-sdk/bin:$PATH"' >> ~/.bashrc


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
            echo 'export PATH="$SCRIPT_DIR/node/bin:$PATH"' >> ~/.bashrc
            export PATH="/opt/app-root/src/node:$PATH"
            echo 'export PATH="/opt/app-root/src/node:$PATH"' >> ~/.bashrc

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
            echo 'export ANTHROPIC_VERTEX_PROJECT_ID=itpc-gcp-ai-eng-claude' >> ~/.bashrc
            export CLAUDE_CODE_USE_VERTEX=1
            echo 'export CLAUDE_CODE_USE_VERTEX=1' >> ~/.bashrc
            export CLOUD_ML_REGION=global
            echo 'export CLOUD_ML_REGION=global' >> ~/.bashrc
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
echo "NODE_TLS_REJECT_UNAUTHORIZED=0" >> ~/.bashrc

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
exec bash

# Data Science Environment Setup

This directory contains initialization script for setting up a code-server (VS Code in the browser) environment optimized for data science workflows.

## code-server-init.sh

Automated setup script for code-server with pre-configured extensions and CLI tools.

### What It Installs

#### VS Code Extensions
- **marimo-team.vscode-marimo** - Marimo reactive notebook extension
- **anthropic.claude-code** - Claude Code AI assistant
- **mtxr.sqltools-driver-pg** - PostgreSQL driver for SQLTools

#### CLI Tools
- **npm (Node.js)** - JavaScript runtime (required for claude-code)
- **gcloud** - Google Cloud SDK for GCP interaction
- **gh** - GitHub CLI for repository management
- **claude-code** - Claude Code command-line interface (installed via npm)

### Usage

Open VS Code terminal
```bash
# Run the initialization script
curl -LsSf https://raw.githubusercontent.com/Jounce-IO/datascience-env/refs/heads/main/code-server-init.sh | sh
```

The script is idempotent - safe to run multiple times. It will skip already-installed components.

#### Post Installation

1. Authenticate CLI tools:
   ```bash
   gcloud auth application-default login
   gcloud auth application-default set-quota-project cloudability-it-gemini
   gh auth login
   ```

2. Open VS Code settings, search for “Claude Code login”, and check Disable Login Prompt.


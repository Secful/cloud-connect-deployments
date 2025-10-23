# Development Guide

## Coding Standards
- **Shell Script Standards**: Use `#!/bin/bash` shebang, enable strict mode with error handling
- **Naming Conventions**: kebab-case for script files, UPPER_CASE for constants, snake_case for variables  
- **Function Definitions**: Descriptive names with clear parameter documentation
- **Error Handling**: Comprehensive error checking with informative messages
- **Logging**: Structured logging with timestamp, level, and detailed context

## Technology Stack
- **Primary Language**: Bash shell scripting
- **Azure Integration**: Azure CLI (`az`) version 2.x+
- **JSON Processing**: `jq` for parsing and formatting JSON responses
- **HTTP Client**: `curl` for REST API communication
- **Utilities**: `uuidgen` for unique identifier generation, `parallel` for concurrent processing
- **Salt Security API**: v1/cloud-connect endpoints for deployment integration

## Code Structure
```
cloud-connect-deployments/
├── azure/
│   ├── subscription/
│   │   ├── deployment/           # Single subscription deployment
│   │   └── deletion/             # Single subscription cleanup
│   └── management-group/
│       ├── deployment/           # Multi-subscription deployment
│       └── deletion/             # Multi-subscription cleanup
├── aws/                         # Future AWS implementation
├── gcp/                         # Future GCP implementation
├── ai-docs/                     # AI agent documentation
└── tasks/                       # Development workspace
```

## Script Architecture Patterns
- **Parameter Validation**: Early validation of required parameters with usage help
- **Nonce Generation**: Unique 8-character identifiers for resource isolation
- **Logging System**: Dual output (console + file) with color-coded console messages
- **Azure CLI Integration**: Standardized error handling and JSON response parsing
- **Salt API Integration**: Structured status reporting with comprehensive error handling

## Testing
See [TESTING.md](TESTING.md) for manual test plans and validation procedures.

## Building
No compilation required - shell scripts execute directly:

```bash
# Make scripts executable
chmod +x azure/subscription/deployment/subscription-level-deployment.sh
chmod +x azure/management-group/deployment/management-group-level-deployment.sh

# Validate syntax
bash -n script-name.sh

# Test with dry-run parameters (if supported)
./script-name.sh --help
```

## Development Environment Setup
```bash
# Install required dependencies
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# jq JSON processor  
sudo apt-get install jq

# curl HTTP client (usually pre-installed)
sudo apt-get install curl

# parallel utility (for management group deployments)
sudo apt-get install parallel
```

## Code Quality Standards
- **Shell Check**: Use shellcheck for static analysis
- **Error Handling**: Always check command exit codes
- **Quoting**: Proper variable quoting to prevent word splitting
- **Function Design**: Single responsibility with clear input/output
- **Documentation**: Inline comments for complex logic, comprehensive usage messages
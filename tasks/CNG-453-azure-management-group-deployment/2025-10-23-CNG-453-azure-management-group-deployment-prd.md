# Azure Management Group Deployment - Product Requirements Document

## Introduction/Overview
This feature enables Salt Security customers to deploy cloud connectivity scanning
capabilities at the Azure management group level through automated shell script
deployment. The solution provides service principal authentication setup across
multiple management groups and their child subscriptions, enabling comprehensive
API Management (APIM) instance and Azure Kubernetes Service (AKS) cluster
discovery and scanning. This addresses the critical need for enterprise customers
to efficiently onboard large Azure environments without manual per-subscription
configuration.

## Objectives & Success Metrics

**Business Objectives:**
- Reduce enterprise customer onboarding time from days to hours for complex Azure
  environments
- Eliminate manual configuration errors in multi-subscription Azure deployments
- Provide scalable deployment automation for management group hierarchies
- Enable comprehensive cloud asset discovery across enterprise Azure footprints

**Success Metrics:**
- **Deployment Success Rate**: 100% successful deployments across all management
  groups and child subscriptions
- **Time Reduction**: 80% reduction in deployment time compared to manual
  per-subscription setup
- **Error Reduction**: 90% reduction in configuration errors versus manual setup
- **Customer Satisfaction**: Improved onboarding experience for enterprise
  customers with complex Azure structures

## Use Cases

### User Stories
- As a Salt customer managing multiple Azure management groups and subscriptions, I want to deploy Salt Security scanning
  across all management groups so that I can enable comprehensive API and
  container security monitoring without per-subscription manual setup
- As a Salt Security support engineer:
  - I want detailed deployment status and audit logs so that I can quickly troubleshoot any deployment issues.
  - I want automated cleanup on deployment failure so that failed deployments don't leave orphaned Azure resources

### Use Cases
1. **Multi-Management Group Enterprise Deployment**: Deploy service principal with Azure RBAC permissions across
   multiple management groups with multiple child subscriptions.
2. **Single Deployment Across Multiple Management Groups**: Deploy service principal with RBAC permissions to all specified management groups simultaneously in a single script execution
3. **Deployment Troubleshooting**: Use comprehensive logs and status reporting to diagnose and resolve deployment issues
4. **Resource Cleanup**: Automatically clean up Azure resources when deployments fail or are interrupted
5. **Interrupt Recovery**: Handle script interruption (Ctrl+C) during deployment with automatic cleanup prompt to remove partially created resources
6. **Manual Resource Deletion**: Use dedicated deletion script to remove previously created Azure resources from specified management groups

## Feature Scope

### In Scope
- Management group level deployment automation via shell scripts running on customer's Azure Cloud Shell
- Azure AD application registration, service principal creation, and custom role creation with assignment at management group(s) scope,
  leveraging RBAC inheritance feature in Azure.
- Comprehensive status reporting per subscription under management groups
- Audit log generation with Salt Security platform integration, with logs sent to Salt's premises (cloud environment)
- Automatic resource cleanup on deployment failure or interruption
- Input validation for management group IDs and deployment parameters
- Integration with Salt Security backend API for credential exchange
- Dedicated deletion script for cleanup of Azure resources previously created by Salt's deployment script.

### Out of Scope
- ARM template deployment approach (superseded by shell script solution)
- Tenant-level deployment permissions (uses management group scope instead)
- Real-time UI progress bars (status updates via API integration)
- Custom dashboard for deployment monitoring (uses existing Salt Security UI)


## Functional Requirements

### Detailed Requirements
1. **Minimal Permission Requirements**: The system must define and document the minimal Azure permissions required for customers to run both deployment and deletion scripts, following the least-privileges principle. Each script (deployment vs deletion) may require different minimal permission sets.
2. **Input Parameter Validation**: The system must validate all input parameters including management group IDs format, Salt host URLs, authentication tokens, and other script parameters. The system must verify user access permissions before proceeding with deployment
3. **Service Principal Creation**: The system must create Azure AD application,
   client secret, and service principal with unique nonce-based naming to
   prevent resource conflicts
4. **Custom Role Management**: The system must create custom role with
   read-only permissions for API Management, Kubernetes, and Resource Groups
   with management group scope assignment
5. **RBAC Inheritance Deployment**: The system must leverage Azure's RBAC inheritance feature to deploy permissions at management group level, automatically inheriting to all child subscriptions with individual status tracking
6. **Status Reporting**: The system must send deployment status updates to
   Salt Security backend API for each subscription under management groups
7. **Audit Logging**: The system must generate comprehensive audit logs
   (matching AWS connector audit event format and structure)
8. **Error Recovery**: The system must provide automatic cleanup of partially
   created resources on deployment failure with user confirmation
9. **Role Inheritance Verification**: The system must verify that management
   group role assignments properly inherit to all child subscriptions
10. **Script Interrupt Handling**: The system must handle script interruptions (Ctrl+C, SIGINT) gracefully by prompting the user for cleanup confirmation and performing rollback of partially created resources
11. **Dedicated Deletion Script**: The system must provide a separate deletion script that can identify and remove previously created Azure resources (applications, service principals, custom roles, role assignments) across specified management groups

## Non-Functional Requirements

### Performance
- **Response Time**: Deployment completion within 15 minutes for management
  groups with up to 100 child subscriptions
- **Throughput**: Support concurrent deployment across up to 10 management
  groups simultaneously

### Security
- **Authentication**: Azure CLI session-based authentication with minimal Azure permissions required (to be defined following least-privileges principle)
- **Authorization**: Read-only Azure permissions with least-privilege custom
  role creation
- **Data Protection**: Secure transmission of credentials to Salt Security
  backend via HTTPS with bearer token authentication

### Usability
- **User Experience**: Clear command-line interface with comprehensive help
  documentation and parameter validation
- **Accessibility**: Full keyboard accessibility through command-line interface

### Reliability
- **Uptime**: Deployment success rate >95% across different Azure environments
- **Error Handling**: Comprehensive error messages with clear remediation steps
  for common deployment issues

### Architecture
- **Design Pattern**: System must follow **Clean Architecture** principles
  with clear separation of deployment logic, Azure integration, and Salt
  Security API communication
- **Layer Separation**: Distinct separation between deployment orchestration,
  Azure resource management, and external API integration
- **Dependency Inversion**: Dependencies flow inward toward deployment core
  logic with external services abstracted through interfaces

## Dependencies & Risks

### Dependencies
- **Internal Dependencies**: Salt Security backend API v1/cloud-connect
  endpoints for status reporting and credential exchange
- **External Dependencies**: Azure CLI, jq (JSON processing), curl (HTTP
  client), uuidgen (unique identifier generation), bash shell environment

### Risks
- **Role Assignment Propagation Delays**: Azure role assignments can take
  several minutes to propagate to child subscriptions - *Mitigation*:
  Implement verification retry logic with extended timeout periods
- **Management Group Permission Requirements**: Customers may lack required
  Owner/User Access Administrator roles - *Mitigation*: Provide clear
  documentation of required permissions with validation checks
- **Network Connectivity**: Deployment failures due to network issues with
  Salt Security backend API - *Mitigation*: Continue deployment on API
  failures, log warnings, provide manual status update procedures

## Open Questions
- Should the deployment support custom role permission modification for
  customers with specific security requirements?
- How should the system handle Azure AD application limits in large
  organizations with many existing applications?
- Should there be integration with Azure Resource Manager deployment history
  for better tracking and rollback capabilities?
- What is the preferred approach for handling Azure CLI authentication token
  refresh during long-running deployments?
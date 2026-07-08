# Score Workload Module - AWS ECS Fargate Deployment

Terraform module for deploying containerized Score workloads to AWS ECS Fargate. This module handles ECS Fargate and ECS Task provisioning, IAM permissions, and container runtime configuration.

## Overview

This module encapsulates the deployment of a single containerized workload to AWS ECS. It is designed to work within a Score and Humanitec Platform Orchestrator ecosystem where:

- **Score defines** the container image, command, environment variables, and required resources
- **This module provisions** the ECS Task and related AWS infrastructure
- **Other modules** provision additional resources (databases, storage, etc.) referenced by the container

The module focuses exclusively on the compute layer (`score-workload` resource type), while other resources (postgres, s3, etc.) are provisioned by dedicated modules.

## Technical References

### Humanitec Documentation
- [Score Overview](https://developer.humanitec.com/platform-orchestrator/docs/score/overview/) - Score file structure and workload definition
- [Custom Resource Types](https://developer.humanitec.com/platform-orchestrator/docs/platform-orchestrator/resources/custom-resource-types/) - Extending and configuring resource types
- [Resource Definitions](https://developer.humanitec.com/platform-orchestrator/docs/platform-orchestrator/resources/resource-definitions/) - Mapping resources to drivers/modules

### Terraform Documentation
- [IAM Role & Policy Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)
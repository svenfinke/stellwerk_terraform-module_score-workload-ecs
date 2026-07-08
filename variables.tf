# ---------------------------------------------------------------------------
# Humanitec context
# ---------------------------------------------------------------------------

variable "res_id" {
  description = "Humanitec resource ID. Used for unique resource naming."
  type        = string
}

variable "app_id" {
  description = "Humanitec application ID. Used for resource naming and tagging."
  type        = string
}

variable "env_id" {
  description = "Humanitec environment ID. Used for resource naming and tagging."
  type        = string
}

# ---------------------------------------------------------------------------
# Score workload specification
# ---------------------------------------------------------------------------

variable "containers" {
  description = <<-EOT
    Map of containers to deploy, as defined in the Score workload spec.
    Keys are container names; values are container configuration objects.

    The first container in iteration order is treated as the primary container
    and is wired to the ALB target group.
  EOT
  type = map(object({
    image   = string
    command = optional(list(string), [])
    args    = optional(list(string), [])
    env     = optional(map(string), {})
    resources = optional(object({
      limits = optional(object({
        cpu    = optional(string, "256")
        memory = optional(string, "512")
      }), {})
    }), {})
    ports = optional(map(object({
      port     = number
      protocol = optional(string, "TCP")
    })), {})
  }))
}

# ---------------------------------------------------------------------------
# Infrastructure references
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the existing ECS cluster to deploy the service into."
  type        = string
}

variable "lb_listener_arn" {
  description = "ARN of the existing ALB listener to attach a forwarding rule to."
  type        = string
}

# ---------------------------------------------------------------------------
# Service configuration
# ---------------------------------------------------------------------------

variable "service_port" {
  description = "Container port that the ALB routes traffic to (primary container)."
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Number of ECS task instances to run."
  type        = number
  default     = 1
}

variable "subnet_tier" {
  description = "Value of the 'Tier' tag used to filter subnets within the orch-aws-vpc VPC."
  type        = string
  default     = "private"
}

variable "service" {
  description = "Service name"
  type        = string
}

variable "metadata" {
  description = "Metadata for the workload, including optional spring_profiles_active."
  type = object
  default = {}
}
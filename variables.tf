#-----------------------------------------------------------------------------------------------------------------------
# Variables
#-----------------------------------------------------------------------------------------------------------------------

variable "create" {
  description = "Controls if resources should be created (affects nearly all resources)"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name to be used on all resources as prefix"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the Client VPN endpoint"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

#-----------------------------------------------------------------------------------------------------------------------
# VPN Client Endpoint
#-----------------------------------------------------------------------------------------------------------------------

variable "client_cidr" {
  description = "Network CIDR to use for clients"
  type        = string
}

variable "server_certificate_arn" {
  description = "The ARN of the ACM server certificate"
  type        = string
}

variable "vpc_id" {
  description = "ID of VPC to attach VPN to"
  type        = string
}

variable "associated_subnets" {
  description = "List of subnets to associate with the VPN endpoint"
  type        = list(string)
}

variable "saml_provider_arn" {
  description = "The ARN of the IAM SAML identity provider for federated authentication"
  type        = string
  validation {
    error_message = "Invalid SAML provider ARN."
    condition = can(regex(
      "^arn:[^:]+:iam::\\d{12}:saml-provider/[\\w+=,.@-]+$",
      var.saml_provider_arn
    ))
  }
}

variable "self_service_portal_enabled" {
  description = "Specify whether to enable the self-service portal for the Client VPN endpoint"
  type        = bool
  default     = false
}

variable "self_service_saml_provider_arn" {
  description = "The ARN of the IAM SAML identity provider for the self service portal. Required when self_service_portal_enabled is true"
  type        = string
  default     = null
}

variable "session_timeout_hours" {
  description = "The maximum session duration. Valid values: 8, 10, 12, 24"
  type        = number
  default     = 8
  validation {
    condition     = contains([8, 10, 12, 24], var.session_timeout_hours)
    error_message = "The maximum session duration must be one of: 8, 10, 12, 24."
  }
}

variable "transport_protocol" {
  description = "Transport protocol used by the TLS sessions. Valid values: udp, tcp"
  type        = string
  default     = "udp"
  validation {
    condition     = contains(["udp", "tcp"], var.transport_protocol)
    error_message = "Invalid protocol type must be one of: udp, tcp."
  }
}

variable "split_tunnel" {
  description = "Indicates whether split-tunnel is enabled on VPN endpoint"
  type        = bool
  default     = false
}

variable "dns_servers" {
  description = "Information about the DNS servers to be used for DNS resolution. A Client VPN endpoint can have up to two DNS servers"
  type        = list(string)
  default     = []
  validation {
    condition = can(
      [
        for server_ip in var.dns_servers : regex(
        "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
        server_ip
      )
      ]
    )
    error_message = "IPv4 addresses must match the appropriate format xxx.xxx.xxx.xxx."
  }
}

variable "vpn_port" {
  description = "The port number for the Client VPN endpoint. Valid values: 443, 1194"
  type        = number
  default     = 443
  validation {
    condition     = contains([443, 1194], var.vpn_port)
    error_message = "VPN port must be either 443 or 1194."
  }
}

variable "banner_text" {
  description = "Customizable text that will be displayed in a banner on AWS provided clients when a VPN session is established"
  type        = string
  default     = null
}

variable "authorization_rules" {
  description = "List of objects describing the authorization rules for the client VPN"
  type = list(object({
    name                 = optional(string)
    access_group_id      = optional(string)
    authorize_all_groups = optional(bool)
    description          = optional(string)
    target_network_cidr  = string
  }))
  default = []
}

variable "additional_routes" {
  description = "A list of additional routes that should be attached to the Client VPN endpoint"
  type = list(object({
    destination_cidr_block = string
    description            = optional(string)
    target_vpc_subnet_id   = string
    name                   = optional(string)
  }))
  default = []
}

#-----------------------------------------------------------------------------------------------------------------------
# Security Group
#-----------------------------------------------------------------------------------------------------------------------

variable "security_group_ids" {
  description = "List of additional VPC security groups to associate"
  type        = list(string)
  default     = []
}

variable "create_security_group" {
  description = "Determines if a security group is created"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Name to use on security group created. If not specified, uses the value from `name`"
  type        = string
  default     = null
}

variable "security_group_use_name_prefix" {
  description = "Determines whether the security group name is used as a prefix"
  type        = bool
  default     = true
}

variable "security_group_description" {
  description = "Description of the security group created"
  type        = string
  default     = null
}

variable "security_group_ingress_rules" {
  description = "Security group ingress rules to add to the security group created"
  type = map(object({
    name                         = optional(string)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(number)
    ip_protocol                  = optional(string, "tcp")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    tags                         = optional(map(string), {})
    to_port                      = optional(number)
  }))
  default = {}
}

variable "security_group_egress_rules" {
  description = "Security group egress rules to add to the security group created"
  type = map(object({
    name                         = optional(string)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(number)
    ip_protocol                  = optional(string, "tcp")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    tags                         = optional(map(string), {})
    to_port                      = optional(number)
  }))
  default = {}
}

variable "security_group_tags" {
  description = "A map of additional tags to add to the security group created"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------------------------------------------------
# CloudWatch Logging
# ----------------------------------------------------------------------------------------------------------------------

variable "logging_enabled" {
  description = "Enables or disables Client VPN CloudWatch logging"
  type        = bool
  default     = false
}

variable "create_cloudwatch_log_group" {
  description = "Whether to create CloudWatch log group for connection logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_name" {
  description = "Name of CloudWatch Log Group to use for connection logs. If not specified, a default name will be generated"
  type        = string
  default     = null
}

variable "cloudwatch_log_stream_name" {
  description = "Name of CloudWatch Log Stream for connection logs"
  type        = string
  default     = "connection-log"
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "The ARN of the KMS Key to use when encrypting log data"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_tags" {
  description = "A map of additional tags to add to CloudWatch log group"
  type        = map(string)
  default     = {}
}

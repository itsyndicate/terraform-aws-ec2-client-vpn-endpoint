locals {
  create = var.create
}

#-----------------------------------------------------------------------------------------------------------------------
# Security Group
#-----------------------------------------------------------------------------------------------------------------------

locals {
  create_security_group = local.create && var.create_security_group
  security_group_name   = try(coalesce(var.security_group_name, var.name), "")
  security_group_description = coalesce(
    var.security_group_description,
    "Security group for VPN Client Endpoint ${var.name}"
  )
}

resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name        = var.security_group_use_name_prefix ? null : local.security_group_name
  name_prefix = var.security_group_use_name_prefix ? "${local.security_group_name}-" : null
  description = local.security_group_description
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    var.security_group_tags,
    { "Name" = local.security_group_name }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for k, v in var.security_group_ingress_rules : k => v if local.create_security_group }

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = aws_security_group.this[0].id
  to_port                      = try(coalesce(each.value.to_port, each.value.from_port), null)

  tags = merge(
    var.tags,
    var.security_group_tags,
    { "Name" = coalesce(each.value.name, "${local.security_group_name}-${each.key}") },
    each.value.tags
  )
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for k, v in var.security_group_egress_rules : k => v if local.create_security_group }

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  description                  = each.value.description
  from_port                    = try(coalesce(each.value.from_port, each.value.to_port), null)
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = aws_security_group.this[0].id
  to_port                      = each.value.to_port

  tags = merge(
    var.tags,
    var.security_group_tags,
    { "Name" = coalesce(each.value.name, "${local.security_group_name}-${each.key}") },
    each.value.tags
  )
}

#-----------------------------------------------------------------------------------------------------------------------
# CloudWatch Log Group
#-----------------------------------------------------------------------------------------------------------------------

locals {
  create_cloudwatch_log_group = local.create && var.logging_enabled && var.create_cloudwatch_log_group
  cloudwatch_log_group_name   = try(coalesce(var.cloudwatch_log_group_name, "/aws/vpn/${var.name}"), "/aws/vpn/default")
}

resource "aws_cloudwatch_log_group" "this" {
  count = local.create_cloudwatch_log_group ? 1 : 0

  name              = local.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = merge(
    var.tags,
    var.cloudwatch_log_group_tags,
    { "Name" = local.cloudwatch_log_group_name }
  )
}

resource "aws_cloudwatch_log_stream" "this" {
  count = local.create_cloudwatch_log_group ? 1 : 0

  name           = var.cloudwatch_log_stream_name
  log_group_name = aws_cloudwatch_log_group.this[0].name
}

#-----------------------------------------------------------------------------------------------------------------------
# VPN Client Endpoint
#-----------------------------------------------------------------------------------------------------------------------

locals {
  self_service_portal_enabled = local.create && var.self_service_portal_enabled
  logging_enabled             = local.create && var.logging_enabled

  cloudwatch_log_group = local.logging_enabled ? (
    local.create_cloudwatch_log_group ? aws_cloudwatch_log_group.this[0].name : var.cloudwatch_log_group_name
  ) : null
  cloudwatch_log_stream = local.logging_enabled ? (
    local.create_cloudwatch_log_group ? aws_cloudwatch_log_stream.this[0].name : var.cloudwatch_log_stream_name
  ) : null

  security_group_ids = compact(concat(
    aws_security_group.this[*].id,
    var.security_group_ids
  ))
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  count = local.create ? 1 : 0

  description            = coalesce(var.description, "Client VPN endpoint for ${var.name}")
  client_cidr_block      = var.client_cidr
  server_certificate_arn = var.server_certificate_arn
  transport_protocol     = var.transport_protocol
  vpc_id                 = var.vpc_id
  security_group_ids     = local.security_group_ids
  self_service_portal    = local.self_service_portal_enabled ? "enabled" : "disabled"
  session_timeout_hours  = var.session_timeout_hours
  split_tunnel           = var.split_tunnel
  dns_servers            = length(var.dns_servers) > 0 ? var.dns_servers : null
  vpn_port               = var.vpn_port

  authentication_options {
    type                           = "federated-authentication"
    saml_provider_arn              = var.saml_provider_arn
    self_service_saml_provider_arn = local.self_service_portal_enabled ? var.self_service_saml_provider_arn : null
  }

  connection_log_options {
    enabled               = var.logging_enabled
    cloudwatch_log_group  = local.cloudwatch_log_group
    cloudwatch_log_stream = local.cloudwatch_log_stream
  }

  dynamic "client_login_banner_options" {
    for_each = var.banner_text != null ? [1] : []

    content {
      enabled     = true
      banner_text = var.banner_text
    }
  }

  tags = merge(
    var.tags,
    { "Name" = var.name }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ec2_client_vpn_network_association" "this" {
  for_each = { for idx, subnet_id in var.associated_subnets : idx => subnet_id if local.create }

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  subnet_id              = each.value

  lifecycle {
    # The issue why we are ignoring changes is that on every apply
    # terraform screws up the description due to a bug in the AWS APIs.
    ignore_changes = [subnet_id]
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }
}

resource "aws_ec2_client_vpn_authorization_rule" "this" {
  for_each = { for idx, rule in var.authorization_rules : coalesce(rule.name, tostring(idx)) => rule if local.create }

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  target_network_cidr    = each.value.target_network_cidr
  description            = try(each.value.description, null)


  #access_group_id      = null
  #authorize_all_groups = true
  #
  #access_group_id      = "1111a1a1-a111-1111-a1aa-1aa11a1a11aa"
  #authorize_all_groups = null
  access_group_id      = try(each.value.authorize_all_groups, false) ? null : try(each.value.access_group_id, null)
  authorize_all_groups = try(each.value.authorize_all_groups, false) ? true : null
}

resource "aws_ec2_client_vpn_route" "this" {
  for_each = { for idx, route in var.additional_routes : coalesce(route.name, tostring(idx)) => route if local.create }

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  destination_cidr_block = each.value.destination_cidr_block
  target_vpc_subnet_id   = each.value.target_vpc_subnet_id
  description            = try(each.value.description, null)

  depends_on = [
    aws_ec2_client_vpn_network_association.this
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

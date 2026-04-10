# ----------------------------------------------------------------------------------------------------------------------
# Terraform Module Source
# ----------------------------------------------------------------------------------------------------------------------
terraform {
  source = "${dirname(find_in_parent_folders("root.terragrunt.hcl"))}/_catalog/modules//vpn-client-endpoint"
}

# ----------------------------------------------------------------------------------------------------------------------
# Local Variables
# ----------------------------------------------------------------------------------------------------------------------
locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  env    = local.environment_vars.locals.environment.short
  prefix = "${local.environment_vars.locals.prefix}-${local.region_vars.locals.aws_region_short}"
  region = local.region_vars.locals.aws_region
}

# ----------------------------------------------------------------------------------------------------------------------
# Dependencies
# ----------------------------------------------------------------------------------------------------------------------
dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../vpc"

  mock_outputs = {
    vpc_id = "vpc-11111aa1a111c1a11"
  }
}

dependency "data" {
  config_path = "${get_terragrunt_dir()}/../data"
}

dependency "acm" {
  config_path = "${get_terragrunt_dir()}/../../global/acm/some.domain.com/"
}

# ----------------------------------------------------------------------------------------------------------------------
# Module Input Variables
# ----------------------------------------------------------------------------------------------------------------------
inputs = {
  name = "${local.prefix}-vpn-endpoint"

  logging_enabled = true

  vpc_id             = dependency.vpc.outputs.vpc_id
  associated_subnets = [dependency.vpc.outputs.private_subnets[0]]
  client_cidr        = "172.16.0.0/22"
  dns_servers = ["10.30.0.2"]
  transport_protocol = "udp"
  split_tunnel       = true
  vpn_port           = 443

  server_certificate_arn = dependency.acm.outputs.acm_certificate_arn

  saml_provider_arn              = "arn:aws:iam::${dependency.data.outputs.account_id}:saml-provider/aws-rk-vpn-client"
  self_service_portal_enabled    = true
  self_service_saml_provider_arn = "arn:aws:iam::${dependency.data.outputs.account_id}:saml-provider/aws-rk-vpn-self-service"

  authorization_rules = [
    {
      target_network_cidr  = "10.30.0.0/16"
      description          = "Allow everyone to access to connectivity VPC"
      authorize_all_groups = true
    },
    {
      target_network_cidr  = "10.10.0.0/16"
      description          = "Allow dev group to access dev VPC"
      authorize_all_groups = false
      access_group_id      = "1111a1a1-aaaa-1111-aaaa-111111111111"
    },
    {
      target_network_cidr  = "10.20.0.0/16"
      description          = "Allow prod group to access prod VPC"
      authorize_all_groups = false
      access_group_id      = "2b222b22-bbbb-bbbb-2222-bbbbbbbbbbb"
    }
  ]
  additional_routes = [
    {
      description            = "Route to dev VPC"
      destination_cidr_block = "10.10.0.0/16"
      target_vpc_subnet_id   = dependency.vpc.outputs.private_subnets[0]
    },
    {
      description            = "Route to prod VPC"
      destination_cidr_block = "10.20.0.0/16"
      target_vpc_subnet_id   = dependency.vpc.outputs.private_subnets[0]
    }
  ]

  security_group_ingress_rules = {
    all_traffic = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
      description = "Allow all inbound traffic"
    }
  }
  security_group_egress_rules = {
    all_traffic = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
      description = "Allow all outbound traffic"
    }
  }
}

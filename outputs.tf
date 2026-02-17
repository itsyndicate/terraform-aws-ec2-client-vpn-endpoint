#-----------------------------------------------------------------------------------------------------------------------
# Outputs
#-----------------------------------------------------------------------------------------------------------------------

output "id" {
  description = "The ID of the Client VPN endpoint"
  value       = try(aws_ec2_client_vpn_endpoint.this[0].id, null)
}

output "arn" {
  description = "The ARN of the Client VPN endpoint"
  value       = try(aws_ec2_client_vpn_endpoint.this[0].arn, null)
}

output "dns_name" {
  description = "The DNS name to be used by clients when establishing their VPN session"
  value       = try(aws_ec2_client_vpn_endpoint.this[0].dns_name, null)
}

#-----------------------------------------------------------------------------------------------------------------------
# Security Group
#-----------------------------------------------------------------------------------------------------------------------

output "security_group_id" {
  description = "The ID of the security group"
  value       = try(aws_security_group.this[0].id, null)
}

output "security_group_arn" {
  description = "The ARN of the security group"
  value       = try(aws_security_group.this[0].arn, null)
}

#-----------------------------------------------------------------------------------------------------------------------
# CloudWatch Log Group
#-----------------------------------------------------------------------------------------------------------------------

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log Group"
  value       = try(aws_cloudwatch_log_group.this[0].name, null)
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group"
  value       = try(aws_cloudwatch_log_group.this[0].arn, null)
}

output "cloudwatch_log_stream_name" {
  description = "The name of the CloudWatch Log Stream"
  value       = try(aws_cloudwatch_log_stream.this[0].name, null)
}

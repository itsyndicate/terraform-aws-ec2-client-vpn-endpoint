# 🔒 AWS Client VPN Endpoint Module 🔒

* All usage examples are in the root `examples` folder. ***Keep in mind they show implementation with `Terragrunt`.***
* This module can provision the following resources:
    * `Client VPN Endpoint` (with federated SAML authentication);
    * `Network Associations` (subnets attached to the VPN endpoint);
    * `Authorization Rules` (access control per CIDR and group);
    * `Additional Routes` (routes to other VPCs via peering);
    * `Security Group` (with configurable ingress/egress rules);
    * `CloudWatch Log Group & Log Stream` (for connection logging);

# 🛩️ Useful information 🛩️

* This module **only supports federated authentication (SAML)**. Certificate-based authentication is not supported. You will need an IAM SAML Identity Provider and an ACM server certificate.
* A **local route** for the VPC where the endpoint lives is created automatically by AWS — do **not** include it in `additional_routes`, otherwise the apply will fail with `InvalidClientVpnDuplicateRoute`.
* Changing `description` on `authorization_rules` forces a **destroy and recreate** of that rule — this is an AWS API limitation. Expect ~1 second of access loss for active sessions on that rule.
* The module creates a **Security Group** by default. You can disable this with `create_security_group = false` and pass your own group via `security_group_ids`.

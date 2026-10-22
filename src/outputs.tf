output "zones" {
  value       = aws_route53_zone.root
  description = "DNS zones"
}

output "acms" {
  value       = { for k, v in module.acm : k => v.arn }
  description = "ACM certificates for domains"
}

output "delegation_set_id" {
  value       = local.delegation_set_id
  description = "The reusable delegation set id in use: the value passed via `delegation_set_id`, the one created when `create_delegation_set` is true, or null when neither is used."
}

output "delegation_set_name_servers" {
  # Each splat is a list of 0-or-1 name_servers lists (count-gated); flatten
  # yields the active set's four name servers, or [] when no delegation set is
  # in use. (coalescelist fails on all-empty; flatten+concat does not.)
  value = flatten(concat(
    aws_route53_delegation_set.default[*].name_servers,
    data.aws_route53_delegation_set.default[*].name_servers,
  ))
  description = "The four name servers of the delegation set in use (created or looked-up), to set at the registrar for the apex domain. Empty when no delegation set is used."
}

locals {
  domains_set    = module.this.enabled ? toset(var.domain_names) : []
  zone_recs_map  = module.this.enabled ? { for zone in var.record_config : "${zone.name}${zone.root_zone}.${zone.type}" => zone } : {}
  zone_alias_map = module.this.enabled ? { for zone in var.alias_record_config : "${zone.name}${zone.root_zone}.${zone.type}" => zone } : {}

  # Reusable delegation set support. Three mutually-exclusive states:
  #   - var.delegation_set_id set        -> attach every zone to that existing set
  #   - var.create_delegation_set = true -> create a reusable set, attach zones to it
  #   - neither (default)                -> upstream behavior: no delegation set
  create_delegation_set = module.this.enabled && var.delegation_set_id == null && var.create_delegation_set
  # Resolved id: the passed-in id, else the created one, else null (upstream default).
  delegation_set_id = var.delegation_set_id != null ? var.delegation_set_id : one(aws_route53_delegation_set.default[*].id)
}

# When an id is passed, look it up so a bad id fails loudly at plan time rather
# than silently attaching zones to a non-existent delegation set.
data "aws_route53_delegation_set" "default" {
  count = module.this.enabled && var.delegation_set_id != null ? 1 : 0

  id = var.delegation_set_id
}

# When create_delegation_set is true, create a reusable delegation set so a set
# of zones (e.g. an apex and its subdomains) can share one fixed name-server set.
resource "aws_route53_delegation_set" "default" {
  count = local.create_delegation_set ? 1 : 0

  reference_name = var.delegation_set_reference_name

  # reference_name maps to the delegation set's CallerReference, which AWS makes
  # immutable and never returns verbatim: on create the provider appends a
  # "-terraform-<random>" suffix. So an imported set's CallerReference can never
  # match the configured reference_name, which would otherwise force a
  # destroy+recreate of a live zone's NS authority on every adoption. The field
  # is write-once and cosmetic after creation, so ignore changes to it.
  lifecycle {
    ignore_changes = [reference_name]
  }
}

resource "aws_route53_zone" "root" {
  for_each = local.domains_set

  name              = each.value
  comment           = "DNS zone for the ${each.value} root domain"
  delegation_set_id = local.delegation_set_id
  tags              = module.this.tags
}

resource "aws_route53_record" "soa" {
  for_each = aws_route53_zone.root

  allow_overwrite = true
  zone_id         = aws_route53_zone.root[each.key].zone_id
  name            = aws_route53_zone.root[each.key].name
  type            = "SOA"
  ttl             = "60"

  records = [
    "${aws_route53_zone.root[each.key].name_servers[0]}. ${var.dns_soa_config}"
  ]
}

resource "aws_route53_record" "dnsrec" {
  for_each = local.zone_recs_map

  name    = format("%s%s", each.value.name, each.value.root_zone)
  type    = each.value.type
  zone_id = aws_route53_zone.root[each.value.root_zone].zone_id
  ttl     = each.value.ttl

  records = each.value.records
}

resource "aws_route53_record" "aliasrec" {
  for_each = local.zone_alias_map

  name    = format("%s%s", each.value.name, each.value.root_zone)
  type    = each.value.type
  zone_id = aws_route53_zone.root[each.value.root_zone].zone_id

  alias {
    name                   = each.value.record
    zone_id                = each.value.zone_id
    evaluate_target_health = each.value.evaluate_target_health
  }
}

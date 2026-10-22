variable "region" {
  type        = string
  description = "AWS Region"
}

variable "domain_names" {
  type        = list(string)
  default     = null
  description = "Root domain name list, e.g. `[\"example.net\"]`"
}

variable "record_config" {
  description = "DNS Record config"
  type = list(object({
    root_zone = string
    name      = string
    type      = string
    ttl       = string
    records   = list(string)
  }))
  default = []
}

# Elastic Load Balancing Hosted Zone IDs can be found here: https://docs.aws.amazon.com/general/latest/gr/elb.html
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record#alias-record
variable "alias_record_config" {
  description = "DNS Alias Record config"
  type = list(object({
    root_zone              = string
    name                   = string
    type                   = string
    zone_id                = string
    record                 = string
    evaluate_target_health = bool
  }))
  default = []
}

variable "dns_soa_config" {
  type        = string
  description = <<-EOT
    Root domain name DNS SOA record:
    - awsdns-hostmaster.amazon.com. ; AWS default value for administrator email address
    - 1 ; serial number, not used by AWS
    - 7200 ; refresh time in seconds for secondary DNS servers to refresh SOA record
    - 900 ; retry time in seconds for secondary DNS servers to retry failed SOA record update
    - 1209600 ; expire time in seconds (1209600 is 2 weeks) for secondary DNS servers to remove SOA record if they cannot refresh it
    - 60 ; nxdomain TTL, or time in seconds for secondary DNS servers to cache negative responses
    See [SOA Record Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/SOA-NSrecords.html) for more information.
  EOT
  default     = "awsdns-hostmaster.amazon.com. 1 7200 900 1209600 60"
}

variable "delegation_set_id" {
  type        = string
  default     = null
  description = <<-EOT
    Existing reusable Route53 delegation set id to attach every zone to. When set,
    the id is looked up (and validated) and all zones share that delegation set's
    name servers — e.g. a subdomain zone attaching to its apex's delegation set.
    Mutually exclusive with `create_delegation_set`. When null (default), no
    existing set is attached.
  EOT
}

variable "create_delegation_set" {
  type        = bool
  default     = false
  description = <<-EOT
    Create a new reusable Route53 delegation set and attach every zone to it, so
    a group of zones (e.g. an apex and its subdomains) share one fixed name-server
    set. Ignored when `delegation_set_id` is set. Defaults to false, preserving
    the upstream behavior of letting AWS assign per-zone name servers.
  EOT
}

variable "delegation_set_reference_name" {
  type        = string
  default     = null
  description = "Reference name for the delegation set created when `create_delegation_set` is true. Ignored otherwise."
}

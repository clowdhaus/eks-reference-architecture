variable "acm_certificate_domain" {
  description = "Existing AWS ACM certificate domain name; used to lookup ACM certificate for use by AWS Client VPN"
  type        = string
}

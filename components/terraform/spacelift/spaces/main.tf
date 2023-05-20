module "space" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-space?ref=chore/refactor-module"
  #version = "0.55.0"

  for_each = var.spaces
  enabled  = local.enabled

  space_name                   = each.key
  parent_space_id              = each.value.parent_space_id
  description                  = each.value.description
  inherit_entities_from_parent = each.value.inherit_entities
  labels                       = each.value.labels

}

locals {
  enabled = module.this.enabled
  spaces = local.enabled ? { for item in values(module.space)[*].space : item.name => {
    description      = item.description
    id               = item.id
    inherit_entities = item.inherit_entities
    labels           = toset(item.labels)
    parent_space_id  = item.parent_space_id
    }
  } : {}

  write_params = local.enabled && var.ssm_params_enabled
}

resource "aws_ssm_parameter" "this" {
  for_each = local.write_params ? local.spaces : {}
  name     = "/spacelift/spaces/${each.key}/id"
  type     = "String"
  value    = each.value.id
}

output "spaces" {
  value = local.spaces
}

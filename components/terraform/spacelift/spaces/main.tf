variable "spaces" {
  type = map(object({
    parent_space_id  = string,
    description      = optional(string),
    inherit_entities = optional(bool, false),
    labels           = optional(set(string), []),
  }))
}

module "space" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-space?ref=chore/refactor-module"
  #version = "0.55.0"

  for_each = var.spaces

  space_name                   = each.key
  parent_space_id              = each.value.parent_space_id
  description                  = each.value.description
  inherit_entities_from_parent = each.value.inherit_entities
  labels                       = each.value.labels

}


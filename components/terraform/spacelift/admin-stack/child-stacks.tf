locals {
  child_stacks = {
    for k, v in module.child_stacks_config.spacelift_stacks : k => v
    if try(v.settings.spacelift.workspace_enabled, false) == true
  }

  child_policies = distinct(flatten([for item in values(module.child_stack)[*] : [
    for policy in var.child_policy_attachments :
    {
      policy_id = local.policies[policy]
      stack_id  = item.id
    }
  ]]))
}

# We now get all of the stack configurations from the atmos config that matched the context_filters and create a stack
# for each one.
module "child_stacks_config" {
  source          = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stacks-from-atmos-config?ref=chore/refactor-module"
  context_filters = var.context_filters
}

module "child_stack" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stack?ref=chore/refactor-module"
  #version = "0.55.0"

  for_each = local.child_stacks

  stack_name     = try(each.value.settings.spacelift.stack_name, each.key)
  administrative = try(each.value.settings.spacelift.administrative, false)
  repository     = var.repository
  space_id       = local.spaces[each.value.settings.spacelift.space_name]

  atmos_stack_name    = try(each.value.stack, null)
  component_name      = try(each.value.component, null)
  component_root      = try(join("/", [var.component_root, try(each.value.metadata.component, each.value.component)]))
  terraform_workspace = try(each.value.workspace, null)

  autodeploy            = try(each.value.settings.spacelift.autodeploy, false)
  autoretry             = try(each.value.settings.spacelift.autoretry, false)
  manage_state          = try(each.value.settings.spacelift.manage_state, false)
  protect_from_deletion = try(each.value.settings.spacelift.protect_from_deletion, false)
  runner_image          = try(each.value.settings.spacelift.runner_images, var.runner_image)

  labels = concat(try(each.value.labels, []), ["managed-by:${local.managed_by}"])

  before_init  = try(each.value.settings.spacelift.before_init, [])
  before_plan  = try(each.value.settings.spacelift.before_plan, [])
  before_apply = try(each.value.settings.spacelift.before_apply, [])

  worker_pool_id = local.worker_pools[var.worker_pool_name]
}

resource "spacelift_policy_attachment" "child" {
  for_each  = { for idx, item in local.child_policies : md5(join("", [item.policy_id, item.stack_id])) => item }
  policy_id = each.value.policy_id
  stack_id  = each.value.stack_id
}

output "test" {
  value = local.policies
}

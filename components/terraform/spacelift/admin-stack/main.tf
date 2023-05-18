locals {
  enabled                 = module.this.enabled
  create_root_admin_stack = local.enabled && var.root_admin_stack
  root_admin_stack_name   = local.create_root_admin_stack ? keys(module.root_admin_stack_config.spacelift_stacks)[0] : null
  root_admin_stack_config = local.create_root_admin_stack ? module.root_admin_stack_config.spacelift_stacks[local.root_admin_stack_name] : null
}

# The root admin stack is a special stack that is used to manage all of the other admin stacks in the the Spacelift
# organization. This stack is denoted by setting the root_administrative property to true in the atmos config. Only one
# such stack is allowed in the Spacelift organization.
module "root_admin_stack_config" {
  source  = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stacks-from-atmos-config?ref=chore/cleanup-stack-module"
  enabled = local.create_root_admin_stack

  context_filters = {
    root_administrative = true
  }
}

module "root_admin_stack" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stack?ref=chore/cleanup-stack-module"
  #version = "0.55.0"
  # https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git
  enabled = local.create_root_admin_stack

  stack_name       = try(var.stack_name, local.root_admin_stack_name)
  administrative   = true
  repository       = var.repository
  space_id         = var.space_id
  atmos_stack_name = try(local.root_admin_stack_config.stack, null)
  component_name   = try(local.root_admin_stack_config.component, null)
  component_root   = try(join("/", [var.component_root, local.root_admin_stack_config.metadata.component]), null)
  manage_state     = false
  worker_pool_id   = var.worker_pool_id

  labels = try(local.root_admin_stack_config.labels, [])

  autodeploy            = var.autodeploy
  autoretry             = var.autoretry
  protect_from_deletion = var.protect_from_deletion
  runner_image          = var.runner_image

  before_init  = try(local.root_admin_stack_config.settings.spacelift.before_init, [])
  before_plan  = try(local.root_admin_stack_config.settings.spacelift.before_plan, [])
  before_apply = try(local.root_admin_stack_config.settings.spacelift.before_apply, [])
}

# We now get all of the stack configurations from the atmos config that matched the context_filters and create a stack
# for each one.
module "child_stacks_config" {
  source          = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stacks-from-atmos-config?ref=chore/cleanup-stack-module"
  context_filters = var.context_filters
}

module "child_stack" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stack?ref=chore/cleanup-stack-module"
  #version = "0.55.0"

  for_each = {
    for k, v in module.child_stacks_config.spacelift_stacks : k => v
    if try(v.settings.spacelift.workspace_enabled, false) == true
  }

  stack_name       = each.key
  administrative   = try(each.value.settings.spacelift.administrative, false)
  repository       = var.repository
  space_id         = var.space_id
  atmos_stack_name = try(each.value.stack, null)
  component_name   = try(each.value.component, null)
  component_root   = try(join("/", [var.component_root, each.value.metadata.component]), null)

  autodeploy            = try(each.value.settings.spacelift.autodeploy, false)
  autoretry             = try(each.value.settings.spacelift.autoretry, false)
  manage_state          = try(each.value.settings.spacelift.manage_state, false)
  protect_from_deletion = try(each.value.settings.spacelift.protect_from_deletion, false)
  runner_image          = try(each.value.settings.spacelift.runner_images, var.runner_image)

  labels = try(each.value.labels, [])

  before_init  = try(each.value.settings.spacelift.before_init, [])
  before_plan  = try(each.value.settings.spacelift.before_plan, [])
  before_apply = try(each.value.settings.spacelift.before_apply, [])

  worker_pool_id = var.worker_pool_id
}

output "root_config" {
  value = local.root_admin_stack_config
}
# output "foo" {
#   value = module.child_stacks_config.spacelift_stacks
# }

# output "bar" {
#   value = module.root_admin_stack_config.spacelift_stacks
# }

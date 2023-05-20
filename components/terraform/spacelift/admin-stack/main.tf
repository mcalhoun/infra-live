locals {
  enabled                 = module.this.enabled
  create_root_admin_stack = local.enabled && var.root_admin_stack
  root_admin_stack_name   = local.create_root_admin_stack ? keys(module.root_admin_stack_config.spacelift_stacks)[0] : null
  root_admin_stack_config = local.create_root_admin_stack ? module.root_admin_stack_config.spacelift_stacks[local.root_admin_stack_name] : null
  managed_by              = local.create_root_admin_stack ? local.root_admin_stack_name : "matt"

  # This loops through all of the administrative stacks in the atmos config and extracts the space_name from the
  # spacelift.settings metadata. It then creates a set of all of the unique space_names so we can use that to look up
  # their IDs from SSM parameters.
  spaces = toset([for k, v in {
    for k, v in module.child_stacks_config.spacelift_stacks : k => try(v.settings.spacelift.space_name, "root")
    if try(v.settings.spacelift.workspace_enabled, false) == true
  } : v if v != "root"])
}

data "aws_ssm_parameter" "spaces" {
  for_each = local.spaces
  name     = "/spacelift/spaces/${each.key}/id"
}

# The root admin stack is a special stack that is used to manage all of the other admin stacks in the the Spacelift
# organization. This stack is denoted by setting the root_administrative property to true in the atmos config. Only one
# such stack is allowed in the Spacelift organization.
module "root_admin_stack_config" {
  source  = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stacks-from-atmos-config?ref=chore/refactor-module"
  enabled = local.create_root_admin_stack

  context_filters = {
    root_administrative = true
  }
}

module "root_admin_stack" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stack?ref=chore/refactor-module"
  #version = "0.55.0"
  # https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git
  enabled = local.create_root_admin_stack

  stack_name          = var.stack_name != null ? var.stack_name : local.root_admin_stack_name
  administrative      = true
  repository          = var.repository
  space_id            = "root"
  atmos_stack_name    = try(local.root_admin_stack_config.stack, null)
  component_name      = try(local.root_admin_stack_config.component, null)
  component_root      = try(join("/", [var.component_root, local.root_admin_stack_config.metadata.component]), null)
  manage_state        = false
  worker_pool_id      = var.worker_pool_id
  terraform_workspace = try(local.root_admin_stack_config.workspace, null)

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
  source          = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stacks-from-atmos-config?ref=chore/refactor-module"
  context_filters = var.context_filters
}

module "child_stack" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stack?ref=chore/refactor-module"
  #version = "0.55.0"

  for_each = {
    for k, v in module.child_stacks_config.spacelift_stacks : k => v
    if try(v.settings.spacelift.workspace_enabled, false) == true
  }

  stack_name     = try(each.value.settings.spacelift.stack_name, each.key)
  administrative = try(each.value.settings.spacelift.administrative, false)
  repository     = var.repository
  space_id       = try(nonsensitive(data.aws_ssm_parameter.spaces[each.value.settings.spacelift.space_name].value), "root")

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

  worker_pool_id = var.worker_pool_id
}

#component      = "spacelift/admin-stack"
#stack          = "infra-gbl-root"

# output "foo" {
#   value = local.root_admin_stack_name
# }

output "foo" {
  value = module.child_stacks_config.spacelift_stacks
}

# output "spaces" {
#   value = local.spaces
# }

# output "bar" {
#   value = module.root_admin_stack_config.spacelift_stacks
# }

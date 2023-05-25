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
  worker_pool_id      = local.worker_pools[var.worker_pool_name]
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

resource "spacelift_policy_attachment" "root" {
  for_each  = var.root_stack_policy_attachments
  policy_id = local.policies[each.key]
  stack_id  = module.root_admin_stack.id
}

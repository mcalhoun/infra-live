locals {
  enabled                 = module.this.enabled
  create_root_admin_stack = local.enabled && var.root_admin_stack
  root_admin_stack_name   = local.create_root_admin_stack ? keys(module.root_admin_stack_config.spacelift_stacks)[0] : null
  root_admin_stack_config = local.create_root_admin_stack ? module.root_admin_stack_config.spacelift_stacks[local.root_admin_stack_name] : null
  managed_by              = local.create_root_admin_stack ? local.root_admin_stack_name : "matt"

  # This loops through all of the administrative stacks in the atmos config and extracts the space_name from the
  # spacelift.settings metadata. It then creates a set of all of the unique space_names so we can use that to look up
  # their IDs from remote state.
  unique_spaces = toset([for k, v in {
    for k, v in module.child_stacks_config.spacelift_stacks : k => try(v.settings.spacelift.space_name, "root")
    if try(v.settings.spacelift.workspace_enabled, false) == true
  } : v if v != "root"])

  # Create a map of all the unique spaces {space_name = space_id}
  spaces = merge({
    for k in local.unique_spaces : k => module.spaces.outputs.spaces[k].id
    }, {
    root = "root"
  })

  # Create a map of all the worker pools {worker_pool_name = worker_pool_id}
  worker_pools = { for k, v in data.spacelift_worker_pools.this.worker_pools : v.name => v.worker_pool_id }

  # Create a map of all the policies {policy_name = policy_id}
  policies = { for k, v in data.spacelift_policies.this.policies : v.name => v.id }
}

data "spacelift_worker_pools" "this" {}
data "spacelift_policies" "this" {}

locals {
  enabled = module.this.enabled
}

module "spacelift" {
  source = "git::https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git//modules/spacelift-stack?ref=chore/cleanup-stack-module"
  #version = "0.55.0"
  # https://github.com/cloudposse/terraform-spacelift-cloud-infrastructure-automation.git
  stack_name       = var.stack_name
  repository       = var.repository
  space_id         = var.space_id
  atmos_stack_name = var.atmos_stack_name
  component_name   = var.component_name
  component_root   = var.component_root
  manage_state     = true

  before_init = [
    "/mnt/workspace/source/rootfs/usr/local/bin/spacelift-install-atmos",
    "/mnt/workspace/source/rootfs/usr/local/bin/spacelift-configure-paths",
    "/mnt/workspace/source/rootfs/usr/local/bin/spacelift-write-vars",
    "/mnt/workspace/source/rootfs/usr/local/bin/spacelift-tf-workspace"
  ]

  before_plan  = ["/mnt/workspace/source/rootfs/usr/local/bin/spacelift-configure-paths"]
  before_apply = ["/mnt/workspace/source/rootfs/usr/local/bin/spacelift-configure-paths"]
  
}

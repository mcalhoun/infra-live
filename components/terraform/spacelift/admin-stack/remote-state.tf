module "spaces" {
  source  = "cloudposse/stack-config/yaml//modules/remote-state"
  version = "1.4.1"

  component   = "spacelift/spaces"
  environment = "gbl"   //coalesce(var.account_map_environment_name, module.this.environment)
  stage       = "root"  // var.account_map_stage_name
  tenant      = "infra" //coalesce(var.account_map_tenant_name, module.this.tenant)

  context = module.this.context
}

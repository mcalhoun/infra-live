output "spaces" {
  value = local.enabled ? local.spaces : {}
}

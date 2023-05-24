variable "spaces" {
  type = map(object({
    parent_space_id  = string,
    description      = optional(string),
    inherit_entities = optional(bool, false),
    labels           = optional(set(string), []),
  }))
}

variable "ssm_params_enabled" {
  type        = bool
  description = "Whether to write the IDs of the created spaces to SSM parameters"
  default     = true
}

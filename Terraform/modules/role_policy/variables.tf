variable "environment" {
  description = "The environment (e.g., dev, prod)"
  type        = string
}

variable "appname" {
  description = "The application name"
  type        = string
}

variable "assume_role_policy" {
  description = "The assume role policy document"
  type        = string
}

variable "policy_description" {
  description = "Description of the IAM policy"
  type        = string
}

variable "policy_document" {
  description = "The IAM policy document (JSON)"
  type        = string
}

variable "tags" {
  description = "A map of tags for the IAM role"
  type        = map(string)
  default     = {}
}

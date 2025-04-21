

variable "appname" {
  description = "The application name"
  type        = string
  default = "ravitest"
}
variable "environment" {
  description = "The application name"
  type        = string
}

variable "tags" {
  description = "A map of tags for the IAM role"
  type        = map(string)
  default     = {}
}

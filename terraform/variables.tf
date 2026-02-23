variable "region" {
  type    = string
  default = "us-east-1"
}

variable "lambda_name" {
  type    = string
  default = "nr-alert-sync"
}

variable "nr_api_key_param_name" {
  type = string
}

variable "nr_api_key_param_arn" {
  type = string
}
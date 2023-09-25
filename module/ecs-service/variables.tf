variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "image" {
  default = "public.ecr.aws/nginx/nginx:alpine"
  type    = string
}

variable "log_retention" {
  default = 7
  type    = number
}

variable "name" {
  type = string
}

variable "parameters" {
  default = []
  type    = list(string)
}

variable "parameters_secure" {
  default = []
  type    = list(string)
}

variable "port" {
  default = 80
  type    = number
}

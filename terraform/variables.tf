variable "api_image_tag" {
  description = "required image tag value to deploy to ECS task"
  type        = string
}

variable "web_image_tag" {
  description = "required image tag value to deploy to ECS task"
  type        = string
}

variable "app_name" {
  type    = string
  default = "3tier-app"
}

variable "api_port" {
  type    = number
  default = 8080
}

variable "web_port" {
  type    = number
  default = 3000
}

variable "api_service_name" {
  type    = string
  default = "api"
}

variable "web_service_name" {
  type    = string
  default = "web"
}

variable "api_default_url_path" {
  type    = string
  default = "/api/status"
}

variable "domain" {
  type    = string
  default = "3tier.clarkwinters.com"
}

variable "api_tags" {
  type = object({
    Name      = string
    component = string
  })
  default = {
    Name      = "3tier-app-api"
    component = "api"
  }
}

variable "web_tags" {
  type = object({
    Name      = string
    component = string
  })
  default = {
    Name      = "3tier-app-web"
    component = "web"
  }
}

variable "public_tags" {
  type = object({
    Name = string
  })
  default = {
    Name = "3tier-app-public"
  }
}

variable "logging_tags" {
  type = object({
    Name = string
  })
  default = {
    Name = "3tier-app-logs"
  }
}

variable "db_name" {
  type    = string
  default = "pg-3tier-app-db"
}

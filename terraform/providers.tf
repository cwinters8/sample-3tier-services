terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
  }

  backend "s3" {
    region         = "us-east-2"
    bucket         = "3tier-services-infra"
    key            = "tf/terraform.tfstate"
    dynamodb_table = "3tier-services-infra"
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      "Name"       = var.app_name
      "service"    = var.app_name
      "managed_by" = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

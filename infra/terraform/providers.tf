terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  #this is locking provider version to 5.x versions only
    }
  }
  required_version = ">= 1.13.1, < 1.13.3"
}

provider "aws" {
    region = var.aws_region
}
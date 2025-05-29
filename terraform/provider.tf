terraform {
  required_version = "1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.84.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.5"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

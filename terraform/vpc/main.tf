locals {
  region = "us-east-2"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = local.region
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

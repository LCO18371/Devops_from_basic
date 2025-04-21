terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.0.0"
}
provider "aws" {
  region = "us-east-1"
}

data "aws_iam_policy_document" "assume_role_policy" {
  # Assuming the role by CodeBuild
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}


module "role_policy" {
  source             = "./modules/role_policy"
  environment        = var.environment
  appname = var.appname
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  # tags               = { "project" = var.project }
}


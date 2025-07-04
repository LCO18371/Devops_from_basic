terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">=1.2.0"
}
provider "aws" {
  region = "us-east-1"
}

# | OS             | SSM Parameter Path |
# |----------------|--------------------|
# | Amazon Linux 2 | `/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2` |
# | Ubuntu         | `/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id` |
# | Windows        | `/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base` |

data "aws_ssm_parameter" "amazon_linux2" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# data "aws_key_pair" "existing" {
#   key_name = var.EC2_Key_Name
#   # optional: depends on whether the key might not exist
# }

resource "aws_key_pair" "deployer" {
  key_name   = var.EC2_Key_Name
  public_key = "~/.ssh/id_rsa.pub"
  
  }

resource "aws_instance" "test" {
  depends_on = [ aws_key_pair.deployer ]
  ami           = data.aws_ssm_parameter.amazon_linux2.value
  instance_type = var.EC2_Instance_Type
  key_name      = aws_key_pair.deployer.key_name

  tags = {
    Name = var.EC2_Name
  }

}

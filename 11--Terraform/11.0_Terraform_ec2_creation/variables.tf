variable "EC2_Name" {
  type        = string
  description = "EC2 server name"
  default     = "Test"
}
variable "EC2_Instance_Type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}
variable "EC2_Region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}
variable "EC2_Ami" {
  type        = string
  description = "AMI ID"
  default     = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}
variable "EC2_Security_Group" {
  type        = string
  description = "Security group ID"
  default     = "sg-12345678"
}
variable "EC2_Key_Name" {
  type        = string
  description = "Key pair name"
  default     = "raviterraform"
}
variable "EC2_User_Data" {
  type        = string
  description = "User data script"
  default     = "#!/bin/bash\necho Hello, World! > /var/tmp/hello.txt"
}
variable "EC2_IAM_Role" {
  type        = string
  description = "IAM role name"
  default     = "my-iam-role"
}
variable "EC2_IAM_Policy" {
  type        = string
  description = "IAM policy name"
  default     = "my-iam-policy"
}
variable "EC2_EBS_Volume_Size" {
  type        = number
  description = "EBS volume size in GB"
  default     = 8
}
variable "EC2_EBS_Volume_Type" {
  type        = string
  description = "EBS volume type"
  default     = "gp2"
}
variable "EC2_EBS_Volume_Iops" {
  type        = number
  description = "EBS volume IOPS"
  default     = 100
}
variable "EC2_EBS_Volume_Throughput" {
  type        = number
  description = "EBS volume throughput in MB/s"
  default     = 128
}

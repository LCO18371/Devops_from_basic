resource "aws_iam_role" "role" {
  name               = "${var.environment}-${var.appname}-codebuild-role"
  assume_role_policy = var.assume_role_policy

  #tags = var.tags
}

resource "aws_iam_policy" "policy" {
  name        = "${var.environment}-${var.appname}-codebuild-policy"
  description = var.policy_description
  policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::your-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:StartBuild",
        "codebuild:BatchGetBuilds"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codepipeline:PutActionRevision",
        "codepipeline:GetPipelineState"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}


resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

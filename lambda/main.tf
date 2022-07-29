terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.23.0"
    }
  }
  cloud {
    organization = "lae"
    workspaces {
      name = "aws-things-lambda"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  function_name = "aws-things-lambda"
}

resource "aws_iam_role" "default" {
  name               = local.function_name
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "default" {
  name   = local.function_name
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : "${aws_cloudwatch_log_group.default.arn}:*",
        Effect : "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}

resource "aws_cloudwatch_log_group" "default" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 30
}

data "archive_file" "default" {
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
  type        = "zip"
}

resource "aws_lambda_function" "default" {
  function_name    = local.function_name
  role             = aws_iam_role.default.arn
  filename         = data.archive_file.default.output_path
  source_code_hash = filebase64sha256(data.archive_file.default.output_path)
  handler          = "main.handle"
  runtime          = "nodejs16.x"
}

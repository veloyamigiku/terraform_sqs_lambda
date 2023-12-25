terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.4.1"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "archive" {}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/sqs_lambda"
}

data "archive_file" "function_source" {
  type = "zip"
  source_dir = "app"
  output_path = "archive/my_lambda_function.zip"
}


data "aws_iam_policy_document" "assume" {

  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }

}

resource "aws_iam_role" "role" {

  assume_role_policy = data.aws_iam_policy_document.assume.json

  name = "role_for_sqs_lambda"

}

resource "aws_iam_role_policy_attachment" "rpa_lambda" {

  role = aws_iam_role.role.id

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

}

resource "aws_iam_role_policy_attachment" "rpa_sqs" {

  role = aws_iam_role.role.id

  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"

}

resource "aws_lambda_function" "function" {
  function_name = "sqs_lambda"
  handler = "simple_lambda.lambda_handler"
  role = aws_iam_role.role.arn
  runtime = "python3.10"
  filename = data.archive_file.function_source.output_path
  source_code_hash = data.archive_file.function_source.output_base64sha256
  depends_on = [
    aws_iam_role_policy_attachment.rpa_lambda,
    aws_iam_role_policy_attachment.rpa_sqs,
    aws_cloudwatch_log_group.lambda_log_group
    ]
  tags = {
    "Name" = "sqs_lambda"
  }
}

resource "aws_sqs_queue" "sqs_dlq" {
  name = "sqs_dlq_lambda"
}

resource "aws_sqs_queue" "sqs" {
  name = "sqs_lambda"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sqs_dlq.arn
    maxReceiveCount = 1
  })
}

resource "aws_lambda_event_source_mapping" "lesm" {

  function_name = aws_lambda_function.function.arn

  event_source_arn = aws_sqs_queue.sqs.arn

}

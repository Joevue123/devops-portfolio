terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = "portfolio-17", ManagedBy = "terraform", Environment = var.environment }
  }
}

# ── Lambda package ──────────────────────────────────────────────────
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/lambda.zip"
}

# ── IAM role for Lambda ─────────────────────────────────────────────
resource "aws_iam_role" "lambda" {
  name = "lambda-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query"]
      Resource = aws_dynamodb_table.items.arn
    }]
  })
}

# ── Lambda function ─────────────────────────────────────────────────
resource "aws_lambda_function" "api" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "items-api-${var.environment}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]   # Graviton — 20% cheaper
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items.name
      ENVIRONMENT = var.environment
      LOG_LEVEL   = "INFO"
    }
  }

  tracing_config { mode = "Active" }  # X-Ray tracing
}

# ── DynamoDB table ──────────────────────────────────────────────────
resource "aws_dynamodb_table" "items" {
  name         = "items-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"   # on-demand, no capacity planning
  hash_key     = "id"

  attribute { name = "id",         type = "S" }
  attribute { name = "owner_id",   type = "S" }
  attribute { name = "created_at", type = "S" }

  global_secondary_index {
    name            = "by-owner-index"
    hash_key        = "owner_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  ttl { attribute_name = "expires_at", enabled = true }
  point_in_time_recovery { enabled = true }
}

# ── API Gateway v2 (HTTP API) ───────────────────────────────────────
resource "aws_apigatewayv2_api" "api" {
  name          = "items-api-${var.environment}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each  = toset(["GET /items", "POST /items", "GET /items/{id}", "DELETE /items/{id}"])
  api_id    = aws_apigatewayv2_api.api.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
  }
}

resource "aws_lambda_permission" "api_gw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.api.name}"
  retention_in_days = 14
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. DynamoDB Table Definition
resource "aws_dynamodb_table" "visitor_counter" {
  name         = "cloud-resume-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
  # 2. IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_role" {
  name = "cloud-resume-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach basic execution policy (for CloudWatch logging)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach DynamoDB Full Access policy
resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# 3. Automatically package the Python code into a ZIP archive
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/lambda_function.zip"
}

# 4. Lambda Function Definition
resource "aws_lambda_function" "visitor_counter" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cloud-resume-visitor-counter-tf" # Using a -tf suffix to keep your manual one safe for now!
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}
# 5. HTTP API Gateway Definition
resource "aws_apigatewayv2_api" "http_api" {
  name          = "cloud-resume-api-tf"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://collesha.xyz"] # Restricts access to your domain cleanly!
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

# API Gateway Integration to Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter.arn
}

# API Gateway Route configuration (/get-count)
resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /get-count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Automatic Deployment Stage ($default)
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Grant permission for API Gateway to invoke your Lambda function
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# Output the new Invoke URL directly to your terminal screen when done!
output "api_gateway_url" {
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/get-count"
  description = "The live endpoint URL for your frontend JavaScript"
}

# 1. DYNAMODB TABLE
resource "aws_dynamodb_table" "visitor_count" {
  name             = "cloud-resume-visitor-count" # Unique name for the table
  billing_mode     = "PAY_PER_REQUEST"            # Free Tier Friendly
  hash_key         = "id"                         # Primary partition key

  attribute {
    name = "id"
    type = "S" # String type
  }
  
  tags = {
    Name = "VisitorCountTable"
  }
}

# 2. IAM ROLE for Lambda Execution
resource "aws_iam_role" "lambda_exec" {
  name = "cloud-resume-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

# Attach the Basic Execution Policy (for CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 3. IAM Policy to access DynamoDB (GRANTING PERMISSIONS)
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "dynamodb_read_write"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
        ],
        Effect   = "Allow",
        # Lambda needs permissions ONLY on the specific table's ARN
        Resource = aws_dynamodb_table.visitor_count.arn 
      },
    ]
  })
}

# 4. ARCHIVE FILE (Using a data source to compress the JS file)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.js"
  output_path = "${path.module}/lambda/lambda.zip"
}

# 5. LAMBDA FUNCTION
resource "aws_lambda_function" "counter_update" {
  function_name = "CloudResumeCounterUpdate"
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  role          = aws_iam_role.lambda_exec.arn
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      # Pass the DynamoDB name to the Lambda environment
      TABLE_NAME = aws_dynamodb_table.visitor_count.name 
    }
  }

  # ADD THIS DEPENDENCY BLOCK:
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.dynamodb_access,
  ]
}

# 6. API GATEWAY (HTTP API)
resource "aws_apigatewayv2_api" "counter_api" {
  name          = "CloudResumeCounterAPI"
  protocol_type = "HTTP"
}

# 7. API Gateway INTEGRATION (Connects the API to the Lambda)
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.counter_api.id
  integration_type = "AWS_PROXY"
  integration_method = "POST" 
  integration_uri  = aws_lambda_function.counter_update.invoke_arn
  payload_format_version = "2.0"
}

# 8. API Gateway ROUTE (Define the path/method)
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.counter_api.id
  route_key = "GET /visits" # Define a GET route at /visits
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 9. API Gateway DEPLOYMENT (Makes the API changes live)
resource "aws_apigatewayv2_deployment" "api_deployment" {
  api_id = aws_apigatewayv2_api.counter_api.id
  # Force a new deployment whenever the route or integration changes
  depends_on = [
    aws_apigatewayv2_route.default_route,
    aws_apigatewayv2_integration.lambda_integration,
  ]
}

# 10. API Gateway STAGE (The public endpoint)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.counter_api.id
  name        = "$default" # Creates the default public stage
  # deployment_id = aws_apigatewayv2_deployment.api_deployment.id # <-- REMOVE OR COMMENT OUT THIS LINE
  auto_deploy = true # Ensures subsequent changes are automatically deployed
}

# 11. LAMBDA PERMISSION (Allow the API Gateway to invoke the Lambda)
resource "aws_lambda_permission" "apigw_lambda" {
  # Change the statement_id here:
  statement_id  = "AllowExecutionFromAPIGatewayNew" # <-- CHANGED!
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.counter_update.function_name
  principal     = "apigateway.amazonaws.com"

  # Source ARN ensures only this specific API can call the function
  source_arn = "${aws_apigatewayv2_api.counter_api.execution_arn}/*/*"
}
resource "aws_lambda_function" "init-env-17f" {
  architectures = ["x86_64"]
  function_name = "init-env"
  image_uri     = "824784664836.dkr.ecr.eu-west-1.amazonaws.com/init-env:latest"
  package_type  = "Image"
  role          = "arn:aws:iam::824784664836:role/stag-lambda-general-role"
  timeout       = 180
  tracing_config {
    mode = "Active"
  }
  vpc_config {
    security_group_ids = ["sg-002735fa484999b42"]
    subnet_ids         = ["subnet-01a753a6428403aa1", "subnet-0a2cd96de23ad0bfd"]
  }
}


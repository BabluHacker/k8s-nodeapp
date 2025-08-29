terraform {
  backend "s3" {
    bucket         = "nodejs-app-terraform-state-enosis"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

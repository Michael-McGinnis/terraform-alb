/* Versions file outline the terraform and provider versions so 
the build can be reproducible. 
1) Locks terraform core to any version greater than 1.6. 
2) Explicit AWS version of 5.x */

terraform {
  required_version = ">= 1.6" # Terraform CLI version guard
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "5.33.0, <6.0.0" # Satisfies all modules
    }
  }
}

# Single provide block. Region is passed as a variable for flexibility.

provider "aws" {
    region = var.aws_region
}
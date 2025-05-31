
/* Variables.tf is the file where inputs can be declared where configurations coukd
be changed without modifying the HCL files directly. For example a user can
change the variable in the CLI: terraform apply -var="aws_region=us-west-2" 

** Terraform resolved variables from the CLI as highest priority and variables.tf as lowest priority. **
*/

variable "aws_region" {     # Keeps code portable as any user worldwide can change the variable
    default = "us-east-1"
}

/* Used as a tag for every resource name (VPC name, ALB name, etc).
Can be used to create multiple isolated copies side by side in the same AWS acount. 
Example project = "demo1", project = "demo2" */

variable "project" {        
    default = "alb"         
}

variable "az_count" {       # Lets the user decide how many az's to span for resilience.
  default = 2
}
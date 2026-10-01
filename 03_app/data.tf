data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "ecs-infra-tfstate-772297676546"
    key    = "00_networking/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = "ecs-infra-tfstate-772297676546"
    key    = "ecr/terraform.tfstate"
    region = "eu-west-1"
  }
}

# Newest image in each repo — only used when Terraform registers a task definition.
# Day-to-day deploys are done by CI, not Terraform.
data "aws_ecr_image" "latest" {
  for_each        = data.terraform_remote_state.ecr.outputs.ecr_repository_names
  repository_name = each.value
  most_recent     = true
}

data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket = "ecs-infra-tfstate-772297676546"
    key    = "01_ecs/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "data" {
  backend = "s3"
  config = {
    bucket = "ecs-infra-tfstate-772297676546"
    key    = "02_data/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "ecs-infra-tfstate-772297676546"
    key    = "00_networking/terraform.tfstate"
    region = "eu-west-1"
  }
}
data "aws_route53_zone" "main" {
  name = "nt-nick.link"
}
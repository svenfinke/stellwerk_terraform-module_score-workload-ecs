data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["orch-aws-vpc"]
  }
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Tier"
    values = [var.subnet_tier]
  }
}

data "aws_ecs_cluster" "main" {
  cluster_name = var.cluster_name
}

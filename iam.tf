locals {
  name_prefix = "${var.app_id}-${var.env_id}-${var.res_id}"

  common_tags = {
    app        = var.app_id
    env        = var.env_id
    managed-by = "humanitec"
  }
}

# ---------------------------------------------------------------------------
# ECS Task Execution Role
# Grants ECS the permissions needed to pull container images and write logs.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name_prefix}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# ECS Task Role
# Runtime identity of the application container. Other resource modules
# (postgres, s3, sqs, …) attach their IAM policies to this role via the
# task_role_arn output.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = local.common_tags
}

output "task_role_arn" {
  description = "ARN of the ECS task IAM role. Other resource modules (postgres, s3, sqs, …) attach their policies to this role."
  value       = aws_iam_role.task.arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition (including revision)."
  value       = aws_ecs_task_definition.main.arn
}

output "service_arn" {
  description = "ARN of the ECS service."
  value       = aws_ecs_service.main.id
}

output "target_group_arn" {
  description = "ARN of the ALB target group."
  value       = aws_lb_target_group.main.arn
}

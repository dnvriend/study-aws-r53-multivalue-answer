output "aws_caller_identity" {
  value = data.aws_caller_identity.current
}

output "aws_region" {
  value = data.aws_region.current
}

output "ec2_instance_id" {
  value = aws_instance.instance.id
}

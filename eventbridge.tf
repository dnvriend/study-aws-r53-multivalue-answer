resource "aws_cloudwatch_event_rule" "ecs_task_launch_rule" {
  name        = "ecs-task-launch-rule"
  description = "Trigger Lambda on ECS task launch"
  event_pattern = jsonencode({
    "source" = ["aws.ecs"],
    "detail-type" = ["ECS Task State Change"],
    "detail" = {
      "lastStatus" = ["RUNNING"],
      "desiredStatus" = ["RUNNING", "STOPPED", ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_task_launch_target" {
  rule      = aws_cloudwatch_event_rule.ecs_task_launch_rule.name
  target_id = "ecs-task-launch-lambda"
  arn       = aws_lambda_function.ecs_task_launch_handler.arn
}

resource "aws_lambda_permission" "eventbridge_invoke_lambda" {
  statement_id  = "EventBridgeInvokePermission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_task_launch_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_task_launch_rule.arn
}
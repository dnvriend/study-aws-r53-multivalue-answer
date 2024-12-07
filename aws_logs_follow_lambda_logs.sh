#!/bin/bash
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/logs/tail.html
export AWS_PAGER=""
aws logs tail /aws/lambda/dnvriend-test-ecs-task-launch-handler --since 1h --follow

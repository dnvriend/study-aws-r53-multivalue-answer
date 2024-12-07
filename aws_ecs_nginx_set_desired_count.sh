#!/bin/bash
export AWS_PAGER=""
aws ecs update-service --cluster dnvriend-test-grafana-cluster --service dnvriend-test-nginx-service --output json --desired-count ${1:-0} | jq '.service | { desiredCount, pendingCount, runningCount }'

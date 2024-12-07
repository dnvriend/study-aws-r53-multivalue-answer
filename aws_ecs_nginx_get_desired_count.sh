#!/bin/bash
export AWS_PAGER=""
aws ecs describe-services --cluster dnvriend-test-grafana-cluster --services dnvriend-test-nginx-service --output json | jq '.services[0] | { desiredCount, pendingCount, runningCount }'

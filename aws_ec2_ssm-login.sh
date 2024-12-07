#!/bin/bash

# Check if instance ID is provided as argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <instance-id>"
    exit 1
fi

INSTANCE_ID=$1

# Check if instance exists and is running
STATUS=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[].Instances[].State.Name' \
    --output text 2>/dev/null)

if [ $? -ne 0 ] || [ "$STATUS" != "running" ]; then
    echo "Error: Instance $INSTANCE_ID not found or not running"
    exit 1
fi

# Check if SSM agent is running on the instance
SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[].PingStatus' \
    --output text 2>/dev/null)

if [ "$SSM_STATUS" != "Online" ]; then
    echo "Error: SSM agent is not running on instance $INSTANCE_ID"
    exit 1
fi

# Start SSM session
echo "Connecting to instance $INSTANCE_ID..."
aws ssm start-session --target $INSTANCE_ID

#!/bin/bash
export AWS_PAGER=""
zone_id=$(aws route53 list-hosted-zones --query "HostedZones[?Name == 'services.vpc.'].Id" --output text)
# jq query breakdown:
# .ResourceRecordSets[] - Get all record sets from the array
# select(.Name == "nginx.services.vpc.") - Filter to only records with this exact name
# .ResourceRecords[].Value - For each matching record, get the Value field from ResourceRecords array
aws route53 list-resource-record-sets --hosted-zone-id $zone_id  --output json | jq '.ResourceRecordSets[] | select(.Name == "nginx.services.vpc.") | .ResourceRecords[].Value'
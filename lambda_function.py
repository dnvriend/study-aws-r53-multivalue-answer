import json
import boto3
from datetime import datetime

class DateTimeEncoder(json.JSONEncoder):
    """
    Custom JSON encoder that handles datetime objects by converting them to ISO format strings.
    """
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super(DateTimeEncoder, self).default(obj)

ecs = boto3.client('ecs')
route53 = boto3.client('route53')

def get_unique_ips(attachments: list[dict]) -> [str]:
    ips = []
    try:
        for attachment in attachments:
            for detail in attachment['details']:
                if detail['name'] == 'privateIPv4Address':
                    ips.append(detail['value'])
        return list(set(ips))
    except KeyError as e:
        print(f"Error: {e}")
        return []

def get_tags(task_arn: str) -> [dict]:
    response = ecs.list_tags_for_resource(
        resourceArn=task_arn
    )
    if response.get('tags'):
        return response['tags']
    else:
        return []

def get_dns_name(task_arn: str) -> str | None:
    tags = get_tags(task_arn)
    for tag in tags:
        if tag.get('key') == 'DnsName':
            return tag['value']
    return None

def get_hosted_zone_id(task_arn: str) -> str | None:
    tags = get_tags(task_arn)
    for tag in tags:
        print(tag)
        if tag.get('key') == 'HostedZoneId':
            return tag['value']
    return None

def get_ips_for_dns_name(hosted_zone: id, dns_name: str):
    ips = []
    response = route53.list_resource_record_sets(
        HostedZoneId=hosted_zone
    )
    for rrs in response['ResourceRecordSets']:
        if rrs['Name'] == f'{dns_name}.':
            for rrr in rrs['ResourceRecords']:
                ips.append(rrr['Value'])
    return ips

def update_route53_record(hosted_zone_id: str, dns_name: str, ip_addresses: [str]) -> None:
    if not ip_addresses:
        ip_addresses = ["127.0.0.1"]

    response = route53.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch={
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': dns_name,
                        'Type': 'A',
                        'TTL': 300,
                        'ResourceRecords': list(map(lambda ip: {'Value': ip}, ip_addresses))
                    }
                }
            ]
        })
    print(response)

def get_all_task_arns(cluster_arn: str, service_name: str) -> [str]:
    all_tasks = []
    paginator = ecs.get_paginator('list_tasks')
    pages = paginator.paginate(cluster=cluster_arn, serviceName=service_name, desiredStatus='RUNNING') # Use desiredStatus
    for page in pages:
        all_tasks.extend(page['taskArns'])
    return all_tasks

def get_cluster_arn(service_name: str) -> str | None:
    for cluster in ecs.list_clusters()['clusterArns']:
        if service_name in cluster:
            return cluster
    return None

def get_tasks(cluster_arn: str, tasks: [str]) -> [dict]:
    if tasks:
        tasks_response = ecs.describe_tasks(cluster=cluster_arn, tasks=tasks)
        return tasks_response['tasks']
    return []

def get_service_arn(cluster: str, service_name: str):
    response = ecs.describe_services(cluster=cluster, services=[service_name])
    return response['services'][0]['serviceArn']

def lambda_handler(event, context):
    # print("Received event:", json.dumps(event))
    task_arn = event['detail']['taskArn']
    cluster_arn = event['detail']['clusterArn']
    desired_status = event['detail']['desiredStatus']
    last_status = event['detail']['lastStatus']
    print(f"Desired status: {desired_status}")
    print(f"Last status: {last_status}")
    group = event['detail']['group']
    print(f"Group: {group}")
    service_name = group.split(':')[1]
    print(f"Service name: {service_name}")

    task_arns = get_all_task_arns(cluster_arn, service_name)
    tasks = get_tasks(cluster_arn, task_arns)
    ips = [ip for task in tasks for ip in get_unique_ips(task['attachments'])]
    print(ips)
    # get the service, because that contains the dns name and hosted zone id
    service_arn = get_service_arn(cluster_arn, service_name)
    tags = get_tags(service_arn)
    for tag in tags:
        if tag.get('key') == 'HostedZoneId':
            hosted_zone_id = tag['value']
        if tag.get('key') == 'DnsName':
            dns_name = tag['value']
    update_route53_record(hosted_zone_id, dns_name, ips)

    return {
        'statusCode': 200,
        'body': json.dumps('Task launch processed successfully!')
    }


if __name__ == '__main__':
    service_name = "grafana-cluster"
    cluster_arn = get_cluster_arn(service_name)
    service_name = "dnvriend-test-nginx-service"
    task_arns = get_all_task_arns(cluster_arn, service_name)
    tasks = get_tasks(cluster_arn, task_arns)
    ips = [ip for task in tasks for ip in get_unique_ips(task['attachments'])]
    print(ips)

    # get the service, because that contains the dns name and hosted zone id
    service_arn = get_service_arn(cluster_arn, service_name)
    tags = get_tags(service_arn)
    for tag in tags:
        if tag.get('key') == 'HostedZoneId':
            hosted_zone_id = tag['value']
        if tag.get('key') == 'DnsName':
            dns_name = tag['value']
    update_route53_record(hosted_zone_id, dns_name, ips)


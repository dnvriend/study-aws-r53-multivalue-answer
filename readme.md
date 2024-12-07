# study-aws-r53-multivalue-answer
A small study project on updating a multivalue DNS record in Route53 when an ECS service launches a task in AWS. This is not necessary when you have access to AWS CloudMap. But if not, then you could use a lambda to update the DNS record to find the IPs for a group of tasks.


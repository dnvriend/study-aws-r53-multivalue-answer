resource "aws_route53_zone" "services" {
  name          = "services.vpc"
  force_destroy = true

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}

resource "aws_route53_record" "test" {
  zone_id = aws_route53_zone.services.zone_id
  name    = "test.services.vpc"
  type    = "A"
  ttl     = "300"
  records = ["127.0.0.1"]
}


resource "aws_route53_record" "nginx" {
  zone_id = aws_route53_zone.services.zone_id
  name    = "nginx.services.vpc"
  type    = "A"
  ttl     = "300"
  records = ["127.0.0.1"]

  # lifecycle {
  #   ignore_changes = [records]
  # }
}

resource "aws_route53_record" "grafana" {
  zone_id = aws_route53_zone.services.zone_id
  name    = "grafana.services.vpc"
  type    = "CNAME"
  ttl     = "300"
  records = ["rds-instance.abcdefghijkl.us-east-1.rds.amazonaws.com"]
}

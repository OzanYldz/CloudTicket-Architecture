output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS MySQL instance"
  value       = aws_db_instance.rds.endpoint
}
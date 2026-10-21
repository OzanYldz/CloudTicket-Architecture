# Look up the latest official Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Web and Application EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd php php-mysqli
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>CloudTicket Architecture v3.0 (Terraform Edition)</h1><p>Application Load Balancer & EC2 are Healthy!</p>" > /var/www/html/index.php
              EOF

  tags = {
    Name        = "cloudticket-app-server"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}

# Internet Facing Application Load Balancer
resource "aws_lb" "alb" {
  name               = "cloudticket-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "cloudticket-alb"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}

# ALB Target Group for HTTP Traffic
resource "aws_lb_target_group" "app_tg" {
  name     = "cloudticket-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "cloudticket-app-tg"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}

# Attach EC2 Instance to the Target Group
resource "aws_lb_target_group_attachment" "app_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 80
}

# ALB HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
resource "aws_security_group" "alb_sg" {
  name        = "cloudticket-alb-sg"
  description = "Security group for internet facing Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow inbound HTTP traffic from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cloudticket-alb-sg"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "cloudticket-ec2-sg"
  description = "Security group for EC2 instance allowing traffic only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP traffic exclusively from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cloudticket-ec2-sg"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "cloudticket-db-sg"
  description = "Security group for RDS instance allowing traffic only from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow MySQL traffic exclusively from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cloudticket-db-sg"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}
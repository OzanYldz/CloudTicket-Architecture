resource "aws_db_subnet_group" "db" {
  name       = "cloudticket-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "cloudticket-db-subnet-group"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}

resource "aws_db_instance" "rds" {
  identifier             = "cloudticket-db"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro"
  db_name                = "ticketdb"
  username               = "admin"
  password               = "CloudTicket2026!"
  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name        = "cloudticket-db"
    Environment = "Dev"
    Project     = "CloudTicket"
  }
}
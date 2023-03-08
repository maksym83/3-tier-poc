#Create provider
provider "aws" {
  region = "us-east-1"
}
#Create vpc
resource "aws_vpc" "F-16" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "F-16"
  }
}
#Create private subnet 
resource "aws_subnet" "mersedes_1" {
  vpc_id                  = aws_vpc.F-16.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "mersedes_1 "
  }
}
resource "aws_subnet" "mersedes_2" {
  vpc_id                  = aws_vpc.F-16.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "mersedes_2"
  }
}
#Create public subnet
resource "aws_subnet" "bmw_1" {
  vpc_id     = aws_vpc.F-16.id
  cidr_block = "10.0.11.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "bmw_1"
  }
}
resource "aws_subnet" "bmw_2" {
  vpc_id     = aws_vpc.F-16.id
  cidr_block = "10.0.12.0/24"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true

  tags = {
    Name = "bmw_2"
  }
}
#Create IGW
resource "aws_internet_gateway" "igw_zoro" {
  vpc_id = aws_vpc.F-16.id

  tags = {
    Name = "Zoro_IGW"
  }
}

# Create Web layber route table
resource "aws_route_table" "bmw-rt" {
  vpc_id = aws_vpc.F-16.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_zoro.id
  }

  tags = {
    Name = "bmw_RT"
  }
}
# Create Web Subnet association with Web route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.bmw_1.id
  route_table_id = aws_route_table.bmw-rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.bmw_2.id
  route_table_id = aws_route_table.bmw-rt.id
}

#Create EC2 Instance
resource "aws_instance" "bmw_webserver_1" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1c"
  vpc_security_group_ids = [aws_security_group.web-sg-bmw.id]
  subnet_id              = aws_subnet.bmw_1.id
  user_data              = file("bash.sh")

  tags = {
    Name = "Web bmw 1"
  }

}

resource "aws_instance" "bmw_webserver_2" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1d"
  vpc_security_group_ids = [aws_security_group.web-sg-bmw.id]
  subnet_id              = aws_subnet.bmw_2.id
  user_data              = file("bash.sh")

  tags = {
    Name = "Web bmw 2"
  }

}
# Create Web-BMW Security Group
resource "aws_security_group" "web-sg-bmw" {
  name        = "Web-SG-BMW"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.F-16.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG-BMW"
  }
}

# Create Database Mersedes Security Group
resource "aws_security_group" "database-sg_mersedes" {
  name        = "Database-SG-Mersedes"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.F-16.id

  ingress {
    description     = "Allow traffic from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg-bmw.id]
  }

  egress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database-SG-Mersedes"
  }
}
#Create LB and TG
resource "aws_lb" "external-elb" {
  name               = "External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-sg-bmw.id]
  subnets            = [aws_subnet.bmw_1.id, aws_subnet.bmw_2.id]
}

resource "aws_lb_target_group" "external-elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.F-16.id
}

resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.bmw_webserver_1.id
  port             = 80

  depends_on = [
    aws_instance.bmw_webserver_1
  ]
}

resource "aws_lb_target_group_attachment" "external-elb2" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.bmw_webserver_2.id
  port             = 80

  depends_on = [
    aws_instance.bmw_webserver_2
  ]
}

resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}
#Create DB
resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_subnet_group_name   = aws_db_subnet_group.default.id
  engine                 = "mysql"
  engine_version         = "8.0.28"
  instance_class         = "db.t2.micro"
  multi_az               = true
# name                   = "db_name"
  username               = "username"
  password               = "password"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database-sg_mersedes.id]
}

resource "aws_db_subnet_group" "default" {
  name       = "db_audi"
  subnet_ids = [aws_subnet.mersedes_1.id, aws_subnet.mersedes_2.id]

  tags = {
    Name = "My DB subnet group"
  }
}
output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.external-elb.dns_name
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

# Create an EC2 instance
# resource "aws_instance" "my-first-server" {
#   ami           = "ami-04505e74c0741db8d"
#   instance_type = "t2.micro"

#   tags = {
#     Name = "HelloWorld"
#   }
# }

# Create a VPC
# resource "aws_vpc" "first-vpc" {
#   cidr_block       = "10.0.0.0/16"
#   instance_tenancy = "default"

#   tags = {
#     Name = "production"
#   }
# }

# resource "aws_subnet" "subnet-1" {
#   vpc_id     = aws_vpc.first-vpc.id
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "prod-subnet" 
#   }
# }

# create a vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# create an internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
    cidr_block = "0.0.0.0/0" # we want all traffic to route to the internet gateway
    gateway_id = aws_internet_gateway.gw.id
  }
  # route for ipv6
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod-route-table"
  }
}

# create a subnet
resource "aws_subnet" "prod-subnet" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# associate the route table with the subnet
resource "aws_route_table_association" "prod-subnet-route-table-association" {
  subnet_id = aws_subnet.prod-subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

# create a security group to allow port 22, 80, 443
resource "aws_security_group" "prod-sg" {
  vpc_id = aws_vpc.prod-vpc.id
  description = "Allow all inbound traffic"
  name = "allow web traffic"

  ingress {
    description = "HTTPS from VPC"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH into VPC"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  // create a tag allow_web
  tags = {
    Name = "allow_web"
  }
}

#7. Creat a network interface with an ip in the subnet
resource "aws_network_interface" "prod-eni" {
  subnet_id = aws_subnet.prod-subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.prod-sg.id]

}

#8. Assign an elastic ip to the network interface in step 7
resource "aws_eip" "prod-eip" {
  vpc = true
  network_interface = aws_network_interface.prod-eni.id
  associate_with_private_ip = "10.0.1.50" 
  depends_on = [aws_internet_gateway.gw] # this could be a list of dependencies e.g internet gateway, vpc, subnet 
}

#9. Create an ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a" # set the availability zone to the same as the subnet
  key_name = "aws-key-pair"
  # subnet_id = aws_subnet.prod-subnet.id
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.prod-eni.id
  }
  user_data = <<-EOF
          #!/bin/bash
          sudo apt update -y 
          sudo apt install apache2 -y
          sudo systemctl start apache2
          echo "<h1>deployed by Terraform</h1>" >> /var/www/html/index.html
          EOF
  # vpc_security_group_ids = [aws_security_group.prod-sg.id]
  tags = {
    Name = "prod-instance"
  }
}
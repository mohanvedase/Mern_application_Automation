# Create a vpc
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "myterraformvpc"
  }
}
# Create a public subnet in "myterraformvpc"
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

}

# Create a private subnet in "myterraformvpc"
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

}

#create a internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  #vpc = true
  domain = "vpc"
}
#create a nat gateway
resource "aws_nat_gateway" "pub_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id  = aws_subnet.public_subnet.id
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "pri_nat" {
  #allocation_id = aws_eip.nat_eip.id
  connectivity_type = "private"
  subnet_id         = aws_subnet.private_subnet.id
}

#create a route table for public subnet
resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

}

resource "aws_route_table" "privateRT" {
  vpc_id = aws_vpc.myvpc.id
}

# associate Route tables with Subnets
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.publicRT.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.privateRT.id
}


# Security groups
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.myvpc.id
  name   = "public_sg"

  # Allow SSH and HTTP from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.29.20/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.myvpc.id
  name   = "private_sg"

  # Allow SSH from public subnet
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  # Allow port 3000 for specific application access
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch instances
resource "aws_instance" "webserver" {
  ami             = "ami-03f4878755434977f"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.public_sg.id]
  tags = {
    Name = "webserver"
  }

  # Key pair for SSH access
  key_name = "terraform"
}

resource "aws_instance" "database" {
  ami             = "ami-03f4878755434977f"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.private_sg.id]
  tags = {
    Name = "database"
  }

  # Key pair for SSH access
  key_name = "terraform"
}

# Output public IP of the webserver EC2 instance
output "webserver_public_ip" {
  value = aws_instance.webserver.public_ip
}

# Output public IP of the database EC2 instance
output "database_public_ip" {
  value = aws_instance.database.public_ip
}
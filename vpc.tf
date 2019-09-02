### Network

# Fetch AZs in the current region
data "aws_availability_zones" "available" {
}


# Internet VPC
resource "aws_vpc" "ecs-vpc" {
  cidr_block           = "172.21.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags = {
    Name = "ecs-terraform"
  }
}

# Subnets
# Create var.az_count private subnets, each in a different AZ
resource "aws_subnet" "private" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.ecs-vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.ecs-vpc.id
  tags = {
   Type = "Public" 
  }	
}

# Create var.az_count public subnets, each in a different AZ
resource "aws_subnet" "public" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.ecs-vpc.cidr_block, 8, var.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.ecs-vpc.id
  map_public_ip_on_launch = true
   tags = {
    Type = "Private"
  }

}


# Internet GW
resource "aws_internet_gateway" "ecs-gw" {
  vpc_id = "${aws_vpc.ecs-vpc.id}"

  tags = {
    Name = "ECS-IG"
  }
}

# Create a NAT gateway with an Elastic IP for each private subnet to get internet connectivity
resource "aws_eip" "gw" {
 count      = var.az_count
  vpc        = true
  depends_on = [aws_internet_gateway.ecs-gw]
}

# nat gateway
resource "aws_nat_gateway" "nat_gw" {
  count         = var.az_count
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gw.*.id, count.index)
  tags = {
    Name = "gw NAT"
  }
}

# route tables
resource "aws_route_table" "ecs-public" {
  count  = var.az_count
  vpc_id = aws_vpc.ecs-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ecs-gw.id}"
  }

  tags = {
    Name = "PUBLIC-TABLE"
  }
}

# Create a new route table for the private subnets, make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "ecs-private" {
 count  = var.az_count
 vpc_id = aws_vpc.ecs-vpc.id  
 route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat_gw.*.id, count.index)  
 }
  
 tags = {
    Name = "PRIVATE-TABLE"
  }
}

# Explicitly associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "rta_subnet_private" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = element(aws_route_table.ecs-public.*.id, count.index)
}


# route associations public
resource "aws_route_table_association" "rta_subnet_public" {
count          = var.az_count
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.ecs-private.*.id, count.index)
}



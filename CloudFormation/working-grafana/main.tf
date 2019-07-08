provider "aws" {
  region = "us-east-2"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "grafana-tf-vpc" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    Name = "grafana-tf-vpc"
  }
}

resource "aws_subnet" "grafana-tf-pub-subnet-1" {
  cidr_block        = "10.50.0.0/24"
  vpc_id            = "${aws_vpc.grafana-tf-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "grafana-tf-subnet-1"
  }
}

resource "aws_subnet" "grafana-tf-pub-subnet-2" {
  cidr_block        = "10.50.1.0/24"
  vpc_id            = "${aws_vpc.grafana-tf-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "grafana-tf-subnet-2"
  }
}

resource "aws_subnet" "grafana-tf-pri-subnet-1" {
  cidr_block        = "10.50.64.0/19"
  vpc_id            = "${aws_vpc.grafana-tf-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "grafana-tf-pri-subnet-1"
  }
}

resource "aws_subnet" "grafana-tf-pri-subnet-2" {
  cidr_block        = "10.50.96.0/19"
  vpc_id            = "${aws_vpc.grafana-tf-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "grafana-tf-pri-subnet-2"
  }
}

resource "aws_internet_gateway" "grafana-tf-internet-gw" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"

  tags {
    Name = "grafana-tf-internet-gw"
  }
}

# https://github.com/terraform-providers/terraform-provider-aws/issues/5465
# resource "aws_ec2_transit_gateway_vpc_attachment" "grafana-gw-attachment" {
#   subnet_ids         = ["${aws_subnet.grafana-tf-pub-subnet-1.id}", "${aws_subnet.grafana-tf-pub-subnet-2.id}"]
#   vpc_id             = "${aws_vpc.grafana-tf-vpc.id}"
#   transit_gateway_id = "${aws_internet_gateway.grafana-tf-internet-gw.id}"
# }

resource "aws_route_table" "grafana-tf-rt" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"
}

resource "aws_route" "grafana-tf-pub-route" {
  route_table_id         = "${aws_route_table.grafana-tf-rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.grafana-tf-internet-gw.id}"
}

resource "aws_route_table_association" "grafana-tf-pub-assoc-1" {
  subnet_id      = "${aws_subnet.grafana-tf-pub-subnet-1.id}"
  route_table_id = "${aws_route_table.grafana-tf-rt.id}"
}

resource "aws_route_table_association" "grafana-tf-pub-assoc-2" {
  subnet_id      = "${aws_subnet.grafana-tf-pub-subnet-2.id}"
  route_table_id = "${aws_route_table.grafana-tf-rt.id}"
}

resource "aws_security_group" "grafana-tf-elb" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 80            #Change to variable
    to_port     = 80
  }

  tags {
    Name        = "grafana-tf-elb"
    description = "Enable http/https ingress"
  }
}

resource "aws_security_group" "grafana-tf-bastion" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"

  ingress {
    cidr_blocks = ["0.0.0.0/0"] # Change to variable
    protocol    = "tcp"
    from_port   = 22            #Change to variable
    to_port     = 22
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "udp"
    from_port   = 123
    to_port     = 123
  }

  tags {
    Name        = "grafana-tf-bastion"
    description = "Enable access to the bastion host"
  }
}

resource "aws_security_group" "grafana-tf-app" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"

  ingress {
    protocol        = "tcp"
    to_port         = 3000
    from_port       = 3000
    security_groups = ["${aws_security_group.grafana-tf-elb.id}"]
  }

  ingress {
    protocol        = "tcp"
    to_port         = 22
    from_port       = 22
    security_groups = ["${aws_security_group.grafana-tf-bastion.id}"]
  }

  egress {
    protocol  = "-1"
    to_port   = "0"
    from_port = "0"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "grafana-tf-app"
    description = "Enable access to the bastion host"
  }
}

resource "aws_security_group" "grafana-tf-db" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"

  egress = {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    to_port     = 3306
    from_port   = 3306
  }

  egress = {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    to_port     = 5432
    from_port   = 5432
  }

  tags {
    Name        = "grafana-tf-db"
    description = "Enable access to the RDS DB"
  }
}

# NAT-related resources
#
# NAT is used to allow instances in private subnets to communicate with AWS
# services, and pull down code and updates.

resource "aws_nat_gateway" "grafana-tf-nat-gw1" {
  allocation_id = "${aws_eip.grafana-tf-eip-1.id}"
  subnet_id     = "${aws_subnet.grafana-tf-pub-subnet-1.id}"
  depends_on    = ["aws_internet_gateway.grafana-tf-internet-gw"]
}

resource "aws_nat_gateway" "grafana-tf-nat-gw2" {
  allocation_id = "${aws_eip.grafana-tf-eip-2.id}"
  subnet_id     = "${aws_subnet.grafana-tf-pub-subnet-2.id}"
  depends_on    = ["aws_internet_gateway.grafana-tf-internet-gw"]
}

resource "aws_eip" "grafana-tf-eip-1" {
  depends_on = ["aws_internet_gateway.grafana-tf-internet-gw"]
  vpc        = true
}

resource "aws_eip" "grafana-tf-eip-2" {
  depends_on = ["aws_internet_gateway.grafana-tf-internet-gw"]
  vpc        = true
}

resource "aws_route_table" "grafana-tf-nat-rt-1" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"

  tags {
    Name = "grafana-tf-private-nat-1"
  }
}

resource "aws_route_table" "grafana-tf-nat-rt-2" {
  vpc_id = "${aws_vpc.grafana-tf-vpc.id}"

  tags {
    Name = "grafana-tf-private-nat-2"
  }
}

resource "aws_route" "grafana-tf-route-1" {
  route_table_id         = "${aws_route_table.grafana-tf-nat-rt-1.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.grafana-tf-nat-gw1.id}"
}

resource "aws_route" "grafana-tf-route-2" {
  route_table_id         = "${aws_route_table.grafana-tf-nat-rt-2.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.grafana-tf-nat-gw2.id}"
}

resource "aws_route_table_association" "grafana-tf-private-subnet-rt-assoc-1" {
  subnet_id      = "${aws_subnet.grafana-tf-pri-subnet-1.id}"
  route_table_id = "${aws_route_table.grafana-tf-nat-rt-1.id}"
}

resource "aws_route_table_association" "grafana-tf-private-subnet-rt-assoc-2" {
  subnet_id      = "${aws_subnet.grafana-tf-pri-subnet-2.id}"
  route_table_id = "${aws_route_table.grafana-tf-nat-rt-2.id}"
}

# Not sure if needed?
# resource "aws_route_table_association" "grafana-tf-private-subnet-rt-single-nat-gw" {
#   subnet_id      = "${aws_subnet.grafana-tf-pri-subnet-2.id}"
#   route_table_id = "${aws_route_table.grafana-tf-nat-rt-1.id}"
# }

# wtf is this for
resource "aws_security_group_rule" "grafana-tf-bastion-elb-egress" {
  type                     = "egress"
  security_group_id        = "${aws_security_group.grafana-tf-elb.id}"
  source_security_group_id = "${aws_security_group.grafana-tf-bastion.id}"
  protocol                 = "tcp"
  to_port                  = 3000                                          #Change to variable
  from_port                = 3000
}

resource "aws_security_group_rule" "grafana-tf-bastion-db-igress" {
  type = "ingress"

  security_group_id        = "${aws_security_group.grafana-tf-db.id}"
  source_security_group_id = "${aws_security_group.grafana-tf-bastion.id}"
  protocol                 = "tcp"
  to_port                  = 5432                                          #Change to variable
  from_port                = 3306
}

resource "aws_security_group_rule" "grafana-tf-app-db-ingress" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.grafana-tf-db.id}"
  source_security_group_id = "${aws_security_group.grafana-tf-app.id}"
  protocol                 = "tcp"
  to_port                  = 5432                                      #Change to variable
  from_port                = 3306
}


resource "aws_security_group_rule" "grafana-tf-bastion-app-egress" {
  type                     = "egress"
  security_group_id        = "${aws_security_group.grafana-tf-bastion.id}"
  source_security_group_id = "${aws_security_group.grafana-tf-app.id}"
  protocol                 = "tcp"
  to_port                  = 22                                      #Change to variable
  from_port                = 22
}


resource "aws_security_group_rule" "grafana-tf-bastion-db-egress" {
  type                     = "egress"
  security_group_id        = "${aws_security_group.grafana-tf-bastion.id}"
  source_security_group_id = "${aws_security_group.grafana-tf-db.id}"
  protocol                 = "tcp"
  to_port                  = 5432                                      #Change to variable
  from_port                = 3306
}
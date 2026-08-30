terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
provider "aws" { region = var.aws_region }
data "aws_availability_zones" "available" { state = "available" }
data "aws_ssm_parameter" "al2023" { name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }
locals { azs = slice(data.aws_availability_zones.available.names, 0, 2) }
resource "aws_vpc" "this" { cidr_block = "10.42.0.0/16"; enable_dns_support = true; enable_dns_hostnames = true; tags = { Name = "prod-arch-ch02" } }
resource "aws_internet_gateway" "this" { vpc_id = aws_vpc.this.id }
resource "aws_subnet" "public" { count = 2; vpc_id = aws_vpc.this.id; availability_zone = local.azs[count.index]; cidr_block = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index); map_public_ip_on_launch = true }
resource "aws_subnet" "app" { count = 2; vpc_id = aws_vpc.this.id; availability_zone = local.azs[count.index]; cidr_block = cidrsubnet(aws_vpc.this.cidr_block, 8, 10 + count.index) }
resource "aws_subnet" "db" { count = 2; vpc_id = aws_vpc.this.id; availability_zone = local.azs[count.index]; cidr_block = cidrsubnet(aws_vpc.this.cidr_block, 8, 20 + count.index) }
resource "aws_route_table" "public" { vpc_id = aws_vpc.this.id; route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.this.id } }
resource "aws_route_table_association" "public" { count = 2; subnet_id = aws_subnet.public[count.index].id; route_table_id = aws_route_table.public.id }
resource "aws_eip" "nat" { count = 2; domain = "vpc"; depends_on = [aws_internet_gateway.this] }
resource "aws_nat_gateway" "this" { count = 2; allocation_id = aws_eip.nat[count.index].id; subnet_id = aws_subnet.public[count.index].id }
resource "aws_route_table" "app" { count = 2; vpc_id = aws_vpc.this.id; route { cidr_block = "0.0.0.0/0"; nat_gateway_id = aws_nat_gateway.this[count.index].id } }
resource "aws_route_table_association" "app" { count = 2; subnet_id = aws_subnet.app[count.index].id; route_table_id = aws_route_table.app[count.index].id }
resource "aws_security_group" "alb" { vpc_id = aws_vpc.this.id; ingress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }; egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] } }
resource "aws_security_group" "app" { vpc_id = aws_vpc.this.id; ingress { from_port = 80; to_port = 80; protocol = "tcp"; security_groups = [aws_security_group.alb.id] }; egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] } }
resource "aws_security_group" "db" { vpc_id = aws_vpc.this.id; ingress { from_port = 5432; to_port = 5432; protocol = "tcp"; security_groups = [aws_security_group.app.id] } }
resource "aws_lb" "this" { name = "prod-arch-ch02"; load_balancer_type = "application"; subnets = aws_subnet.public[*].id; security_groups = [aws_security_group.alb.id] }
resource "aws_lb_target_group" "app" { name = "prod-arch-ch02"; port = 80; protocol = "HTTP"; vpc_id = aws_vpc.this.id; health_check { path = "/" } }
resource "aws_lb_listener" "http" { load_balancer_arn = aws_lb.this.arn; port = 80; protocol = "HTTP"; default_action { type = "forward"; target_group_arn = aws_lb_target_group.app.arn } }
resource "aws_launch_template" "app" { name_prefix = "prod-arch-ch02-"; image_id = data.aws_ssm_parameter.al2023.value; instance_type = var.instance_type; vpc_security_group_ids = [aws_security_group.app.id]; user_data = base64encode("#!/bin/bash\ndnf install -y nginx\necho '<h1>AWS Production Architecture 02</h1>' > /usr/share/nginx/html/index.html\nsystemctl enable --now nginx\n") }
resource "aws_autoscaling_group" "app" { min_size = 2; desired_capacity = 2; max_size = 4; vpc_zone_identifier = aws_subnet.app[*].id; target_group_arns = [aws_lb_target_group.app.arn]; health_check_type = "ELB"; launch_template { id = aws_launch_template.app.id; version = "$Latest" } }
resource "aws_db_subnet_group" "this" { name = "prod-arch-ch02"; subnet_ids = aws_subnet.db[*].id }
resource "random_password" "db" { length = 24; special = true; override_special = "!#$%&*+-=?" }
resource "aws_db_instance" "this" { identifier = "prod-arch-ch02"; engine = "postgres"; instance_class = var.db_instance_class; allocated_storage = 20; storage_type = "gp3"; db_name = "architecture"; username = "archadmin"; password = random_password.db.result; multi_az = true; publicly_accessible = false; db_subnet_group_name = aws_db_subnet_group.this.name; vpc_security_group_ids = [aws_security_group.db.id]; storage_encrypted = true; backup_retention_period = 7; skip_final_snapshot = true }
variable "aws_region" { type = string; default = "us-east-1" }
variable "instance_type" { type = string; default = "t3.micro" }
variable "db_instance_class" { type = string; default = "db.t4g.micro" }
output "alb_url" { value = "http://${aws_lb.this.dns_name}" }
output "rds_endpoint" { value = aws_db_instance.this.endpoint }
output "db_password" { value = random_password.db.result; sensitive = true }

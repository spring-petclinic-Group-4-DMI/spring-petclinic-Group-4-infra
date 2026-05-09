output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main_vpc.id
}
output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main_vpc.cidr_block
}
output "public_subnet_ids" {
  description = "List of public subnet IDs [az1, az2]"
  value       = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
}
output "private_subnet_ids" {
  description = "List of private subnet IDs [az1, az2]"
  value       = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
}
output "public_subnet_az1_id" {
  description = "Public subnet ID in us-east-1a"
  value       = aws_subnet.public_az1.id
}
output "public_subnet_az2_id" {
  description = "Public subnet ID in us-east-1b"
  value       = aws_subnet.public_az2.id
}
output "private_subnet_az1_id" {
  description = "Private subnet ID in us-east-1a"
  value       = aws_subnet.private_az1.id
}
output "private_subnet_az2_id" {
  description = "Private subnet ID in us-east-1b"
  value       = aws_subnet.private_az2.id
}
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}
output "eks_node_sg_id" {
  description = "Security group ID for EKS nodes"
  value       = aws_security_group.eks_nodes_sg.id
}
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main_igw.id
}
output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main_nat.id
}

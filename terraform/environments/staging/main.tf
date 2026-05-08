
# ── RDS MySQL Module — Amarachi (SPC-39) ─────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  allowed_security_group_id = module.eks.node_security_group_id
  db_name                   = var.db_name
  db_username               = var.mysql_username
  db_password               = var.mysql_password
  db_instance_class         = var.db_instance_class
  allocated_storage         = var.db_allocated_storage
  common_tags               = local.common_tags
}

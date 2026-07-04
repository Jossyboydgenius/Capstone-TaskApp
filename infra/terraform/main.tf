module "network" {
  source            = "./modules/network"
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone
  env               = var.env
}

module "security_group" {
  source   = "./modules/security_group"
  vpc_id   = module.network.vpc_id
  env      = var.env
  admin_ip = var.admin_ip
}

module "compute" {
  source            = "./modules/compute"
  public_subnet_id  = module.network.public_subnet_id
  security_group_id = module.security_group.security_group_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  ami_id            = var.ami_id
  env               = var.env
  agent_count       = var.agent_count
}

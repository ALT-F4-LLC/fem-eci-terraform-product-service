module "service" {
  for_each = local.services

  source = "./module/ecs-service"

  cluster_name = var.cluster_name
  environment  = var.environment
  name         = "service"
  parameters   = each.value.parameters
}

moved {
  from = module.service
  to   = module.service["service"]
}

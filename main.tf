module "service" {
  source = "./module/ecs-service"

  cluster_name = var.cluster_name
  environment  = var.environment
  name         = "service"

  parameters = [
    "fem-instructor",
    "fem-location",
    "fem-version"
  ]
}

module "parameter" {
  for_each = { for item in var.parameters : item => item }

  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "1.1.0"

  ignore_value_changes = true
  name                 = "/${var.name}-${var.environment}/${each.key}"
  value                = "example"
}

module "parameter_secure" {
  for_each = { for item in var.parameters_secure : item => item }

  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "1.1.0"

  ignore_value_changes = true
  name                 = "/${var.name}-${var.environment}/${each.key}"
  secure_type          = true
  value                = "example"
}

resource "aws_kms_key" "this" {
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "this" {
  name_prefix       = "${var.name}-${var.environment}-"
  retention_in_days = var.log_retention
}

resource "aws_kms_key_policy" "this" {
  key_id = aws_kms_key.this.id
  policy = data.aws_iam_policy_document.kms_policy.json
}

resource "aws_iam_role" "execution" {
  assume_role_policy = data.aws_iam_policy_document.execution_assume_role.json
  name_prefix        = "${var.name}-execution-${var.environment}-"
}

resource "aws_iam_policy" "execution_policy" {
  name_prefix = "${var.name}-execution-${var.environment}-"
  policy      = data.aws_iam_policy_document.execution_policy.json
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution_policy.arn
}

resource "aws_iam_role_policy_attachment" "execution_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.execution.name
}

resource "aws_iam_role_policy_attachment" "execution_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.execution.name
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name             = "fem-eci-${var.name}"
  repository_read_access_arns = [aws_iam_role.execution.arn]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["prod"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_iam_role" "task" {
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
  name_prefix        = "${var.name}-task-${var.environment}-"
}

resource "aws_ecs_task_definition" "this" {
  execution_role_arn = aws_iam_role.execution.arn
  family             = "${var.name}-${var.environment}"
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      cpu          = 256
      essential    = true
      image        = var.image
      memory       = 512
      name         = "service"
      portMappings = [{ containerPort = var.port }]

      environment = []

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      secrets = concat(
        [
          for item in var.parameters : {
            name      = upper(replace(item, "-", "_"))
            valueFrom = module.parameter[item].ssm_parameter_arn
          }
        ],
        [
          for item in var.parameters_secure : {
            name      = upper(replace(item, "-", "_"))
            valueFrom = module.parameter_secure[item].ssm_parameter_arn
          }
        ]
      )
    },
  ])
}

resource "aws_iam_role" "service" {
  assume_role_policy = data.aws_iam_policy_document.service_assume_role.json
  name_prefix        = "${var.name}-service-${var.environment}-"
}

resource "aws_iam_role_policy_attachment" "service" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
  role       = aws_iam_role.service.name
}

resource "aws_ecs_service" "this" {
  cluster         = data.aws_ecs_cluster.this.id
  desired_count   = 1
  iam_role        = aws_iam_role.service.arn
  name            = "${var.name}-${var.environment}"
  task_definition = aws_ecs_task_definition.this.arn

  load_balancer {
    container_name   = "service"
    container_port   = var.port
    target_group_arn = data.aws_lb_target_group.this.arn
  }

  capacity_provider_strategy {
    base              = 1
    capacity_provider = var.cluster_name
    weight            = 100
  }

  depends_on = [
    aws_iam_role_policy_attachment.service,
  ]
}

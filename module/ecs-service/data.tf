data "aws_caller_identity" "this" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.cluster_name
}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    actions = [
      "kms:*",
    ]

    principals {
      identifiers = [data.aws_caller_identity.this.arn]
      type        = "AWS"
    }

    resources = ["*"]
  }

  statement {
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [aws_cloudwatch_log_group.this.arn]
    }

    principals {
      identifiers = ["logs.us-west-2.amazonaws.com"]
      type        = "Service"
    }

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "execution_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "execution_policy" {
  statement {
    actions = ["ssm:GetParameters"]
    resources = concat(
      [for item in var.parameters : module.parameter[item].ssm_parameter_arn],
      [for item in var.parameters_secure : module.parameter_secure[item].ssm_parameter_arn]
    )
  }
}

data "aws_iam_policy_document" "task_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "service_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = ["ecs.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_lb_target_group" "this" {
  tags = {
    Cluster = var.cluster_name
    Name    = "fem-eci-service-${var.environment}"
  }
}

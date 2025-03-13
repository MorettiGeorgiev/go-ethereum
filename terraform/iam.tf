resource "aws_iam_role" "eks_pod_role" {
  name = "eks-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:${var.namespace}:${var.app_name}-sa"
        }
      }
    }]
  })
}
resource "aws_iam_policy" "ecr_pull_policy" {
  name = "ECRFullAccessPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:*"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull_attach" {
  role       = aws_iam_role.eks_pod_role.name
  policy_arn = aws_iam_policy.ecr_pull_policy.arn
}

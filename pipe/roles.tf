# Role para o CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "CLD34-devops-final-CodePipeline-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "codepipeline_policy" {
  name       = "attach-codepipeline-policy"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

# Role para o CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "CLD34-devops-final-CodeBuild-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "codebuild_policy" {
  name       = "attach-codebuild-policy"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_s3_bucket_policy" "pipeline_bucket_policy" {
  bucket = aws_s3_bucket.pipeline_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCodePipelineAccess",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::185983175555:role/CLD34-devops-final-CodePipeline-Role"
        },
        Action    = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource  = [
          "${aws_s3_bucket.pipeline_bucket.arn}",
          "${aws_s3_bucket.pipeline_bucket.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy" "codepipeline_codebuild_policy" {
  name = "CodePipelineCodeBuildPolicy"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
          "codebuild:BatchGetProjects",
          "codebuild:ListBuildsForProject"
        ],
        Resource = "arn:aws:codebuild:us-east-1:185983175555:project/CLD34-devops-final-Build"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "CodeBuildS3AccessPolicy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::cld34-terraform-state-bucket",
          "arn:aws:s3:::cld34-terraform-state-bucket/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem"
        ],
        Resource = "arn:aws:dynamodb:us-east-1:185983175555:table/terraform-lock-table"
      },
      {
        Effect   = "Allow",
        Action   = [
          "ec2:DescribeInstances",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_logging_policy" {
  name = "CodeBuildLoggingPolicy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = [
          "arn:aws:logs:us-east-1:185983175555:log-group:/aws/codebuild/*",
          "arn:aws:logs:us-east-1:185983175555:log-group:/aws/codebuild/*:log-stream:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_s3_policy" {
  name = "CodeBuildS3Policy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::cld34-devops-final-pipeline-bucket",           # Permissão para listar o bucket
          "arn:aws:s3:::cld34-devops-final-pipeline-bucket/*"         # Permissão para acessar objetos específicos
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_ecr_policy" {
  name = "CodeBuildECRPolicy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:CreateRepository"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_codebuild_project" "build" {
  name          = "CLD34-devops-final-Build"
  service_role  = aws_iam_role.codebuild_role.arn

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "S3"
    location  = "arn:aws:s3:::cld34-devops-final-pipeline-bucket/buildspec.yml"
  }

  artifacts {
    type                = "S3"
    location            = "cld34-devops-final-pipeline-bucket"  # Nome do bucket S3
    path                = "artifacts"                          # Subpasta no bucket
    packaging           = "ZIP"                                # Opcional: compactar os artefatos
    override_artifact_name = true                              # Permite nome personalizado
    artifact_identifier = "build-output"                       # Identificador opcional
  }
}

resource "aws_iam_role_policy" "codebuild_ec2_policy" {
  name = "CodeBuildEC2AccessPolicy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_ecs_policy" {
  name = "CodeBuildECSAccessPolicy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:TagResource",
          "ecs:UntagResource",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:UpdateClusterSettings",
          "ecs:PutClusterCapacityProviders",
          "ecs:CreateService",
          "ecs:DeleteService",
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:ListServices"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "codedeploy_role" {
  name = "CLD34-devops-final-CodeDeploy-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "codedeploy.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_iam_policy" {
  name = "CodeBuildIAMAccessPolicy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:ListEntitiesForPolicy",
          "iam:GetPolicy",
          "iam:PutRolePolicy",
          "iam:GetRole",
          "iam:DeleteRole",
          "iam:ListRolePolicies",
          "iam:DeleteRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:ListInstanceProfilesForRole"
        ],
        Resource = [
          "arn:aws:iam::185983175555:role/CLD34-devops-final-ECS-Instance-Role",
          "arn:aws:iam::185983175555:role/*",
          "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
          "arn:aws:iam::185983175555:instance-profile/CLD34-devops-final-ECS-Instance-Profile"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "iam:GetInstanceProfile"
        ],
        Resource = "arn:aws:iam::185983175555:instance-profile/CLD34-devops-final-ECS-Instance-Profile"
      }
    ]
  })
}


resource "aws_iam_policy" "codedeploy_ecs_policy" {
  name        = "CodeDeployECSAccessPolicy"
  description = "Permissões para CodeDeploy acessar ECS e ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListServices",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "attach_codedeploy_ecs_policy" {
  name       = "codedeploy-ecs-policy-attachment"
  roles      = [aws_iam_role.codedeploy_role.name]
  policy_arn = aws_iam_policy.codedeploy_ecs_policy.arn
}

resource "aws_iam_policy_attachment" "codepipeline_codedeploy_access" {
  name       = "codepipeline-codedeploy-access"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
}


resource "aws_iam_policy_attachment" "codepipeline_ecs_policy" {
  name       = "codepipeline-ecs-policy"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
}

resource "aws_iam_policy_attachment" "codepipeline_ecs_policy_attach" {
  name       = "attach-codepipeline-ecs-policy"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = aws_iam_policy.codedeploy_ecs_policy.arn
}

resource "aws_iam_role_policy" "codebuild_autoscaling_policy" {
  name = "CodeBuildAutoscalingPolicy"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DescribeScalingPolicies",
          "application-autoscaling:ListTagsForResource",
          "application-autoscaling:DeregisterScalableTarget"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
      }
    ]
  })
}
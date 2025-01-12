resource "aws_codebuild_project" "build_project" {
  name         = "CLD34-devops-final-Build"
  service_role = aws_iam_role.codebuild_role.arn

  source {
    type = "CODEPIPELINE"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
  }
}

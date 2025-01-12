
resource "aws_codepipeline" "pipeline" {
  name     = "CLD34-devops-final-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline_bucket.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "marceloflcruz"
        Repo       = "fiap-34cld-cicd"
        Branch     = "main"
        OAuthToken = var.github_oauth_token 
      }
    }

  }

  stage {
    name = "Build"

    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "ECS_Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      version          = "1"
      input_artifacts  = ["build_output"]

      configuration = {
        ClusterName = "CLD34-devops-final-ECS-Cluster"
        ServiceName = "CLD34-devops-final-service"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

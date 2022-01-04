provider "aws" {
    region = "ap-south-1"
}

// Create S3 Bucket for artifacts
resource "aws_s3_bucket" "tf-codepipeline-test" {
  bucket = "tf-codepipeline-test"
  acl    = "private"
}
// Create GitHub connection for Source Code
resource "aws_codestarconnections_connection" "tf_codestart_con" {
  name          = "tf_connection"
  provider_type = "GitHub"
}

// Create CodeBuild Resource
resource "aws_codebuild_project" "react-aws-codebuild" {
  name = "react-aws-codebuild"
  description = "react-aws-codebuild"
  build_timeout = "5"
  service_role = aws_iam_role.codepipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/standard:5.0"
    type = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODEPIPELINE"
  }
}

// Create CodeDeploy Resource
resource "aws_codedeploy_app" "codedeploy-app" {
  name = "codedeploy-app"
}

resource "aws_codedeploy_deployment_group" "codedeploy-deployment-group" {
  app_name              = aws_codedeploy_app.codedeploy-app.name
  deployment_group_name = "codedeploy-deployment-group"
  service_role_arn      = aws_iam_role.codepipeline_role.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "CodeDeploy"
    	}
    }
 }
 
// Create CodePipeline for CI/CD
resource "aws_codepipeline" "tf-codepipeline" {
  name     = "tf-test-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.tf-codepipeline-test.bucket
    type     = "S3"
  }
 //stages for CodePipeline

  stage {
    name = "stg_source_code"
    action {
      name = "Source"
      category = "Source"
      owner = "AWS"
      provider = "CodeStarSourceConnection"
      version = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn = aws_codestarconnections_connection.tf_codestart_con.arn
        FullRepositoryId = "divyadima25/reactjs-codedeploy"
        BranchName = "main" 
      }
    }
  }

  stage {
    name = "stg_build"

    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = "react-aws-codebuild"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName = "codedeploy-app"
        DeploymentGroupName = "codedeploy-deployment-group"
        
       }
    }
  }
}
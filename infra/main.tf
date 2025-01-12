provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "cld34-terraform-state-bucket"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "CLD34-devops-final-VPC"
  }
}

# Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "CLD34-devops-final-Subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "CLD34-devops-final-Internet-Gateway"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "CLD34-devops-final-Route-Table"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "CLD34-devops-final-SG"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "CLD34-devops-final-SG"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "CLD34-devops-final-ECS-Cluster"
  tags = {
    Environment = "DevOps"
  }
}

# EC2 Instance for ECS
resource "aws_instance" "ecs_instance" {
  ami           = "ami-00510a0be518b7bcf"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id

  iam_instance_profile = aws_iam_instance_profile.ecs_profile.name
  vpc_security_group_ids = [aws_security_group.ecs_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=CLD34-devops-final-ECS-Cluster >> /etc/ecs/ecs.config
  EOF

  tags = {
    Name = "CLD34-devops-final-ECS-Node"
  }
}

# IAM Role for ECS
resource "aws_iam_role" "ecs_role" {
  name = "CLD34-devops-final-ECS-Instance-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_instance_policy" {
  name       = "ecs-instance-policy"
  roles      = [aws_iam_role.ecs_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_profile" {
  name = "CLD34-devops-final-ECS-Instance-Profile"
  role = aws_iam_role.ecs_role.name
}

resource "aws_ecr_repository" "demo_repo" {
  name = "cld34-devops-repo"
  tags = {
    Environment = "DevOps"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "CLD34-devops-final-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "128"
  memory                   = "256"

  container_definitions = jsonencode([
    {
      name      = "app-container"
      image     = "${aws_ecr_repository.demo_repo.repository_url}:latest"
      cpu       = 128
      memory    = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = "CLD34-devops-final-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  deployment_minimum_healthy_percent = 0 
  deployment_maximum_percent         = 100
  launch_type     = "EC2"
}

resource "aws_appautoscaling_target" "ecs_scaling_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 0 # O serviço nunca terá menos de 1 tarefa
  max_capacity       = 1 # O serviço pode escalar até 2 tarefas
}

resource "aws_appautoscaling_policy" "scale_up" {
  name               = "scale-up-policy"
  policy_type        = "TargetTrackingScaling" # Tipo de política deve ser TargetTrackingScaling
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  target_tracking_scaling_policy_configuration {
    target_value       = 50.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "scale_down" {
  name               = "scale-down-policy"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  target_tracking_scaling_policy_configuration {
    target_value       = 30.0 # Meta: reduzir se a CPU média estiver abaixo de 30%
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120 # Aguarda 120 segundos antes de reduzir tarefas
    scale_out_cooldown = 60  # Tempo de espera ao escalar para cima (pode ser diferente do scale_up)
  }
}


# Output for ECS Cluster
output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}

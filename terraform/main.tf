# terraform/main.tf

provider "aws" {
  region = "ap-south-1" # Replace with your preferred AWS region (e.g., us-east-1)
}

# 1. VPC, Subnets, Security Groups
resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "app-vpc"
  }
}

resource "aws_subnet" "public_subnet_az1" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a" # Replace with your AZ
  map_public_ip_on_launch = true # Required for public subnets with NAT Gateway/Internet Gateway

  tags = {
    Name = "public-subnet-az1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b" # Replace with your AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-az2"
  }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "app-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for ALB (allow HTTP/HTTPS from anywhere)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "alb-sg"
  }
}

# Security Group for ECS Tasks (allow traffic from ALB, allow egress to internet)
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "ecs-tasks-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port       = 0 # All ports for simplicity for now, refine later
    to_port         = 65535
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sg.id] # Only allow traffic from ALB SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow tasks to reach internet (e.g., for pulling images)
  }

  tags = {
    Name = "ecs-tasks-sg"
  }
}

# 2. ECS Cluster + Fargate Services
resource "aws_ecs_cluster" "app_cluster" {
  name = "my-app-cluster"

  tags = {
    Name = "my-app-cluster"
  }
}

# IAM Role for ECS Task Execution (for pulling images, logging)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Tasks (application-specific permissions, e.g., Secrets Manager)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# Attach a policy to allow reading secrets from Secrets Manager
resource "aws_iam_role_policy" "ecs_task_secret_access_policy" {
  name = "ecsTaskSecretAccessPolicy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict this to specific secret ARNs later for least privilege
      },
    ]
  })
}


# Backend Task Definition
resource "aws_ecs_task_definition" "backend_task" {
  family                   = "backend-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn # Attach the task role

  container_definitions = jsonencode([
    {
      name        = "backend"
      image       = var.backend_image_uri # This will be passed from GitHub Actions
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/backend"
          "awslogs-region"        = "ap-south-1" # Your region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # environment = [ # Example for secrets
      #   {
      #     name = "DATABASE_URL"
      #     valueFrom = "arn:aws:secretsmanager:ap-south-1:YOUR_AWS_ACCOUNT_ID:secret:my-db-secret:db_url::"
      #   }
      # ]
    }
  ])
}

# Frontend Task Definition
resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "frontend-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn # Attach the task role

  container_definitions = jsonencode([
    {
      name        = "frontend"
      image       = var.frontend_image_uri # This will be passed from GitHub Actions
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ],
      environment = [
        # IMPORTANT: This needs to point to the *internal* DNS name of the backend service in ECS
        {
          name = "NEXT_PUBLIC_BACKEND_URL"
          value = "http://${aws_ecs_service.backend_service.name}:5000" # Frontend talks to backend service
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/frontend"
          "awslogs-region"        = "ap-south-1" # Your region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# 3. Application Load Balancer (ALB)
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id] # ALB needs at least 2 subnets

  tags = {
    Name = "app-alb"
  }
}

resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id
  target_type = "ip" # Fargate uses IP-based targeting

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "backend-tg"
  }
}

resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id
  target_type = "ip"

  health_check {
    path                = "/" # Next.js serves on /
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "frontend-tg"
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response" # Default action if no rules match
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Listener Rule for Backend API
resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 100 # Lower number means higher priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/health"] # Any path starting with /api or /health goes to backend
    }
  }
}

# Listener Rule for Frontend
resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 10 # Higher priority for frontend as it's the main entry point

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/*"] # All other traffic goes to frontend
      # NOTE: The order of rules matters. Frontend rule should be lower priority (higher number)
      # than specific backend rules if paths overlap. Or frontend could be default.
      # Here, the more specific backend rules will take precedence.
    }
  }
}

# ECS Services
resource "aws_ecs_service" "backend_service" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  desired_count   = 2 # Start with 2 instances for load balancing demonstration
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
    security_groups = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true # Fargate needs public IP if in public subnet without NAT GW
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend"
    container_port   = 5000
  }

  tags = {
    Name = "backend-service"
  }
}

resource "aws_ecs_service" "frontend_service" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  desired_count   = 2 # Start with 2 instances for load balancing demonstration
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
    security_groups = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  depends_on = [aws_ecs_service.backend_service] # Ensure backend service is up first

  tags = {
    Name = "frontend-service"
  }
}

# 4. Secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "example_secret" {
  name = "my-app/db-credentials" # Use a descriptive name
  description = "Database credentials for my application"
}

resource "aws_secretsmanager_secret_version" "example_secret_version" {
  secret_id     = aws_secretsmanager_secret.example_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = "supersecretpassword"
    db_name  = "mydb"
    host     = "my-db-instance.rds.amazonaws.com" # Placeholder
  })
}

# Example of how you would reference a secret in a task definition
# Go back to task definition and uncomment environment variables section
# with valueFrom: "arn:aws:secretsmanager:ap-south-1:YOUR_AWS_ACCOUNT_ID:secret:my-app/db-credentials:db_url::"
# Replace YOUR_AWS_ACCOUNT_ID with your actual AWS account ID.

# Outputs
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}
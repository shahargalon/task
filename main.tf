module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = var.bucket_name
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}

resource "aws_s3_object" "index_html" {
  bucket = module.s3_bucket.s3_bucket_id
  key    = "index.html"
  source = "index.html"
  acl    = "private"
}


resource "aws_iam_policy" "ec2_s3_policy" {
  name        = "ec2_s3_access_policy"
  description = "Allow EC2 instances to access the private S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject"]
      Effect   = "Allow"
      Resource = "${module.s3_bucket.s3_bucket_arn}/*"
    }]
  })
}

#Create a security group allowing HTTP access
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow HTTP access"
  vpc_id      = var.vpc_id
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
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = var.instance_name

  instance_type = var.instance_type
  # key_name               = "user1"
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  subnet_id                   = var.subnet_id
  create_iam_instance_profile = true

  iam_role_policies = {
    s3  = aws_iam_policy.ec2_s3_policy.arn
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  user_data = <<-EOF
              #!/bin/bash
              # Update the system
              yum update -y

              # Install Nginx and AWS CLI
              amazon-linux-extras install nginx1 -y

              # Start and enable the Nginx service
              systemctl start nginx
              systemctl enable nginx

              # Create a directory for the S3 file
              mkdir -p /var/www/html

              # Download the index.html file from S3
              aws s3 cp s3://${module.s3_bucket.s3_bucket_id}/index.html /usr/share/nginx/html/index.html

              # Restart Nginx to apply the changes
              systemctl restart nginx
              EOF

  tags = {
    Terraform = "true"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.12.0"

  name    = var.alb_name
  vpc_id  = var.vpc_id
  subnets = var.alb_subnets

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
    security_group_egress_rules = {
      all = {
        ip_protocol = "-1"
        cidr_ipv4   = "10.0.0.0/16"
      }
    }


    listeners = {
      http = {
        port     = 80
        protocol = "HTTP"
        forward = {
          target_group_key = "ex-instance"
        }
      }
    }

    target_groups = {
      ex-instance = {
        name_prefix = "nginx"
        protocol    = "HTTP"
        port        = 80
        target_type = "instance"
        target_id   = module.ec2_instance.id
      }
    }

    tags = {
      terraform = "true"
    }
  }

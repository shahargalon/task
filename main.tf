module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = var.bucket_name
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"
  attach_policy            = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = ["s3:GetObject"]
      Principal = "*"
      Effect    = "Allow"
      Resource  = "arn:aws:s3:::${var.bucket_name}/*"
      Condition = {
        "StringEquals" = {
          "aws:SourceVpce" = var.s3_endpointID
        }
      }
    }]
  })

  versioning = {
    enabled = true
  }
}

resource "aws_s3_object" "index_html" {
  bucket = module.s3_bucket.s3_bucket_id
  key    = "index.html"
  content = file("index.html")
  acl    = "private"
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
              cat > /etc/nginx/nginx.conf <<EOFILE
              user nginx;
              worker_processes auto;
              error_log /var/log/nginx/error.log;
              pid /run/nginx.pid;

              include /usr/share/nginx/modules/*.conf;

              events {
                  worker_connections 1024;
              }

              http {
                  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                                    '$status $body_bytes_sent "$http_referer" '
                                    '"$http_user_agent" "$http_x_forwarded_for"';

                  access_log  /var/log/nginx/access.log  main;

                  sendfile            on;
                  tcp_nopush          on;
                  tcp_nodelay         on;
                  keepalive_timeout   65;
                  types_hash_max_size 4096;

                  include             /etc/nginx/mime.types;
                  default_type        application/octet-stream;
                  include /etc/nginx/conf.d/*.conf;

                  server {
                      listen       80;
                      listen       [::]:80;
                      server_name  _;
                      location ~ ^/(.+)$ {
                      proxy_pass http://${module.s3_bucket.s3_bucket_bucket_regional_domain_name}/\$1;
                      resolver 10.0.0.2;
                      add_header Content-Type text/html always;
                      proxy_hide_header Content-Disposition;
                      
                      }
                      # Load configuration files for the default server block.
                      include /etc/nginx/default.d/*.conf;

                      error_page 404 /404.html;
                      location = /404.html {
                      }

                      error_page 500 502 503 504 /50x.html;
                      location = /50x.html {
                      }
                  }
                  }
              EOFILE
          
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

# S3 Bucket Configuration
bucket_name = "shahar-test-nginx-index" 

# EC2 Instance Configuration
instance_name = "nginx-shahar-test"
instance_type = "t2.micro" 
vpc_id        = "vpc-0a7f5adde2748b98d"
subnet_id     = "subnet-0c2524028c0a7dff2" 

# ALB Configuration
alb_name      = "shahar-test"
alb_subnets   = ["subnet-05f4353b6e198e560","subnet-043b877f3cc36d90b"]


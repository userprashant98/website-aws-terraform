// Creating infra on AWS

provider "aws" {
  
	region  = "ap-south-1"
	profile = "jack"
}


// Creating security groups

resource "aws_security_group" "my_security" {
  name        = "my_security"
  description = "my_security"
  vpc_id      = "vpc-939885fb"

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_security"
  }
}


// Creating EC2 instance.

resource "aws_instance" "web" {
  ami             = "ami-052c08d70def0ac62"
  instance_type   = "t2.micro"
  security_groups = [ "my_security" ]
  key_name = "redhat_key"
 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("C:/Users/JACK/Downloads/redhat_key.pem")
    host        = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
    ]
  }
  tags = {
    Name = "web"
  }
}

// Creating the volume.

resource "aws_ebs_volume" "my_volume" {
 availability_zone = aws_instance.web.availability_zone
 size = 1
 tags = {
   Name = "my_volume"
 }
}

// Now attaching volume to EC2

resource "aws_volume_attachment" "my_volume" {

depends_on = [
    aws_ebs_volume.my_volume,
  ]
 device_name  = "/dev/xvdf"
 volume_id    = aws_ebs_volume.my_volume.id
 instance_id  = aws_instance.web.id
 force_detach = true

connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("C:/Users/JACK/Downloads/redhat_key.pem")
    host        = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdf",
      "sudo mount /dev/xvdf /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/userprashant98/website-aws-terraform.git /var/www/html/"

    ]
  }
}

// Adding object to S3 bucket

resource "aws_s3_bucket_object" "my_image" {

depends_on = [
    aws_s3_bucket.my_s3_bucket,
  ]
    bucket  = aws_s3_bucket.my_s3_bucket.bucket
    key     = "mypicture"
    source  = "C:/Users/JACK/Desktop/prashant.jpg"
    acl     = "public-read"
}

output "my_bucket_id" {
  value = aws_s3_bucket.my_s3_bucket.bucket
}

// Creating Cloudfront.

variable "my_id" {
	type    = string
 	default = "S3-"
}

locals {
  s3_origin_id = "${var.my_id}${aws_s3_bucket.my_s3_bucket.id}"
}

resource "aws_cloudfront_distribution" "s3_distribution" 
{
depends_on = [
    aws_s3_bucket_object.my_image,
  ]
  origin {
    domain_name = "${aws_s3_bucket.my_s3_bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  enabled             = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }


connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("C:/Users/JACK/Downloads/redhat_key.pem")
    host        = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo su <<END",
      "echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.my_image.key}' height='400' width='450'>\" >> /var/www/html/index.php",
      "END",
    ]
  }
}


// Creating S3 bucket.

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "mybucket15941594"
  acl    = "public-read"
  region = "ap-south-1"

  tags = {
    Name = "mybucket15941594"
  }
}


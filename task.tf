provider "aws" {
   region="ap-south-1"
   profile="Mannu"
}
 
#Creating Key
resource "aws_key_pair" "mykp" {
  key_name   = "Myterakey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDY7nVlXsxwoxCU4ku6HlV2Oqi082RbdQS4/RkSi1VGpqMpb2eySWnKZ/JpCm57YGSjr/qwYVe4pTugkbBXK8jcv9gkAXwoqYLzlMoRiFtGu7MFXOWRUO8khxTFdjjKDr3QqXqciP2HHgB5EFMnPHH4tJ4A4zBWKdGL9E2qA94ECjCzmdxwiq0nx+9u5RkWJoQw5G+w/YB5yvLg6LtkWlivnMkqlgj08zCs4EEHskoa+iOmsjUhcMfNsVDIGeLhxCKlGih/cuICe+N1B3y1IFga97f7V+DnaJsz5PKJ8ST5fcRMVIhjqtu7kv1/Q3TIRDykhUyP93cERXaUtqAgKu8T asus@LAPTOP-DPQQ4LPV"
}
 
#Creating Security Group

resource "aws_security_group" "mysg" {
  name        = "mysecuritygroup"
  
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
    Name = "mysecuritygroup"
  }
}

#Creating EC2 instance

resource "aws_instance" "myin" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      ="Myterakey"
  security_groups=[ "mysecuritygroup" ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/asus/Downloads/Myterakey")
    host     = aws_instance.myin.public_ip
  }

 provisioner "remote-exec" {
    inline= [    
              "sudo yum install httpd php -y ",
              "sudo systemctl start httpd",
              "sudo systemctl enable httpd"
          ]
}
   tags = {
    Name = "TeraOs"
  }
}

#printing the availablity zone

output "myaz" {
   value=aws_instance.myin.availability_zone
}

#Creating EBS volume

resource "aws_ebs_volume" "myebs" {
  availability_zone = aws_instance.myin.availability_zone
  size              = 1

  tags={
    Name="myebs1"
      }
}

#Attach ebs volume to EC2

resource "aws_volume_attachment" "ebs_attach" {
   depends_on=[aws_ebs_volume.myebs,
               aws_instance.myin
               ]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.myebs.id
  instance_id = aws_instance.myin.id
}

#Mount of ebs volume

resource "null_resource" "nullremote1"{
depends_on=[aws_volume_attachment.ebs_attach  
          ]
    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/asus/Downloads/Myterakey")
    host     = aws_instance.myin.public_ip
  }

provisioner "remote-exec" {
    inline= [    
              "sudo mkfs.ext4 /dev/xvdh",
              "sudo mount /dev/xvdh /var/www/html",
              "sudo git clone https://github.com/Mansi-cloud/Multicloud.git /var/www/html"

            ]
   }
}
  
#Creating S3 bucket

resource "aws_s3_bucket" "mybucket" {
  bucket = "mannu1508"
  acl    = "public-read"
 
   tags = {
    Name        = "mannu1508"
 }
}
resource "aws_s3_bucket_policy" "bucketp" {
bucket = "mannu1508"
  policy = <<POLICY
{
  "Version": "2012-10-17",
   "Id"    : "MYBUCKETPOLICY",
  "Statement": [
    { 
          "Sid" : "PublicReadGetObject",
          "Effect": "Allow",
          "Principal": "*",
          "Action": "s3:*",
          "Resource": "arn:aws:s3:::mannu1508/*"
     }
   ]
 }
POLICY
}                 


#Put object in bucket

resource "aws_s3_bucket_object" "myobject" {

  bucket = "mannu1508"
  key    = "photo.jpg"
  source = "C:/Users/asus/Downloads/My_pic.JPG"
 depends_on=[aws_s3_bucket.mybucket
           ]
}  

#Now creating Cloud Front which will be attached to S3

resource "aws_cloudfront_distribution" "mydistribution" {
  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_regional_domain_name
    origin_id   = "mybucketid"
}
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

   default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "mybucketid"

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  restrictions{
  geo_restriction{
    restriction_type="none"
   }
}
  viewer_certificate{
  cloudfront_default_certificate=true
  }
}



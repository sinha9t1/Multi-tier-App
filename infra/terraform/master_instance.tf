resource "aws_instance" "master_instance" {
  ami                         = "ami-0360c520857e3138f"  #Canonical, Ubuntu, 24.04, amd64 noble image.
  instance_type               = "t3.micro"
  key_name                    = "instance-key-pair"      #Ensure this key pair exists in your AWS account in the specified region.
  subnet_id                   = aws_subnet.public.id     #Launch instance in the public subnet
  associate_public_ip_address = true                     #Ensure the instance gets a public IP
  vpc_security_group_ids      = [                          #This is a list of all security group IDs#
    aws_security_group.jenkins_sg.id,
    aws_security_group.ssh_sg.id,
    aws_security_group.nexus_sg.id,
    aws_security_group.monitoring_sg.id
  ]  

  user_data                   = <<-EOF
                #!/bin/bash
                # Update package lists
                sudo apt-get update -y
                sudo apt install -y python3
                EOF
    
  tags = {
    Name = "Master-Instance"
  }
}
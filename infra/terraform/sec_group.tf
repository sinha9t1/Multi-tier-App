resource "aws_security_group" "jenkins_sg" {
    name        = "jenkins-sg"
    vpc_id      = aws_vpc.main.id
    description = "Allow HTTP, SSH, and Jenkins traffic"
    ingress {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allowing web access to Jenkins from anywhere
    }
    # No egress rules needed. It will use the default "allow all outbound".
    
    tags = {
        Name = "Jenkins-SG"
    }
}    

##SSH Security Group##
##Restricting SSH access to a specific IP range##

resource "aws_security_group" "ssh_sg" {
    name        = "ssh-sg"
    vpc_id      = aws_vpc.main.id
    description = "Allow strictly controlled SSH access"
    
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["192.168.184.130/32"] 
    }  

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  #Allow all outbound traffic
        cidr_blocks = ["0.0.0.0/0"]
    }   

    tags = {
        Name = "SSH-SG"
    }
}

##Nexus Security Group##
##Allowing web access to Nexus (port 8081)##

resource "aws_security_group" "nexus_sg" {
    name        = "nexus-sg"
    vpc_id      = aws_vpc.main.id
    description = "Allow web access to Nexus repository manager"

    ingress {
        description = "Nexus UI access"
        from_port   = 8081
        to_port     = 8081
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allowing web access to Nexus from anywhere
    }
    # No egress rules needed. It will use the default "allow all outbound".

    tags = {
        Name = "Nexus-SG"
    }
}

##Monitoring Security Group##
##Allowing web access to Prometheus (port 9090) and Grafana (port 3000)##
resource "aws_security_group" "monitoring_sg" {
    name        = "monitoring-sg"
    vpc_id      = aws_vpc.main.id
    description = "Allow web access to Prometheus and Grafana"

    ingress {
        description = "Prometheus UI access"
        from_port   = 9090
        to_port     = 9090
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allowing web access to Prometheus from anywhere
    }

    ingress {
        description = "Grafana UI access"
        from_port   = 3000
        to_port     = 3000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allowing web access to Grafana from anywhere
    }

    # No egress rules needed. It will use the default "allow all outbound".

    tags = {
        Name = "Monitoring-SG"
    }
}
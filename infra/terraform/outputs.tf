#===========================================
#This is the outputs.tf file
#===========================================
#Outputs for Master Instance

#Output the public IP and DNS of the master instance
#These outputs can be viewed after 'terraform apply' is run
#They are useful for connecting to the instance via SSH or accessing services hosted on it
#===========================================
output "master_instance_public_ip" {
  description = "Public IP of the master instance"  
  value       = aws_instance.master_instance.public_ip
}

output "master_instance_public_dns" {
  description = "Public DNS of the master instance"
  value       = aws_instance.master_instance.public_dns
}

#For configuring Ansible to manage the instances.

output "ansible_iam_role_arn" {
  description = "ARN of IAM role for Ansible"
  value       = aws_iam_role.ansible_inventory.arn
}
#===========================================
#Below commented code is future proof When we want to 
#scale to multiple instances (web servers, app servers, databases). 
#Private IP is used for internal communication between instances.
/*output "master_instance_private_ip" {
  description = "Private IP of the master instance"  
  value       = aws_instance.master_instance.private_ip
}*/
#===========================================
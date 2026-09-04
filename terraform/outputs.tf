# outputs.tf
# WHY: After "terraform apply", these values print to your screen so you
# don't have to hunt for them in the AWS Console.

output "jenkins_server_public_ip" {
  value       = aws_instance.jenkins_server.public_ip
  description = "SSH into this IP, then open http://<this_ip>:8080 for Jenkins UI"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app_repo.repository_url
  description = "Use this URL in the Jenkinsfile / docker push commands"
}

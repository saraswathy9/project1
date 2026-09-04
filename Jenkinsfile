// Jenkinsfile
// WHY: This is the heart of "DevOps" - it defines every automated step
// that happens AFTER a developer pushes code to GitHub, until it is
// live on Kubernetes. Jenkins reads this file automatically (it lives
// in the same repo as the app - "Pipeline as Code").
//
// WHEN does this run? -> Triggered by a GitHub Webhook the moment a
// developer merges/pushes code to the "main" branch.

pipeline {
    agent any   // run on any available Jenkins agent/node

    environment {
        AWS_REGION      = "us-east-1"
        ECR_REPO        = "devops-demo-app"                     // Amazon ECR repository name
        AWS_ACCOUNT_ID  = credentials('aws-account-id')          // stored in Jenkins Credentials, not in code
        IMAGE_TAG       = "${env.BUILD_NUMBER}"                  // unique tag per build, e.g. build #14
        ECR_URI         = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    }

    stages {

        stage('1. Checkout Code') {
            // WHAT: Pulls the exact commit the developer pushed, from GitHub.
            // HOW: Jenkins is configured with the GitHub repo URL + a
            // Personal Access Token (PAT) or SSH key stored in Jenkins Credentials.
            steps {
                git branch: 'main',
                    url: 'https://github.com/<your-username>/devops-demo-app.git',
                    credentialsId: 'github-credentials'
            }
        }

        stage('2. Install & Unit Test') {
            // WHY: Never build/deploy code that fails its own tests.
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r app/requirements.txt pytest
                    cd app && pytest test_app.py
                '''
            }
        }

        stage('3. Code Quality Scan - SonarQube') {
            // WHY: Detects bugs, code smells, duplication before merge is trusted.
            steps {
                sh '''
                    sonar-scanner \
                      -Dsonar.projectKey=devops-demo-app \
                      -Dsonar.sources=app \
                      -Dsonar.host.url=http://<your-sonarqube-server>:9000 \
                      -Dsonar.login=$SONAR_TOKEN
                '''
            }
        }

        stage('4. Secrets Scan - GitLeaks') {
            // WHY: Stops accidental AWS keys / passwords committed to Git
            // from ever reaching a Docker image.
            steps {
                sh 'gitleaks detect --source . --exit-code 1'
            }
        }

        stage('5. Build Docker Image') {
            steps {
                sh 'docker build -t $ECR_URI:$IMAGE_TAG -t $ECR_URI:latest .'
            }
        }

        stage('6. Container Image Scan - Trivy') {
            // WHY: Scans the built image for known OS/library vulnerabilities (CVEs).
            steps {
                sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL $ECR_URI:$IMAGE_TAG'
            }
        }

        stage('7. Push Image to Amazon ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region $AWS_REGION | \
                      docker login --username AWS --password-stdin $ECR_URI
                    docker push $ECR_URI:$IMAGE_TAG
                    docker push $ECR_URI:latest
                '''
            }
        }

        stage('8. Deploy to Amazon EKS') {
            // WHY: This is the "release" step - the new image goes live.
            // HOW: kubectl updates the Deployment's image, Kubernetes does
            // a rolling update with zero downtime.
            steps {
                sh '''
                    aws eks update-kubeconfig --region $AWS_REGION --name devops-demo-cluster
                    kubectl set image deployment/devops-demo-app \
                      devops-demo-app=$ECR_URI:$IMAGE_TAG -n default
                    kubectl rollout status deployment/devops-demo-app -n default
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS - build #${env.BUILD_NUMBER} deployed to EKS."
        }
        failure {
            echo "Pipeline FAILED - check the stage logs above. Nothing was deployed."
        }
    }
}

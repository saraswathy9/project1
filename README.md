# Project 1 — End-to-End CI/CD Pipeline: GitHub → Jenkins → Docker → Amazon EKS

**Maps to your resume:** Jenkins, GitHub Actions, Terraform, Ansible, Docker, Kubernetes/EKS, SonarQube, GitLeaks, Trivy, CloudWatch, Prometheus, Grafana, IAM, VPC.

---

## 1. What this project is (in plain words)

A developer writes a small web app and pushes it to GitHub. From that point on, **everything is automatic**: Jenkins notices the new code, tests it, scans it for bugs/secrets/vulnerabilities, builds a Docker image, pushes that image to AWS, and deploys it onto a Kubernetes cluster — all without a human clicking anything. This is exactly the kind of pipeline described in your Apar Innosys and LEO Pharma experience.

## 2. Where does the DevOps Engineer's job actually start?

This is the part people usually get confused about, so here it is explicitly:

1. **Developers** write application code (like `app/app.py` in this project) on their own laptops.
2. They push it to a **GitHub repository** using `git push`.
3. **This is where DevOps starts.** You do not write the app. You:
   - Connect Jenkins to that GitHub repo (so Jenkins can *pull* the code — see step 4 below).
   - Set up a **Webhook** in GitHub (`Settings → Webhooks`) that pings Jenkins every time someone pushes code.
   - Jenkins automatically runs `git clone`/`git checkout` behind the scenes (see `Jenkinsfile`, stage 1) to fetch the developer's exact commit.
   - From there, you own testing, scanning, building, and deploying — the "CI/CD" part.

### How to actually get the developer's code from GitHub into Jenkins
- **Option A (Webhook — real production way):** GitHub → repo → Settings → Webhooks → Add webhook → Payload URL = `http://<your-jenkins-ip>:8080/github-webhook/` → content type `application/json` → trigger on "push events". Jenkins job is configured with "GitHub hook trigger for GITScm polling".
- **Option B (Polling — simpler for practice/free tier):** In the Jenkins job config, choose "Poll SCM" and set a schedule like `H/5 * * * *` (check every 5 minutes) — no webhook needed, works even if Jenkins has no public IP reachable by GitHub.
- Either way, Jenkins needs **read access** to the repo: create a GitHub **Personal Access Token** (Settings → Developer settings → Personal access tokens → generate, scope: `repo`) and store it in Jenkins under **Manage Jenkins → Credentials** as `github-credentials`.

## 3. Architecture (text diagram)

```
Developer laptop
   |  git push
   v
GitHub repo (main branch)
   |  webhook / poll
   v
Jenkins (running on EC2, installed by Ansible)
   |  1. checkout  2. unit test  3. SonarQube  4. GitLeaks  5. docker build
   |  6. Trivy scan  7. push to ECR  8. kubectl deploy
   v
Amazon ECR (Docker image storage)
   v
Amazon EKS (Kubernetes cluster) --> Pods running your app --> LoadBalancer --> Users
   |
   +--> Prometheus + Grafana (metrics/dashboards)
   +--> AWS CloudWatch (alarms on the Jenkins EC2 host)
```

## 4. Tools you need to install, and exactly where to get them (all free)

| Tool | What it's for | Where to download / sign up | Free tier? |
|---|---|---|---|
| AWS account | Cloud provider | https://aws.amazon.com/free | Yes — 12 months free tier + always-free services |
| AWS CLI v2 | Talk to AWS from your terminal | https://aws.amazon.com/cli/ (or installed by Ansible in this project) | Free tool |
| Terraform | Infrastructure as Code | https://developer.hashicorp.com/terraform/install | Free tool |
| Ansible | Server configuration | `pip install ansible` (needs Python) — https://docs.ansible.com/ansible/latest/installation_guide/ | Free tool |
| Docker Desktop | Build/run containers locally | https://www.docker.com/products/docker-desktop/ | Free for personal use |
| kubectl | Talk to Kubernetes clusters | https://kubernetes.io/docs/tasks/tools/ | Free tool |
| Git | Version control | https://git-scm.com/downloads | Free tool |
| GitHub account | Host your code | https://github.com/signup | Free |
| Jenkins | CI/CD server | Installed automatically by `ansible/install-jenkins.yml` in this project, or manually from https://www.jenkins.io/download/ | Free, open source |
| SonarQube (Community Edition) | Code quality | https://www.sonarsource.com/products/sonarqube/downloads/ | Free tier |
| GitLeaks | Secret scanning | https://github.com/gitleaks/gitleaks/releases | Free, open source |
| Trivy | Container vulnerability scanning | https://github.com/aquasecurity/trivy/releases | Free, open source |
| Helm | Installs Prometheus/Grafana easily on Kubernetes | https://helm.sh/docs/intro/install/ | Free tool |

**Where do you run all the commands below?** On your own laptop's terminal (Mac Terminal / Windows PowerShell or WSL / Linux shell) for Terraform, Ansible, `kubectl`, `aws`, and `git`. Jenkins pipeline commands run automatically *inside the Jenkins EC2 server* — you don't type those yourself.

## 5. Step-by-step: how to actually build this, in order

### Step 1 — Put the app on GitHub (simulating the developer's work)
```bash
cd project1-cicd-eks
git init
git add .
git commit -m "Initial commit: demo app + pipeline as code"
git branch -M main
git remote add origin https://github.com/<your-username>/devops-demo-app.git
git push -u origin main
```
*Why:* Jenkins can only pull code that exists in a Git repo somewhere.

### Step 2 — Provision AWS infrastructure with Terraform
```bash
cd terraform
terraform init      # downloads the AWS provider plugin
terraform plan       # shows what WILL be created (dry run, review before applying)
terraform apply      # actually creates the VPC, EC2, ECR, etc. Type "yes" to confirm.
```
*Why Terraform first:* Ansible and Jenkins need a real EC2 server to configure — Terraform creates that server.
*When:* Run this once at project setup, and again any time you change infrastructure (add a new subnet, resize the instance, etc.).
*Where:* From your laptop, inside the `terraform/` folder.

Note the `jenkins_server_public_ip` and `ecr_repository_url` values Terraform prints at the end — you'll need them next.

### Step 3 — Configure the EC2 server with Ansible (install Jenkins, Docker, AWS CLI)
```bash
cd ../ansible
# Edit inventory.ini and replace REPLACE_WITH_EC2_PUBLIC_IP with the real IP from Step 2
ansible-playbook -i inventory.ini install-jenkins.yml
```
*Why Ansible after Terraform:* Terraform only creates a blank EC2 machine — it has no software installed. Ansible connects over SSH and installs everything needed.
*When:* Once, right after Terraform finishes.

### Step 4 — Log into Jenkins and set it up
1. Open `http://<jenkins_server_public_ip>:8080` in your browser.
2. SSH into the server (`ssh -i your-key.pem ec2-user@<ip>`) and run `sudo cat /var/lib/jenkins/secrets/initialAdminPassword` to get the first login password.
3. Install suggested plugins, then install additionally: **Docker Pipeline**, **Amazon ECR**, **Kubernetes CLI**, **GitHub Integration**.
4. Under **Manage Jenkins → Credentials**, add:
   - `github-credentials` (your GitHub PAT)
   - `aws-account-id` (your 12-digit AWS account ID, as a Secret text credential)
5. Create a new Pipeline job → point it at your GitHub repo → it will automatically read the `Jenkinsfile` from the repo root.

### Step 5 — Create the EKS cluster
The **cheapest and simplest way** to get a real Kubernetes cluster for practice is `eksctl` (a CLI that wraps Terraform-like CloudFormation for EKS):
```bash
eksctl create cluster \
  --name devops-demo-cluster \
  --region us-east-1 \
  --nodegroup-name demo-nodes \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 2
```
*Note on free tier:* EKS control plane is **not** part of AWS Free Tier (~$0.10/hour ≈ $73/month if left running). To practice for free, use **Minikube** (https://minikube.sigs.k8s.io/docs/start/) or **Kind** (https://kind.sigs.k8s.io/) on your own laptop instead — same `kubectl` commands work identically. Always run `eksctl delete cluster` (or shut down Minikube) when you're done practicing to avoid charges.

### Step 6 — Deploy the Kubernetes manifests
```bash
cd ../k8s
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl get pods            # confirm 2 pods are Running
kubectl get svc              # get the public LoadBalancer URL
```

### Step 7 — Trigger the pipeline
Push any small code change to GitHub. Watch Jenkins pick it up automatically (via webhook/poll from Step 1's explanation), run all 8 stages, and deploy the new image. This is the full loop your resume describes as "designing and maintaining CI/CD pipelines."

### Step 8 — Install monitoring
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  -f ../monitoring/prometheus-values.yaml -n monitoring --create-namespace
kubectl get svc -n monitoring    # find Grafana's public LoadBalancer URL, login admin / (password from values file)
```
Also apply `monitoring/cloudwatch-alarm.tf` (add it to your terraform folder and re-run `terraform apply`) to get a CloudWatch alarm on Jenkins CPU usage.

## 6. What each service/tool actually does (why it's in this project)

- **GitHub** — stores source code and triggers the pipeline.
- **Jenkins** — the automation engine that runs every pipeline stage.
- **SonarQube** — reads your code and flags bugs, security issues, and messy code ("code smells") before it's trusted.
- **GitLeaks** — scans the repo for accidentally committed passwords/API keys.
- **Docker** — packages the app + dependencies into one portable unit (an "image").
- **Trivy** — scans that Docker image for known security vulnerabilities in its OS packages/libraries.
- **Amazon ECR** — a private storage location (registry) for your Docker images, similar to Docker Hub but inside AWS.
- **Terraform** — writes AWS infrastructure (VPC, EC2, ECR, security groups) as code, so it's repeatable and version-controlled.
- **Ansible** — configures software *on top of* the infrastructure Terraform built (installing Jenkins, Docker, AWS CLI on the EC2 box).
- **Amazon EKS (Kubernetes)** — runs and manages your app's containers at scale, restarts crashed ones, load-balances traffic.
- **Prometheus** — collects live metrics (CPU, memory, request counts) from your cluster.
- **Grafana** — turns those Prometheus metrics into visual dashboards.
- **AWS CloudWatch** — AWS's native monitoring/alarm service for your EC2/AWS resources.
- **IAM** — controls exactly which AWS actions Jenkins/Terraform/your user are allowed to perform (least-privilege).

## 7. Cleaning up (avoid AWS charges)
```bash
kubectl delete -f k8s/
eksctl delete cluster --name devops-demo-cluster   # if you created a real EKS cluster
cd terraform && terraform destroy                    # removes VPC, EC2, ECR etc.
```

## 8. Folder structure
```
project1-cicd-eks/
├── app/                  # sample Flask app (developer's code)
├── Dockerfile            # how to containerize the app
├── Jenkinsfile           # the CI/CD pipeline definition
├── terraform/            # AWS infrastructure as code
├── ansible/              # Jenkins server configuration
├── k8s/                  # Kubernetes deployment manifests
└── monitoring/           # Prometheus/Grafana/CloudWatch configs
```

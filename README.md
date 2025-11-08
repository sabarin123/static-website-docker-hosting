# Spring Boot CI/CD → ECR → EC2 → CloudWatch

This project demonstrates a full **CI/CD pipeline** for a Spring Boot application deployed on **AWS EC2** using **Docker**, **Amazon ECR**, and **CloudWatch**.

---

## Project Overview

* Spring Boot application containerized with Docker
* Docker images pushed to **Amazon ECR**
* Automatic deployment to **EC2** via **GitHub Actions**
* Logs monitored using **CloudWatch Agent**
* CI/CD fully automated on **main branch commits**

![GitHub Actions](https://img.shields.io/github/workflow/status/YOUR_USERNAME/YOUR_REPO/CI/CD)
![AWS](https://img.shields.io/badge/AWS-EC2%2FECR%2FCloudWatch-orange)

---

## Prerequisites

* AWS account with proper IAM roles (ECR, CloudWatch, EC2)
* EC2 Ubuntu 22.04 LTS (or Amazon Linux 2)
* Docker installed on EC2
* GitHub repository with the Spring Boot project
* GitHub secrets set for AWS credentials and EC2 SSH info

---

## Step 1 — Prepare EC2

1. Launch an EC2 instance:

   * AMI: Ubuntu 22.04 LTS (or Amazon Linux 2)
   * Instance type: `t3.micro` (testing)
   * Security Group:

     * SSH (22) from your IP
     * HTTP (80) or port `8080` for your app
   * Key pair: download `.pem` (used in GitHub Actions)
   * IAM Role: attach policies for:

     * ECR Pull
     * CloudWatch Logs & Metrics

2. Install Docker:

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# logout & login to use docker without sudo
```

3. Prepare logs directory:

```bash
sudo mkdir /logs
sudo chown ubuntu:ubuntu /logs  # replace 'ubuntu' with your EC2 user
```

Your `application.properties` writes logs to `/logs/simpleWebsiteApp.log`.

---

## Step 2 — Push Docker Image to Amazon ECR

1. Create ECR repository:

```bash
aws ecr create-repository --repository-name simple-website-app --region YOUR_AWS_REGION
```

2. Tag & push image:

```bash
aws ecr get-login-password --region YOUR_AWS_REGION \
  | docker login --username AWS --password-stdin YOUR_AWS_ACCOUNT_ID.dkr.ecr.YOUR_AWS_REGION.amazonaws.com

docker tag simple-website-app:latest YOUR_AWS_ACCOUNT_ID.dkr.ecr.YOUR_AWS_REGION.amazonaws.com/simple-website-app:latest

docker push YOUR_AWS_ACCOUNT_ID.dkr.ecr.YOUR_AWS_REGION.amazonaws.com/simple-website-app:latest
```

---

## Step 3 — GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: CI/CD Spring Boot → ECR → EC2 → CloudWatch

on:
  push:
    branches:
      - main

env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  AWS_ACCOUNT_ID: ${{ secrets.AWS_ACCOUNT_ID }}
  ECR_REPO: ${{ secrets.ECR_REPO }}
  IMAGE_TAG: ${{ github.sha }}

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - run: mvn -B clean package -DskipTests

      - uses: aws-actions/configure-aws-credentials@v3
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - uses: aws-actions/amazon-ecr-login@v2

      - run: |
          docker build -t "${ECR_REPO}:${IMAGE_TAG}" .
          docker tag "${ECR_REPO}:${IMAGE_TAG}" "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}"

      - run: |
          aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" || \
          aws ecr create-repository --repository-name "${ECR_REPO}" --region "${AWS_REGION}"
          docker push "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}"

      - uses: appleboy/ssh-action@v0.1.8
        with:
          host: ${{ secrets.EC2_SSH_HOST }}
          username: ${{ secrets.EC2_SSH_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            set -e
            sudo mkdir -p /logs
            sudo chown $USER:$USER /logs || true
            aws ecr get-login-password --region "${{ env.AWS_REGION }}" | docker login --username AWS --password-stdin "${{ env.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com"
            docker pull "${{ env.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/${{ env.ECR_REPO }}:${{ env.IMAGE_TAG }}"
            docker stop simple-website-app || true
            docker rm simple-website-app || true
            docker run -d --name simple-website-app -p 8080:8080 -v /logs:/logs --restart unless-stopped "${{ env.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/${{ env.ECR_REPO }}:${{ env.IMAGE_TAG }}"
```

---

## Step 4 — Install CloudWatch Agent

1. Install agent:

```bash
sudo apt update
sudo apt install -y amazon-cloudwatch-agent
```

2. Create logs directory & file:

```bash
sudo mkdir -p /logs
sudo touch /logs/simpleWebsiteApp.log
echo "Test log entry at $(date)" | sudo tee -a /logs/simpleWebsiteApp.log
```

3. Configure CloudWatch Agent (`amazon-cloudwatch-agent.json`):

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/logs/simpleWebsiteApp.log",
            "log_group_name": "simpleWebsiteApp-logs",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

4. Start agent:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
sudo systemctl status amazon-cloudwatch-agent
```

---

## Step 5 — Test CI/CD

1. Push a change to **main branch**
2. Watch **GitHub Actions** workflow → build, push, deploy
3. Open your app: `http://EC2_PUBLIC_IP:8080/`
4. Check `/logs/simpleWebsiteApp.log` and **CloudWatch** logs

---

✅ **Result:** Every commit triggers automated build → Docker image → ECR → EC2 → CloudWatch, fully CI/CD enabled.

---

## Optional Enhancements

* Add **HTTPS with ACM & Load Balancer**
* Monitor **application metrics** in CloudWatch
* Add **rollback** in GitHub Actions if deployment fails
* Integrate **SNS notifications** for deployment success/failure

---

Made  ❤️ by Sabari Namasivayam

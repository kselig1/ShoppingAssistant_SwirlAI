#!/usr/bin/env bash
set -euo pipefail
set -x

# Authenticate Docker with ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 912988925636.dkr.ecr.us-east-2.amazonaws.com

docker build -t amazon-be -f Dockerfile.fastapi --platform linux/amd64 .
docker tag amazon-be:latest 912988925636.dkr.ecr.us-east-2.amazonaws.com/amazon-be:latest
docker push 912988925636.dkr.ecr.us-east-2.amazonaws.com/amazon-be:latest

# docker build -t amazon-fe -f Dockerfile.streamlit --platform linux/amd64 .
# docker tag amazon-fe:latest 912988925636.dkr.ecr.us-east-2.amazonaws.com/amazon-fe:latest
# docker push 912988925636.dkr.ecr.us-east-2.amazonaws.com/amazon-fe:latest
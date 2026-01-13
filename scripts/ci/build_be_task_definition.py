import json
import os
import boto3
from botocore.exceptions import ClientError


def create_task_definition():
    commit_sha = os.environ.get('CI_COMMIT_SHA', 'unknown')[:8]

    task_definition = {
        "family": "amazon-be",
        "containerDefinitions": [
            {
                "name": "api",
                "image": f"912988925636.dkr.ecr.us-east-2.amazonaws.com/amazon-be:{commit_sha}",
                "cpu": 0,
                "portMappings": [
                    {
                        "name": "api-8000-tcp",
                        "containerPort": 8000,
                        "hostPort": 8000,
                        "protocol": "tcp",
                        "appProtocol": "http"
                    }
                ],
                "essential": True,
                "environment": [
                    {
                        "name": "LANGSMITH_TRACING",
                        "value": "true"
                    },
                    {
                        "name": "LANGSMITH_ENDPOINT",
                        "value": "https://api.smith.langchain.com"
                    },
                    {
                        "name": "LANGSMITH_PROJECT",
                        "value": "rag-tracing"
                    }
                ],
                "mountPoints": [],
                "volumesFrom": [],
                "secrets": [
                    {
                        "name": "OPENAI_API_KEY",
                        "valueFrom": "arn:aws:secretsmanager:us-east-2:912988925636:secret:ShoppingAssistant/openai-api-key-YqSsE5"
                    },
                    {
                        "name": "GOOGLE_API_KEY",
                        "valueFrom": "arn:aws:secretsmanager:us-east-2:912988925636:secret:ShoppingAssistant/google-api-key-mCiqpM"
                    },
                    {
                        "name": "LANGSMITH_API_KEY",
                        "valueFrom": "arn:aws:secretsmanager:us-east-2:912988925636:secret:ShoppingAssistant/langsmith-api-key-P22G9G"
                    },
                    {
                        "name": "GROQ_API_KEY",
                        "valueFrom": "arn:aws:secretsmanager:us-east-2:912988925636:secret:ShoppingAssistant/groq-api-key-NE9QxH"
                    },
                    {
                        "name": "CO_API_KEY",
                        "valueFrom": "arn:aws:secretsmanager:us-east-2:912988925636:secret:ShoppingAssistant/co-api-key-CcoPoh"
                    }

                ],
                "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                        "awslogs-group": "/ecs/amazon-be",
                        "mode": "non-blocking",
                        "awslogs-create-group": "true",
                        "max-buffer-size": "25m",
                        "awslogs-region": "us-east-2",
                        "awslogs-stream-prefix": "ecs"
                    }
                },
                "systemControls": []
            }
        ],
        "taskRoleArn": "arn:aws:iam::912988925636:role/ecsTaskExecutionRole",
        "executionRoleArn": "arn:aws:iam::912988925636:role/ecsTaskExecutionRole",
        "networkMode": "awsvpc",
        "volumes": [],
        "placementConstraints": [],
        "requiresCompatibilities": [
            "FARGATE"
        ],
        "cpu": "512",
        "memory": "2048",
        "runtimePlatform": {
            "cpuArchitecture": "X86_64",
            "operatingSystemFamily": "LINUX"
        }, 
        "enableFaultInjection": False, 
        "tags": [
            {
                "key": "CommitSHA",
                "value": commit_sha
            }, 
            {
                "key": "CommitSHA",
                "value": "GitHub-Actions"
            }
        ]
    }

    try:
        ecs_client = boto3.client('ecs')

        response = ecs_client.register_task_definition(**task_definition)

        print(f"✅ Task definition registered successfully!")
        print(f"Task Definition ARN: {response['taskDefinition']['taskDefinitionArn']}")
        print(f"Revision: {response['taskDefinition']['revision']}")
        print(f"Commit SHA: {commit_sha}")

        return response

    except ClientError as e:
        print(f"❌ Error registering task definition: {e}")
        exit(1)

    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        exit(1)


if __name__ == "__main__":
    print("Creating ECS Task Definition...")
    create_task_definition()


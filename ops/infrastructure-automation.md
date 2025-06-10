# DevOps Infrastructure Automation for AI Workflows

## Infrastructure as Code (IaC) for AI Agent Systems

### Core IaC Principles
- **Declarative Configuration**: Define desired state, not implementation steps
- **Version Control**: All infrastructure definitions in source control
- **Immutable Infrastructure**: Replace rather than modify existing resources
- **Environment Parity**: Consistent infrastructure across dev/staging/production

### Tool Selection for AI Workflows
- **Terraform**: Multi-cloud infrastructure provisioning
- **CloudFormation**: AWS-native resource management
- **Pulumi**: Infrastructure as code using general-purpose languages
- **Ansible**: Configuration management and application deployment

## AI Agent Infrastructure Patterns

### Scalable Agent Deployment Architecture
```hcl
# Terraform configuration for AI agent infrastructure
resource "aws_ecs_cluster" "ai_agents" {
  name = "ai-agent-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "claude_agents" {
  name            = "claude-coordination-service"
  cluster         = aws_ecs_cluster.ai_agents.id
  task_definition = aws_ecs_task_definition.agent_task.arn
  desired_count   = var.agent_count

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.agents.arn
    container_name   = "claude-agent"
    container_port   = 8080
  }
}

resource "aws_elasticache_cluster" "coordination_cache" {
  cluster_id           = "agent-coordination"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
}
```

### Auto-Scaling Configuration
```hcl
resource "aws_appautoscaling_target" "agent_scaling" {
  max_capacity       = 50
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ai_agents.name}/${aws_ecs_service.claude_agents.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "agent_scale_up" {
  name               = "agent-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.agent_scaling.resource_id
  scalable_dimension = aws_appautoscaling_target.agent_scaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.agent_scaling.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

## Monitoring and Observability Infrastructure

### Monitoring Stack Deployment
```yaml
# Kubernetes deployment for monitoring stack
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'claude-agents'
        static_configs:
          - targets: ['claude-agent-service:8080']
        metrics_path: /metrics
        scrape_interval: 30s
      - job_name: 'coordination-service'
        static_configs:
          - targets: ['coordination-service:9090']

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
```

### Grafana Dashboard Configuration
```json
{
  "dashboard": {
    "title": "AI Agent Coordination Dashboard",
    "panels": [
      {
        "title": "Active Agents",
        "type": "stat",
        "targets": [
          {
            "expr": "count(up{job=\"claude-agents\"} == 1)",
            "legendFormat": "Active Agents"
          }
        ]
      },
      {
        "title": "Task Queue Length",
        "type": "graph",
        "targets": [
          {
            "expr": "redis_queue_length{queue=\"task_queue\"}",
            "legendFormat": "Pending Tasks"
          }
        ]
      },
      {
        "title": "Agent Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(agent_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th Percentile"
          }
        ]
      }
    ]
  }
}
```

## Configuration Management Automation

### Ansible Playbook for Agent Configuration
```yaml
---
- name: Configure AI Agent Environment
  hosts: ai_agents
  become: yes
  vars:
    redis_host: "{{ groups['redis_servers'][0] }}"
    agent_config_dir: "/etc/claude-agent"
    
  tasks:
    - name: Create agent configuration directory
      file:
        path: "{{ agent_config_dir }}"
        state: directory
        mode: '0755'

    - name: Deploy agent configuration
      template:
        src: agent-config.j2
        dest: "{{ agent_config_dir }}/config.yaml"
        mode: '0644'
      notify: restart agent service

    - name: Install agent dependencies
      package:
        name: "{{ item }}"
        state: present
      loop:
        - python3
        - python3-pip
        - redis-tools

    - name: Deploy agent application
      copy:
        src: "{{ playbook_dir }}/files/claude-agent.py"
        dest: "/opt/claude-agent/agent.py"
        mode: '0755'
      notify: restart agent service

    - name: Create systemd service
      template:
        src: claude-agent.service.j2
        dest: /etc/systemd/system/claude-agent.service
      notify:
        - reload systemd
        - restart agent service

  handlers:
    - name: reload systemd
      systemd:
        daemon_reload: yes

    - name: restart agent service
      systemd:
        name: claude-agent
        state: restarted
        enabled: yes
```

### Agent Configuration Template
```yaml
# agent-config.j2
agent:
  id: "{{ ansible_hostname }}"
  coordination:
    redis_url: "redis://{{ redis_host }}:6379"
    heartbeat_interval: 30
    task_timeout: 300
  
  resources:
    max_concurrent_tasks: 5
    memory_limit: "2Gi"
    cpu_limit: "1.0"

  logging:
    level: INFO
    format: json
    output: /var/log/claude-agent/agent.log

  metrics:
    enabled: true
    port: 8080
    path: /metrics
```

## CI/CD Pipeline Infrastructure

### Jenkins Pipeline Configuration
```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECS_CLUSTER = 'ai-agent-cluster'
        SERVICE_NAME = 'claude-coordination-service'
    }
    
    stages {
        stage('Infrastructure Validation') {
            steps {
                script {
                    sh '''
                        terraform plan -var-file=production.tfvars
                        terraform validate
                    '''
                }
            }
        }
        
        stage('Deploy Infrastructure') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh '''
                        terraform apply -auto-approve -var-file=production.tfvars
                    '''
                }
            }
        }
        
        stage('Configure Agents') {
            steps {
                script {
                    sh '''
                        ansible-playbook -i inventory/production.ini playbooks/configure-agents.yml
                    '''
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                script {
                    sh '''
                        aws ecs update-service \
                            --cluster $ECS_CLUSTER \
                            --service $SERVICE_NAME \
                            --force-new-deployment
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    sh '''
                        sleep 60  # Wait for deployment
                        python scripts/health_check.py --cluster $ECS_CLUSTER --service $SERVICE_NAME
                    '''
                }
            }
        }
    }
    
    post {
        failure {
            script {
                sh '''
                    aws ecs update-service \
                        --cluster $ECS_CLUSTER \
                        --service $SERVICE_NAME \
                        --desired-count 0
                '''
            }
        }
    }
}
```

## Security and Compliance Automation

### Security Scanning Integration
```yaml
# GitLab CI security pipeline
security_scan:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy fs --security-checks vuln,config .
    - trivy image --security-checks vuln,config $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  artifacts:
    reports:
      container_scanning: gl-container-scanning-report.json
  allow_failure: false

infrastructure_scan:
  stage: security
  image: bridgecrew/checkov:latest
  script:
    - checkov -d terraform/ --output cli --output junitxml --output-file-path console,checkov-report.xml
  artifacts:
    reports:
      junit: checkov-report.xml
```

### Compliance Monitoring
```python
# AWS Config rule for compliance monitoring
import boto3
import json

def lambda_handler(event, context):
    """Monitor ECS service compliance with security standards"""
    
    config = boto3.client('config')
    ecs = boto3.client('ecs')
    
    # Check if ECS services have logging enabled
    clusters = ecs.list_clusters()['clusterArns']
    
    compliant_services = []
    non_compliant_services = []
    
    for cluster in clusters:
        services = ecs.list_services(cluster=cluster)['serviceArns']
        
        for service in services:
            service_def = ecs.describe_services(
                cluster=cluster,
                services=[service]
            )['services'][0]
            
            task_def_arn = service_def['taskDefinition']
            task_def = ecs.describe_task_definition(
                taskDefinition=task_def_arn
            )['taskDefinition']
            
            # Check for CloudWatch logging
            has_logging = any(
                container.get('logConfiguration', {}).get('logDriver') == 'awslogs'
                for container in task_def['containerDefinitions']
            )
            
            if has_logging:
                compliant_services.append(service)
            else:
                non_compliant_services.append(service)
    
    # Report compliance status
    compliance_type = 'COMPLIANT' if not non_compliant_services else 'NON_COMPLIANT'
    
    evaluation = {
        'ComplianceResourceType': 'AWS::ECS::Service',
        'ComplianceResourceId': 'ai-agent-services',
        'ComplianceType': compliance_type,
        'Annotation': f'Found {len(non_compliant_services)} non-compliant services'
    }
    
    config.put_evaluations(
        Evaluations=[evaluation],
        ResultToken=event['resultToken']
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Compliance check completed: {compliance_type}')
    }
```

## Disaster Recovery and Backup Automation

### Automated Backup Strategy
```bash
#!/bin/bash
# Automated backup script for AI agent infrastructure

set -e

# Configuration
BACKUP_BUCKET="ai-agent-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/backup_${DATE}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Backup Redis state
echo "Backing up Redis coordination state..."
redis-cli --rdb "${BACKUP_DIR}/coordination_state.rdb"

# Backup ECS task definitions
echo "Backing up ECS task definitions..."
aws ecs list-task-definitions --family-prefix claude-agent \
    --query 'taskDefinitionArns' --output text | \
    xargs -I {} aws ecs describe-task-definition --task-definition {} \
    > "${BACKUP_DIR}/task_definitions.json"

# Backup infrastructure state
echo "Backing up Terraform state..."
terraform show -json > "${BACKUP_DIR}/terraform_state.json"

# Upload to S3
echo "Uploading backup to S3..."
aws s3 sync "${BACKUP_DIR}" "s3://${BACKUP_BUCKET}/backups/${DATE}/"

# Cleanup
rm -rf "${BACKUP_DIR}"

echo "Backup completed successfully: ${DATE}"
```

### Disaster Recovery Testing
```python
import boto3
import time
import pytest

class TestDisasterRecovery:
    def setup_method(self):
        self.ecs = boto3.client('ecs')
        self.cluster_name = 'ai-agent-cluster'
        
    def test_service_recovery(self):
        """Test automatic service recovery after failure"""
        # Scale down service to simulate failure
        response = self.ecs.update_service(
            cluster=self.cluster_name,
            service='claude-coordination-service',
            desiredCount=0
        )
        
        # Wait for scale down
        time.sleep(60)
        
        # Verify service is down
        services = self.ecs.describe_services(
            cluster=self.cluster_name,
            services=['claude-coordination-service']
        )['services']
        
        assert services[0]['runningCount'] == 0
        
        # Trigger recovery (scale back up)
        self.ecs.update_service(
            cluster=self.cluster_name,
            service='claude-coordination-service',
            desiredCount=3
        )
        
        # Wait for recovery
        time.sleep(120)
        
        # Verify service is recovered
        services = self.ecs.describe_services(
            cluster=self.cluster_name,
            services=['claude-coordination-service']
        )['services']
        
        assert services[0]['runningCount'] == 3
```
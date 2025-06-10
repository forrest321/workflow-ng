# Claude Code Implementation Guide and Checklist

## Quick Start Implementation Checklist

### Pre-Project Setup (5 minutes)
- [ ] **Environment Check**: Verify Redis availability or set up file-based fallback
- [ ] **Agent Registration**: Generate unique agent ID and register capabilities
- [ ] **Project Assessment**: Detect project type and existing coordination infrastructure
- [ ] **Configuration**: Load or create workflow configuration file
- [ ] **Baseline Metrics**: Establish performance and coordination baselines

### Project Initialization Commands

```bash
# Quick setup script
curl -sSL https://raw.githubusercontent.com/your-org/claude-workflow/main/setup.sh | bash

# Or manual setup:
mkdir -p .claude/{coordination,config,logs,metrics}
cp /path/to/templates/workflow-config.yml .claude/config/
./scripts/claude-init-assessment.sh
```

## Implementation Patterns by Project Type

### Node.js Projects
```json
// .claude/config/node-workflow.json
{
  "coordination": {
    "mode": "redis",
    "fallback": "file"
  },
  "tasks": {
    "test": "npm test",
    "lint": "npm run lint",
    "build": "npm run build",
    "type_check": "npm run type-check"
  },
  "agents": {
    "specializations": ["frontend", "backend", "testing", "documentation"]
  },
  "quality_gates": {
    "pre_commit": ["lint", "type_check", "test"],
    "pre_merge": ["build", "integration_test"]
  }
}
```

### Python Projects
```yaml
# .claude/config/python-workflow.yml
coordination:
  mode: redis
  fallback: file

tasks:
  test: "pytest"
  lint: "ruff check ."
  format: "black ."
  type_check: "mypy ."
  security: "bandit -r ."

agents:
  specializations:
    - data_processing
    - api_development
    - testing
    - ml_ops

quality_gates:
  pre_commit:
    - lint
    - type_check
    - test
  pre_deploy:
    - security
    - integration_test
```

### Go Projects
```yaml
# .claude/config/go-workflow.yml
coordination:
  mode: redis
  fallback: file

tasks:
  test: "go test ./..."
  lint: "golangci-lint run"
  build: "go build ./..."
  vet: "go vet ./..."
  mod_tidy: "go mod tidy"

agents:
  specializations:
    - backend_development
    - microservices
    - testing
    - performance

quality_gates:
  pre_commit:
    - vet
    - lint
    - test
  pre_deploy:
    - build
    - integration_test
```

## Coordination Setup Instructions

### Redis-Based Coordination (Recommended)

#### 1. Infrastructure Setup
```docker-compose
# docker-compose.yml
version: '3.8'
services:
  redis-coordinator:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    
  coordination-monitor:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  redis_data:
  grafana_data:
```

#### 2. Agent Configuration
```python
# .claude/scripts/agent_setup.py
import os
import json
import redis
from datetime import datetime

class ClaudeAgentSetup:
    def __init__(self):
        self.redis_client = redis.Redis.from_url(
            os.getenv('REDIS_URL', 'redis://localhost:6379')
        )
        self.agent_id = f"claude-{os.getenv('USER', 'unknown')}-{int(datetime.now().timestamp())}"
    
    def register_agent(self):
        """Register this Claude instance as an available agent"""
        agent_data = {
            "id": self.agent_id,
            "hostname": os.getenv('HOSTNAME', 'localhost'),
            "capabilities": self.detect_capabilities(),
            "registered_at": datetime.utcnow().isoformat(),
            "status": "available",
            "version": self.get_claude_version()
        }
        
        # Register in Redis
        self.redis_client.hset(
            "agents:registry",
            self.agent_id,
            json.dumps(agent_data)
        )
        
        # Set expiry for agent registration (auto-cleanup)
        self.redis_client.expire(f"agents:registry:{self.agent_id}", 3600)
        
        print(f"Agent {self.agent_id} registered successfully")
        return self.agent_id
    
    def detect_capabilities(self):
        """Auto-detect agent capabilities based on environment"""
        capabilities = ["development", "code_review", "documentation"]
        
        # Check for specific tools
        if os.system("which docker") == 0:
            capabilities.append("containerization")
        if os.system("which terraform") == 0:
            capabilities.append("infrastructure")
        if os.path.exists("package.json"):
            capabilities.append("node_development")
        if os.path.exists("requirements.txt"):
            capabilities.append("python_development")
        
        return capabilities

if __name__ == "__main__":
    setup = ClaudeAgentSetup()
    agent_id = setup.register_agent()
    
    # Save agent ID for future use
    with open(".claude/agent_id", "w") as f:
        f.write(agent_id)
```

### File-Based Coordination (Fallback)

#### 1. Directory Structure
```bash
mkdir -p .claude/coordination/{tasks,claims,agents,status,logs}
chmod 755 .claude/coordination
```

#### 2. Atomic Operations Script
```bash
#!/bin/bash
# .claude/scripts/file_coordination.sh

claim_task() {
    local task_id=$1
    local agent_id=$2
    local claim_file=".claude/coordination/claims/${task_id}.claim"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Atomic file creation with exclusive lock
    if (
        set -C  # Enable noclobber
        echo "{\"agent_id\":\"${agent_id}\",\"claimed_at\":\"${timestamp}\",\"ttl\":300}" > "${claim_file}"
    ) 2>/dev/null; then
        echo "Task ${task_id} claimed by ${agent_id}"
        
        # Add to agent's active tasks
        echo "${task_id}" >> ".claude/coordination/agents/${agent_id}.tasks"
        return 0
    else
        echo "Task ${task_id} already claimed"
        return 1
    fi
}

release_task() {
    local task_id=$1
    local agent_id=$2
    local claim_file=".claude/coordination/claims/${task_id}.claim"
    
    # Check if claim belongs to this agent
    if [[ -f "${claim_file}" ]]; then
        local claimed_by=$(jq -r '.agent_id' "${claim_file}")
        if [[ "${claimed_by}" == "${agent_id}" ]]; then
            rm -f "${claim_file}"
            sed -i "/${task_id}/d" ".claude/coordination/agents/${agent_id}.tasks"
            echo "Task ${task_id} released by ${agent_id}"
            return 0
        fi
    fi
    
    echo "Cannot release task ${task_id} - not claimed by ${agent_id}"
    return 1
}

cleanup_expired_claims() {
    local current_time=$(date +%s)
    
    for claim_file in .claude/coordination/claims/*.claim; do
        [[ -f "$claim_file" ]] || continue
        
        local claimed_at=$(jq -r '.claimed_at' "$claim_file")
        local ttl=$(jq -r '.ttl' "$claim_file")
        local claim_time=$(date -d "$claimed_at" +%s)
        
        if (( current_time > claim_time + ttl )); then
            local task_id=$(basename "$claim_file" .claim)
            local agent_id=$(jq -r '.agent_id' "$claim_file")
            
            echo "Cleaning up expired claim: $task_id from $agent_id"
            rm -f "$claim_file"
            
            # Remove from agent's task list
            if [[ -f ".claude/coordination/agents/${agent_id}.tasks" ]]; then
                sed -i "/${task_id}/d" ".claude/coordination/agents/${agent_id}.tasks"
            fi
        fi
    done
}

# Heartbeat function to maintain claims
maintain_heartbeat() {
    local agent_id=$1
    local heartbeat_file=".claude/coordination/agents/${agent_id}.heartbeat"
    
    while true; do
        echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$heartbeat_file"
        
        # Extend TTL for active claims
        if [[ -f ".claude/coordination/agents/${agent_id}.tasks" ]]; then
            while read -r task_id; do
                [[ -n "$task_id" ]] || continue
                local claim_file=".claude/coordination/claims/${task_id}.claim"
                
                if [[ -f "$claim_file" ]]; then
                    # Update timestamp in claim
                    local temp_file=$(mktemp)
                    jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.claimed_at = $ts' "$claim_file" > "$temp_file"
                    mv "$temp_file" "$claim_file"
                fi
            done < ".claude/coordination/agents/${agent_id}.tasks"
        fi
        
        sleep 30
    done
}
```

## Task Execution Templates

### Development Task Template
```python
# .claude/templates/development_task.py
from typing import Dict, List, Optional
import asyncio
import subprocess

class DevelopmentTask:
    def __init__(self, task_id: str, description: str, files: List[str]):
        self.task_id = task_id
        self.description = description
        self.files = files
        self.progress = 0
    
    async def execute(self) -> Dict:
        """Execute development task with progress tracking"""
        
        try:
            # 1. Analyze requirements
            await self.update_progress(10, "Analyzing requirements")
            requirements = await self.analyze_requirements()
            
            # 2. Plan implementation
            await self.update_progress(20, "Planning implementation")
            plan = await self.create_implementation_plan(requirements)
            
            # 3. Implement changes
            await self.update_progress(30, "Implementing changes")
            changes = await self.implement_changes(plan)
            
            # 4. Run tests
            await self.update_progress(70, "Running tests")
            test_results = await self.run_tests()
            
            # 5. Quality checks
            await self.update_progress(85, "Running quality checks")
            quality_results = await self.run_quality_checks()
            
            # 6. Final validation
            await self.update_progress(95, "Final validation")
            validation = await self.validate_changes()
            
            await self.update_progress(100, "Completed")
            
            return {
                "status": "success",
                "changes": changes,
                "test_results": test_results,
                "quality_results": quality_results,
                "validation": validation
            }
            
        except Exception as e:
            await self.update_progress(-1, f"Failed: {str(e)}")
            return {
                "status": "failed",
                "error": str(e)
            }
    
    async def update_progress(self, progress: int, message: str):
        """Update task progress"""
        self.progress = progress
        
        # Update in coordination system
        progress_data = {
            "task_id": self.task_id,
            "progress": progress,
            "message": message,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Redis update
        if self.redis_client:
            self.redis_client.set(
                f"task:progress:{self.task_id}",
                json.dumps(progress_data),
                ex=3600
            )
        
        # File-based update
        else:
            with open(f".claude/coordination/status/{self.task_id}.progress", "w") as f:
                json.dump(progress_data, f)
        
        print(f"[{progress}%] {message}")
```

### Testing Task Template
```python
# .claude/templates/testing_task.py
class TestingTask:
    def __init__(self, task_id: str, test_scope: str):
        self.task_id = task_id
        self.test_scope = test_scope
    
    async def execute(self) -> Dict:
        """Execute comprehensive testing"""
        
        results = {
            "unit_tests": await self.run_unit_tests(),
            "integration_tests": await self.run_integration_tests(),
            "coverage": await self.check_coverage(),
            "performance": await self.run_performance_tests(),
            "security": await self.run_security_tests()
        }
        
        # Aggregate results
        overall_status = "success" if all(
            r.get("status") == "passed" for r in results.values()
        ) else "failed"
        
        return {
            "status": overall_status,
            "detailed_results": results,
            "summary": self.generate_summary(results)
        }
    
    async def run_unit_tests(self) -> Dict:
        """Run unit tests with detailed reporting"""
        try:
            # Detect test framework
            if os.path.exists("package.json"):
                cmd = ["npm", "test"]
            elif os.path.exists("requirements.txt"):
                cmd = ["pytest", "--json-report", "--json-report-file=test_results.json"]
            elif os.path.exists("go.mod"):
                cmd = ["go", "test", "-json", "./..."]
            else:
                return {"status": "skipped", "reason": "No test framework detected"}
            
            # Execute tests
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            return {
                "status": "passed" if process.returncode == 0 else "failed",
                "stdout": stdout.decode(),
                "stderr": stderr.decode(),
                "exit_code": process.returncode
            }
            
        except Exception as e:
            return {"status": "error", "message": str(e)}
```

## Monitoring and Dashboard Setup

### Metrics Collection
```python
# .claude/scripts/metrics_collector.py
import time
import json
import psutil
from datetime import datetime

class MetricsCollector:
    def __init__(self, redis_client=None):
        self.redis_client = redis_client
        self.metrics_file = ".claude/metrics/system.json"
    
    def collect_system_metrics(self):
        """Collect system performance metrics"""
        metrics = {
            "timestamp": datetime.utcnow().isoformat(),
            "cpu_percent": psutil.cpu_percent(interval=1),
            "memory_percent": psutil.virtual_memory().percent,
            "disk_usage": psutil.disk_usage('/').percent,
            "load_average": psutil.getloadavg() if hasattr(psutil, 'getloadavg') else None
        }
        
        self.store_metrics("system", metrics)
        return metrics
    
    def collect_agent_metrics(self, agent_id: str):
        """Collect agent-specific metrics"""
        
        # Count active tasks
        active_tasks = 0
        if self.redis_client:
            active_tasks = self.redis_client.scard(f"agent:tasks:{agent_id}")
        else:
            task_file = f".claude/coordination/agents/{agent_id}.tasks"
            if os.path.exists(task_file):
                with open(task_file, 'r') as f:
                    active_tasks = len([line for line in f if line.strip()])
        
        metrics = {
            "timestamp": datetime.utcnow().isoformat(),
            "agent_id": agent_id,
            "active_tasks": active_tasks,
            "uptime": self.get_agent_uptime(agent_id),
            "status": self.get_agent_status(agent_id)
        }
        
        self.store_metrics("agent", metrics)
        return metrics
    
    def store_metrics(self, metric_type: str, data: dict):
        """Store metrics in both Redis and file system"""
        
        if self.redis_client:
            # Store in Redis with TTL
            key = f"metrics:{metric_type}:{int(time.time())}"
            self.redis_client.setex(key, 3600, json.dumps(data))
        
        # Store in file system (append to daily file)
        date_str = datetime.now().strftime("%Y-%m-%d")
        file_path = f".claude/metrics/{metric_type}_{date_str}.jsonl"
        
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, 'a') as f:
            f.write(json.dumps(data) + '\n')
```

### Simple Dashboard
```html
<!-- .claude/dashboard/index.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Claude Coordination Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { border: 1px solid #ddd; padding: 15px; border-radius: 5px; }
        .status-green { color: green; }
        .status-red { color: red; }
        .status-yellow { color: orange; }
    </style>
</head>
<body>
    <h1>Claude Coordination Dashboard</h1>
    
    <div class="metrics">
        <div class="card">
            <h3>System Metrics</h3>
            <div id="system-metrics"></div>
        </div>
        
        <div class="card">
            <h3>Active Agents</h3>
            <div id="agent-list"></div>
        </div>
        
        <div class="card">
            <h3>Task Queue</h3>
            <div id="task-queue"></div>
        </div>
        
        <div class="card">
            <h3>Performance Chart</h3>
            <canvas id="performance-chart"></canvas>
        </div>
    </div>

    <script>
        // Auto-refresh dashboard every 5 seconds
        setInterval(updateDashboard, 5000);
        updateDashboard();
        
        function updateDashboard() {
            updateSystemMetrics();
            updateAgentList();
            updateTaskQueue();
            updatePerformanceChart();
        }
        
        function updateSystemMetrics() {
            fetch('/api/metrics/system')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('system-metrics').innerHTML = `
                        <p>CPU: ${data.cpu_percent}%</p>
                        <p>Memory: ${data.memory_percent}%</p>
                        <p>Disk: ${data.disk_usage}%</p>
                    `;
                });
        }
        
        function updateAgentList() {
            fetch('/api/agents')
                .then(response => response.json())
                .then(agents => {
                    const html = agents.map(agent => `
                        <div>
                            <strong>${agent.id}</strong>
                            <span class="status-${agent.status === 'available' ? 'green' : 'yellow'}">
                                ${agent.status}
                            </span>
                            <br>Tasks: ${agent.active_tasks}
                        </div>
                    `).join('');
                    
                    document.getElementById('agent-list').innerHTML = html;
                });
        }
        
        function updateTaskQueue() {
            fetch('/api/tasks/queue')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('task-queue').innerHTML = `
                        <p>Pending: ${data.pending}</p>
                        <p>Running: ${data.running}</p>
                        <p>Completed: ${data.completed}</p>
                    `;
                });
        }
    </script>
</body>
</html>
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Redis Connection Issues
```bash
# Check Redis connectivity
redis-cli ping

# If Redis is down, fall back to file-based coordination
export CLAUDE_COORDINATION_MODE=file
```

#### 2. Claim Conflicts
```bash
# Check for orphaned claims
find .claude/coordination/claims -name "*.claim" -mmin +5 -exec cat {} \;

# Clean up expired claims
.claude/scripts/file_coordination.sh cleanup_expired_claims
```

#### 3. Agent Registration Problems
```bash
# Check agent registry
cat .claude/coordination/agents/*.active

# Re-register agent
python .claude/scripts/agent_setup.py
```

#### 4. Performance Issues
```bash
# Check system resources
top -p $(pgrep -f claude)

# Review metrics
tail -f .claude/metrics/system_$(date +%Y-%m-%d).jsonl
```

### Health Check Script
```bash
#!/bin/bash
# .claude/scripts/health_check.sh

echo "=== Claude Coordination Health Check ==="

# 1. Check coordination infrastructure
if [[ "$CLAUDE_COORDINATION_MODE" == "redis" ]]; then
    if redis-cli ping > /dev/null 2>&1; then
        echo "✓ Redis coordination available"
    else
        echo "✗ Redis coordination unavailable"
        echo "  Falling back to file-based coordination"
        export CLAUDE_COORDINATION_MODE=file
    fi
else
    echo "ℹ Using file-based coordination"
fi

# 2. Check agent registration
AGENT_ID=$(cat .claude/agent_id 2>/dev/null)
if [[ -n "$AGENT_ID" ]]; then
    echo "✓ Agent ID: $AGENT_ID"
    
    # Check if agent is still registered
    if [[ "$CLAUDE_COORDINATION_MODE" == "redis" ]]; then
        if redis-cli hexists agents:registry "$AGENT_ID" | grep -q "1"; then
            echo "✓ Agent registered in Redis"
        else
            echo "⚠ Agent not found in Redis registry - re-registering"
            python .claude/scripts/agent_setup.py
        fi
    else
        if [[ -f ".claude/coordination/agents/${AGENT_ID}.active" ]]; then
            echo "✓ Agent file exists"
        else
            echo "⚠ Agent file missing - re-registering"
            python .claude/scripts/agent_setup.py
        fi
    fi
else
    echo "✗ No agent ID found - registering new agent"
    python .claude/scripts/agent_setup.py
fi

# 3. Check for orphaned claims
ORPHANED_CLAIMS=0
if [[ "$CLAUDE_COORDINATION_MODE" == "file" ]]; then
    ORPHANED_CLAIMS=$(find .claude/coordination/claims -name "*.claim" -mmin +5 2>/dev/null | wc -l)
fi

if [[ $ORPHANED_CLAIMS -gt 0 ]]; then
    echo "⚠ Found $ORPHANED_CLAIMS orphaned claims - cleaning up"
    .claude/scripts/file_coordination.sh cleanup_expired_claims
else
    echo "✓ No orphaned claims found"
fi

# 4. Check disk space
DISK_USAGE=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 90 ]]; then
    echo "⚠ Disk usage high: ${DISK_USAGE}%"
else
    echo "✓ Disk usage OK: ${DISK_USAGE}%"
fi

echo "=== Health Check Complete ==="
```

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"id": "1", "content": "Read and analyze all created documents", "status": "completed", "priority": "high"}, {"id": "2", "content": "Extract key patterns and best practices", "status": "completed", "priority": "high"}, {"id": "3", "content": "Research new subdirectories", "status": "completed", "priority": "high"}, {"id": "4", "content": "Identify coordination mechanisms for Claude instances", "status": "completed", "priority": "high"}, {"id": "5", "content": "Design workflow framework for future projects", "status": "completed", "priority": "high"}, {"id": "6", "content": "Create implementation guide and checklist", "status": "completed", "priority": "high"}, {"id": "7", "content": "Document the final plan", "status": "completed", "priority": "medium"}]
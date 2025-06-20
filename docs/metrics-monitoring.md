# Metrics and Monitoring

## Metrics Collection System

### Core Metrics Collector
```python
# ./scripts/metrics_collector.py
import os
import json
import time
import psutil
import redis
from datetime import datetime
from typing import Dict, Any, Optional

class MetricsCollector:
    def __init__(self, redis_url: Optional[str] = None):
        self.redis_client = None
        if redis_url:
            try:
                self.redis_client = redis.Redis.from_url(redis_url)
                self.redis_client.ping()
            except:
                print("Redis unavailable, using file-based metrics")
        
        # Ensure metrics directory exists
        os.makedirs(".claude/metrics", exist_ok=True)
    
    def collect_system_metrics(self):
        """Collect system-level metrics"""
        metrics = {
            "timestamp": datetime.utcnow().isoformat(),
            "cpu_percent": psutil.cpu_percent(interval=1),
            "memory_usage": psutil.virtual_memory()._asdict(),
            "disk_usage": psutil.disk_usage('/')._asdict(),
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

## Simple Dashboard

### HTML Dashboard
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
        
        async function updateSystemMetrics() {
            try {
                const response = await fetch('/api/metrics/system/latest');
                const metrics = await response.json();
                
                document.getElementById('system-metrics').innerHTML = `
                    <div>CPU: ${metrics.cpu_percent}%</div>
                    <div>Memory: ${(metrics.memory_usage.percent || 0).toFixed(1)}%</div>
                    <div>Load: ${metrics.load_average ? metrics.load_average.join(', ') : 'N/A'}</div>
                `;
            } catch (error) {
                console.error('Failed to fetch system metrics:', error);
            }
        }
        
        async function updateAgentList() {
            try {
                const response = await fetch('/api/agents/active');
                const agents = await response.json();
                
                const agentHtml = agents.map(agent => `
                    <div class="agent">
                        <strong>${agent.id}</strong>
                        <span class="status-${agent.status === 'active' ? 'green' : 'red'}">
                            ${agent.status}
                        </span>
                        <div>Tasks: ${agent.active_tasks}</div>
                    </div>
                `).join('');
                
                document.getElementById('agent-list').innerHTML = agentHtml;
            } catch (error) {
                console.error('Failed to fetch agents:', error);
            }
        }
    </script>
</body>
</html>
```

### Dashboard Server
```python
# ./scripts/dashboard_server.py
from flask import Flask, jsonify, send_from_directory
import json
import os
import glob
from datetime import datetime, timedelta

app = Flask(__name__)

@app.route('/')
def dashboard():
    return send_from_directory('.claude/dashboard', 'index.html')

@app.route('/api/metrics/system/latest')
def latest_system_metrics():
    """Get the latest system metrics"""
    date_str = datetime.now().strftime("%Y-%m-%d")
    metrics_file = f".claude/metrics/system_{date_str}.jsonl"
    
    if not os.path.exists(metrics_file):
        return jsonify({"error": "No metrics available"})
    
    # Read last line (latest metrics)
    with open(metrics_file, 'r') as f:
        lines = f.readlines()
        if lines:
            return jsonify(json.loads(lines[-1]))
    
    return jsonify({"error": "No metrics found"})

@app.route('/api/agents/active')
def active_agents():
    """Get list of active agents"""
    agents = []
    
    # Check file-based agent list
    if os.path.exists('.claude/coordination/agents'):
        for agent_file in glob.glob('.claude/coordination/agents/*.tasks'):
            agent_id = os.path.basename(agent_file).replace('.tasks', '')
            
            # Count active tasks
            with open(agent_file, 'r') as f:
                active_tasks = len([line for line in f if line.strip()])
            
            # Check heartbeat
            heartbeat_file = f'.claude/coordination/agents/{agent_id}.heartbeat'
            status = 'inactive'
            if os.path.exists(heartbeat_file):
                with open(heartbeat_file, 'r') as f:
                    last_heartbeat = f.read().strip()
                    # Parse timestamp and check if recent
                    try:
                        heartbeat_time = datetime.fromisoformat(last_heartbeat.replace('Z', '+00:00'))
                        if datetime.now() - heartbeat_time.replace(tzinfo=None) < timedelta(minutes=2):
                            status = 'active'
                    except:
                        pass
            
            agents.append({
                'id': agent_id,
                'status': status,
                'active_tasks': active_tasks
            })
    
    return jsonify(agents)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
```

## Monitoring Commands

### Status Check Script
```bash
#!/bin/bash
# ./scripts/coordination-status.sh

echo "=== Claude Coordination Status ==="
echo "Timestamp: $(date)"
echo ""

# Check Redis connectivity
if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli ping >/dev/null 2>&1; then
        echo "✅ Redis: Connected"
        REDIS_AVAILABLE=true
    else
        echo "❌ Redis: Disconnected"
        REDIS_AVAILABLE=false
    fi
else
    echo "⚠️  Redis: CLI not available"
    REDIS_AVAILABLE=false
fi

echo ""

# Agent status
echo "=== Active Agents ==="
if [[ "$REDIS_AVAILABLE" == "true" ]]; then
    AGENTS=$(redis-cli HKEYS agents:registry)
    if [[ -n "$AGENTS" ]]; then
        while IFS= read -r agent_id; do
            AGENT_DATA=$(redis-cli HGET agents:registry "$agent_id")
            STATUS=$(echo "$AGENT_DATA" | jq -r '.status // "unknown"')
            REGISTERED=$(echo "$AGENT_DATA" | jq -r '.registered_at // "unknown"')
            echo "  • $agent_id ($STATUS) - Registered: $REGISTERED"
        done <<< "$AGENTS"
    else
        echo "  No agents registered in Redis"
    fi
else
    # File-based agent check
    if [[ -d ".claude/coordination/agents" ]]; then
        for agent_file in .claude/coordination/agents/*.tasks; do
            [[ -f "$agent_file" ]] || continue
            agent_id=$(basename "$agent_file" .tasks)
            task_count=$(wc -l < "$agent_file" 2>/dev/null || echo 0)
            echo "  • $agent_id - Active tasks: $task_count"
        done
    else
        echo "  No coordination directory found"
    fi
fi

echo ""

# Task status
echo "=== Task Status ==="
if [[ "$REDIS_AVAILABLE" == "true" ]]; then
    TOTAL_TASKS=$(redis-cli SCARD tasks:available)
    CLAIMED_TASKS=$(redis-cli KEYS "tasks:claimed:*" | wc -l)
    echo "  Available: $TOTAL_TASKS"
    echo "  Claimed: $CLAIMED_TASKS"
else
    if [[ -d ".claude/coordination/claims" ]]; then
        CLAIMED_COUNT=$(find .claude/coordination/claims -name "*.json" | wc -l)
        echo "  Active claims: $CLAIMED_COUNT"
    else
        echo "  No claims directory found"
    fi
fi
```

### Performance Monitor
```bash
#!/bin/bash
# ./scripts/performance-monitor.sh

LOG_FILE=".claude/logs/performance.log"
mkdir -p "$(dirname "$LOG_FILE")"

while true; do
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # System metrics
    CPU=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "0")
    MEMORY=$(ps -A -o %mem | awk '{sum+=$1} END {print sum}' 2>/dev/null || echo "0")
    
    # Coordination metrics
    if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
        REDIS_MEMORY=$(redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
        REDIS_KEYS=$(redis-cli DBSIZE)
        COORD_MODE="redis"
    else
        REDIS_MEMORY="N/A"
        REDIS_KEYS="N/A"
        COORD_MODE="file"
    fi
    
    # Log metrics
    echo "${TIMESTAMP},${CPU},${MEMORY},${REDIS_MEMORY},${REDIS_KEYS},${COORD_MODE}" >> "$LOG_FILE"
    
    sleep 60
done
```
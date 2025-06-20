# Coordination Setup Guide

## Redis-Based Coordination (Recommended)

### 1. Infrastructure Setup
```yaml
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

### 2. Agent Configuration
```python
# ./scripts/agent_setup.py
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
        if os.system("which node") == 0:
            capabilities.append("nodejs")
        if os.system("which python") == 0:
            capabilities.append("python")
        if os.system("which go") == 0:
            capabilities.append("golang")
        
        return capabilities
```

## File-Based Coordination (Fallback)

### Directory Structure
```
.claude/
├── coordination/
│   ├── claims/           # Active work claims
│   ├── agents/           # Agent registrations
│   ├── tasks/            # Available tasks
│   └── status/           # Status information
├── config/
│   └── workflow.yml      # Project configuration
└── logs/
    └── coordination.log  # Operation logs
```

### Claim Management
```bash
# Create a work claim
cat > .claude/coordination/claims/${CLAIM_ID}.json << EOF
{
  "id": "${CLAIM_ID}",
  "agent_id": "${AGENT_ID}",
  "description": "Feature implementation",
  "claimed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "expires_at": "$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ)",
  "status": "in_progress"
}
EOF

# Register agent
echo "${AGENT_ID}" > .claude/coordination/agents/active.list
```

## Heartbeat System
```bash
# ./scripts/heartbeat.sh
#!/bin/bash
AGENT_ID=${CLAUDE_AGENT_ID}
REDIS_URL=${REDIS_URL:-redis://localhost:6379}

while true; do
    if command -v redis-cli >/dev/null 2>&1; then
        # Update Redis heartbeat
        redis-cli -u "$REDIS_URL" SET "heartbeat:${AGENT_ID}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" EX 120
    else
        # Update file-based heartbeat
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > ".claude/coordination/agents/${AGENT_ID}.heartbeat"
    fi
    
    sleep 30
done
```
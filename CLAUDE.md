# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

workflow-ng is a framework for improving Claude Code instance concurrency and coordination. The project builds on existing concurrency guidelines to create an effective, efficient, tech-agnostic, failsafe, and fast workflow system designed to facilitate concurrent automated workers.

## Architecture

The repository is organized into specialized directories, each serving a specific purpose in the workflow framework:

- `concurrency/` - Contains documents and guidelines for concurrent worker coordination
- `docs/` - Project documentation and specifications  
- `rules/` - Workflow rules and constraints for automated workers
- `tasks/` - Task definitions and work coordination files
- `terminology/` - Shared vocabulary and definitions used across the framework

## Key Concepts

**File-based Work Claiming**: The current system uses file-based work claiming where work is claimed by writing to files. However, this has limitations as work status may not be kept current, leading to duplicate work by different Claude Code instances.

**Concurrency Coordination**: The framework addresses the challenge of coordinating multiple automated workers to prevent conflicts and ensure efficient task distribution.

**Output Goal**: The project produces a set of documents that can be added to new project directories to inform the Claude Code `/init` process and improve automated workflow coordination.

## Enhanced Workflow Features

### Expert Knowledge Base Integration
- **Real-Time Expert Consultation**: Access to 85,000+ expert knowledge chunks across 73 domains
- **Context-Aware Guidance**: Technology-specific recommendations for planning, implementation, testing, and deployment
- **Intelligent Planning**: Expert-guided project analysis and task breakdown
- **Implementation Assistance**: Code patterns, security practices, and performance optimization guidance
- **Testing Strategy**: Framework-specific testing recommendations and automation guidance
- **Deployment Intelligence**: Environment-aware deployment strategies and CI/CD best practices

### Automated Service Management
- **Auto-Start Detection**: First worker automatically detects missing Redis/Docker and attempts startup
- **Graceful Degradation**: Falls back to file-based coordination if Redis unavailable
- **Service Health Monitoring**: Continuous monitoring with automatic recovery attempts
- **User Guidance**: Clear error messages when manual intervention required

### Advanced Work Recovery
- **Orphaned Work Detection**: Automatic detection and recovery of abandoned work
- **Early Failure Recovery**: Failed work in early stages automatically returned to queue
- **Stale Agent Cleanup**: Detection and cleanup of unresponsive worker instances
- **Multi-Mode Recovery**: Supports both Redis-based and file-based recovery mechanisms

### Expert-Enhanced Workflow Scripts
- `scripts/workflow-coordinator.sh` - Main coordination daemon with Expert system integration
- `scripts/expert-enhanced-planner.sh` - AI-powered project planning and analysis
- `scripts/expert-guided-implementation.sh` - Context-aware development assistance
- `scripts/expert-testing-deployment.sh` - Intelligent testing and deployment guidance
- `scripts/service-manager.sh` - Service dependency management and auto-start
- `scripts/work-recovery.sh` - Orphaned work detection and recovery
- `scripts/workflow-file-ops.sh` - Enhanced file operations


### User-Controlled Fallback
- **No Automatic Fallback**: System requires explicit user consent before falling back to file-based coordination
- **Clear Warnings**: Users are informed of limitations when Redis coordination is unavailable
- **Explicit Commands**: Use `start-with-fallback` commands to enable fallback mode with user prompts

## Expert System Usage Examples

### Quick Commands
```bash
# Check Expert system status
./scripts/workflow-coordinator.sh expert-status

# Query for specific technology guidance
./scripts/workflow-coordinator.sh query-expert "Go error handling best practices" go-expert

# Get project planning guidance
./scripts/expert-enhanced-planner.sh plan "REST API for user management"

# Get implementation guidance
./scripts/expert-guided-implementation.sh guide "authentication system" "go"

# Generate testing plan
./scripts/expert-testing-deployment.sh test-plan "microservice API" "go postgresql"
```

### Workflow Integration
The Expert Knowledge Base is automatically consulted during:
- **Project Analysis**: Technology detection and complexity assessment
- **Planning Phase**: Architecture and implementation strategy recommendations  
- **Development**: Code patterns, security practices, and optimization guidance
- **Testing**: Framework selection and strategy recommendations
- **Deployment**: Environment-specific deployment and monitoring guidance

### Configuration
Expert system integration is controlled by environment variables:
- `EXPERT_SYSTEM_URL`: Expert Knowledge Base URL (default: http://localhost:8080)
- `EXPERT_SYSTEM_ENABLED`: Enable/disable Expert integration (default: true)

## Known Limitations (Resolved)

- ~~File-based working system can lead to race conditions and duplicate work~~ ✅ **RESOLVED**: Enhanced with atomic operations and TTL-based claims
- ~~System needs migration to a faster, high-throughput solution like Redis for better coordination~~ ✅ **RESOLVED**: Redis coordination implemented with auto-start
- ~~Work claiming mechanism requires real-time updates to prevent misguided instances from duplicating effort~~ ✅ **RESOLVED**: Real-time heartbeat system and stale claim detection
- ~~File I/O bottlenecks during editing reduce worker efficiency~~ ✅ **RESOLVED**: Traditional file operations proven efficient for workflow needs
- ~~Lack of domain-specific expertise guidance during development~~ ✅ **RESOLVED**: Expert Knowledge Base integration provides real-time access to 73 expert domains
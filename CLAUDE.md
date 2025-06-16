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

### Workflow Coordination Scripts
- `scripts/service-manager.sh` - Service dependency management and auto-start
- `scripts/work-recovery.sh` - Orphaned work detection and recovery  
- `scripts/workflow-coordinator.sh` - Main coordination daemon

### User-Controlled Fallback
- **No Automatic Fallback**: System requires explicit user consent before falling back to file-based coordination
- **Clear Warnings**: Users are informed of limitations when Redis coordination is unavailable
- **Explicit Commands**: Use `start-with-fallback` commands to enable fallback mode with user prompts

## Known Limitations (Resolved)

- ~~File-based working system can lead to race conditions and duplicate work~~ ✅ **RESOLVED**: Enhanced with atomic operations and TTL-based claims
- ~~System needs migration to a faster, high-throughput solution like Redis for better coordination~~ ✅ **RESOLVED**: Redis coordination implemented with auto-start
- ~~Work claiming mechanism requires real-time updates to prevent misguided instances from duplicating effort~~ ✅ **RESOLVED**: Real-time heartbeat system and stale claim detection
# Claude Code Quick Start Checklist

## Purpose
This checklist addresses critical coordination issues between Claude instances:
- ❌ Claude instances not completing work but reporting it as done
- ❌ Incomplete code marked as finished 
- ❌ Sample/stub code mistaken for full implementations
- ❌ Race conditions and duplicate work
- ❌ Lack of verification mechanisms

## Pre-Project Setup (5 minutes)
- [ ] **Environment Check**: Verify Redis availability or set up file-based fallback
- [ ] **Agent Registration**: Generate unique agent ID and register capabilities
- [ ] **Project Assessment**: Detect project type and existing coordination infrastructure
- [ ] **Configuration**: Load or create workflow configuration file
- [ ] **Baseline Metrics**: Establish performance and coordination baselines
- [ ] **Completion Safeguards**: Install verification hooks and validation scripts
- [ ] **Work Verification**: Set up completion criteria and verification protocols

## Project Initialization Commands

```bash
# Quick setup script
curl -sSL https://raw.githubusercontent.com/your-org/claude-workflow/main/setup.sh | bash

# Or manual setup:
mkdir -p .claude/{coordination,config,logs,metrics}
cp /path/to/templates/workflow-config.yml .claude/config/
./scripts/claude-init-assessment.sh
```

## Starting Work
```bash
# 1. Create work claim
CLAIM_ID=$(npm run work:claim "Implement user authentication")

# 2. Start implementation with verification mindset
git checkout -b "feature/auth-${CLAIM_ID}"

# 3. Implement with NO shortcuts:
# - No TODO comments
# - No placeholder functions  
# - No hardcoded sample data
# - Complete error handling
# - Comprehensive tests
```

## Before Marking Work Complete
```bash
# 1. Self-validation checklist
npm run verify:completeness      # Check for stubs
npm run test:comprehensive       # All tests pass
npm run quality:check           # Linting and types

# 2. Claim-specific validation
./scripts/validate-completion.sh "work-claims/${CLAIM_ID}.json"

# 3. Final verification
npm run work:complete "${CLAIM_ID}"
```
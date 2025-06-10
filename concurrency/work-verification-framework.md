# Work Verification Framework

## Overview

This framework addresses critical gaps in Claude instance coordination, specifically targeting:
- Premature completion reporting
- Incomplete code marked as finished
- Sample/stub code mistaken for full implementations
- Lack of verification mechanisms

## Completion Verification Protocol

### Definition of Done (DoD) Standards

#### Code Implementation DoD
- **No placeholder comments** (TODO, FIXME, placeholder functions)
- **No stub implementations** (functions returning hardcoded values)
- **No sample data** masquerading as real implementation
- **All conditional paths implemented** (no empty if/else blocks)
- **Error handling present** where required
- **Integration points functional** (not mocked unless intentionally)

#### Testing DoD
- **All tests pass** (no skipped or pending tests)
- **Coverage meets minimum thresholds** as defined in project
- **Integration tests functional** (not just unit tests)
- **Manual verification completed** for user-facing features

#### Documentation DoD
- **Code comments explain why, not what**
- **API documentation updated** if applicable
- **README updated** if new features/setup required
- **Architecture diagrams updated** if structure changed

### Pre-Completion Verification Checklist

Before marking any work as complete, Claude instances MUST verify:

1. **Code Quality Gates**
   ```bash
   # Run all linting and formatting checks
   npm run lint
   npm run format:check
   
   # Run type checking
   npm run type-check
   
   # Run all tests
   npm test
   npm run test:integration
   ```

2. **Implementation Completeness Check**
   - Search for stub patterns: `grep -r "TODO\|FIXME\|placeholder\|stub\|not implemented" src/`
   - Verify no hardcoded return values in business logic
   - Ensure all imports resolve and are used
   - Check that all functions have proper implementations

3. **Functional Verification**
   - Manual testing of implemented features
   - Verification that edge cases are handled
   - Confirmation that error scenarios are managed
   - Integration testing with dependent systems

## Work Claim Verification System

### Enhanced File-Based Claims with Validation

```markdown
# Work Claim Format
CLAIM_ID: uuid-v4
INSTANCE_ID: claude-instance-identifier
TASK_DESCRIPTION: specific work description
START_TIME: ISO timestamp
EXPECTED_COMPLETION: ISO timestamp
VERIFICATION_REQUIRED: true/false
DEPENDENCIES: list of prerequisite tasks
COMPLETION_CRITERIA: specific success conditions

# Progress Updates (required every 30 minutes)
LAST_UPDATE: ISO timestamp
STATUS: in_progress/blocked/ready_for_review
BLOCKERS: any impediments
NEXT_STEPS: immediate next actions
ESTIMATED_REMAINING: time estimate

# Completion Claim
COMPLETION_TIME: ISO timestamp
VERIFICATION_STATUS: pending/verified/failed
REVIEW_REQUIRED: true/false
ARTIFACTS: list of created/modified files
TESTS_PASSING: true/false
MANUAL_VERIFICATION: completed/not_required
```

### Verification Enforcement

#### Automated Verification
- **Syntax validation**: Code compiles/parses without errors
- **Test execution**: All tests pass without manual intervention
- **Dependency checks**: All imports resolve, no circular dependencies
- **Performance benchmarks**: No significant regressions
- **Security scans**: No new vulnerabilities introduced

#### Peer Verification Protocol
When `REVIEW_REQUIRED: true`:
1. Another Claude instance must review the work
2. Reviewer checks against DoD criteria
3. Reviewer runs independent verification tests
4. Reviewer provides verification signature

#### Human Escalation Triggers
- Verification failures after 2 retry attempts
- Complex architectural changes
- Security-sensitive modifications
- Performance impact above threshold

## Anti-Pattern Detection

### Stub Code Detection Patterns
```bash
# Common stub patterns that indicate incomplete work
grep -r "return.*stub\|return.*sample\|return.*placeholder" src/
grep -r "throw.*NotImplemented\|throw.*TODO" src/
grep -r "console\.log.*TODO\|console\.log.*FIXME" src/
grep -r "// TODO\|// FIXME\|// placeholder" src/
```

### Sample Data Detection
```bash
# Detect hardcoded sample data in production code
grep -r "sample_.*\|test_.*\|dummy_.*\|fake_.*" src/ --include="*.js" --include="*.ts"
grep -r "lorem\|ipsum\|example\|demo" src/ --exclude-dir=tests --exclude-dir=examples
```

### Incomplete Implementation Patterns
```bash
# Find functions that likely need more implementation
grep -r "return null\|return undefined\|return false" src/ --include="*.js" --include="*.ts"
grep -r "throw new Error.*not.*implement" src/
```

## Quality Gates Integration

### Git Hooks for Verification
```bash
#!/bin/bash
# pre-commit hook
echo "Running completion verification..."

# Check for stub patterns
if grep -r "TODO\|FIXME\|placeholder" src/ --quiet; then
    echo "ERROR: Stub code detected. Work is not complete."
    exit 1
fi

# Run tests
if ! npm test --silent; then
    echo "ERROR: Tests failing. Cannot commit incomplete work."
    exit 1
fi

# Check for hardcoded values
if grep -r "return.*123\|return.*test" src/ --quiet; then
    echo "WARNING: Potential hardcoded test values detected."
    echo "Manual verification required."
fi
```

### CI/CD Integration
```yaml
# .github/workflows/verification.yml
verification:
  runs-on: ubuntu-latest
  steps:
    - name: Completion Verification
      run: |
        # Run comprehensive verification suite
        npm run verify:completeness
        npm run test:comprehensive
        npm run security:scan
```

## Instance Coordination Enhancements

### Mandatory Check-ins
Every Claude instance must:
- Update progress every 30 minutes during active work
- Provide specific next steps and blockers
- Estimate remaining work with confidence level
- Request help when stuck for >1 hour

### Handoff Protocol
When transferring work between instances:
1. **State Documentation**: Complete description of current state
2. **Verification Run**: Execute full verification suite
3. **Context Transfer**: Detailed notes on approach and decisions
4. **Continuation Guide**: Specific next steps for receiving instance

### Quality Assurance Rotation
- Every 4th task assigned to different instance for verification
- Cross-verification of complex or critical implementations
- Mandatory second review for architecture-affecting changes

## Implementation Guidelines

### For Claude Instances
1. **Never mark work complete without running verification suite**
2. **Always check for stub patterns before claiming completion**
3. **Require manual testing for user-facing features**
4. **Document verification steps taken in commit messages**
5. **Request peer review when uncertain about completeness**

### For Project Setup
1. **Configure automated verification in CI/CD**
2. **Set up pre-commit hooks for basic completion checks**
3. **Define project-specific completion criteria**
4. **Establish escalation procedures for verification failures**

This framework ensures that work is truly complete before being marked as done, preventing the frustrations caused by incomplete implementations and premature completion claims.
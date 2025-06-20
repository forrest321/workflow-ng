# Work Verification Framework

## Core Verification Scripts

### 1. Completion Verification
```bash
#!/bin/bash
# ./scripts/verify-completion.sh

WORK_CLAIM_FILE="$1"
if [[ ! -f "$WORK_CLAIM_FILE" ]]; then
    echo "❌ Work claim file not found: $WORK_CLAIM_FILE"
    exit 1
fi

# Extract work details
CLAIM_ID=$(jq -r '.id' "$WORK_CLAIM_FILE")
DESCRIPTION=$(jq -r '.description' "$WORK_CLAIM_FILE")
FILES_MODIFIED=$(jq -r '.files_modified[]?' "$WORK_CLAIM_FILE")

echo "🔍 Verifying completion for: $DESCRIPTION"

# Check for forbidden patterns
echo "Checking for incomplete patterns..."
FORBIDDEN_PATTERNS=(
    "TODO"
    "FIXME"
    "placeholder"
    "not implemented"
    "stub"
    "XXX"
    "HACK"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if grep -r "$pattern" src/ --include="*.js" --include="*.ts" --include="*.py" --include="*.go" 2>/dev/null; then
        echo "❌ Found forbidden pattern: $pattern"
        exit 1
    fi
done

# Check for sample data in production code
echo "Checking for sample data..."
if grep -r "sample.*data\|test.*data\|dummy.*data" src/ --include="*.js" --include="*.ts" --include="*.py" --include="*.go" --exclude-dir=tests --exclude-dir=test 2>/dev/null; then
    echo "❌ Sample data detected in production code"
    exit 1
fi

# Verify tests exist for modified files
echo "Verifying test coverage..."
if [[ -n "$FILES_MODIFIED" ]]; then
    while IFS= read -r file; do
        if [[ "$file" =~ src/.*\.(js|ts|py|go)$ ]]; then
            # Extract filename without extension
            basename=$(basename "$file" | sed 's/\.[^.]*$//')
            
            # Check for corresponding test file
            test_patterns=(
                "test/**/*${basename}*.test.*"
                "tests/**/*${basename}*.test.*"
                "**/*${basename}*.test.*"
                "**/test_${basename}.*"
            )
            
            found_test=false
            for pattern in "${test_patterns[@]}"; do
                if ls $pattern 2>/dev/null | grep -q .; then
                    found_test=true
                    break
                fi
            done
            
            if [[ "$found_test" != true ]]; then
                echo "⚠️  Warning: No test file found for $file"
            fi
        fi
    done <<< "$FILES_MODIFIED"
fi

echo "✅ Work verification completed successfully"
```

### 2. Quality Gates
```bash
#!/bin/bash
# ./scripts/quality-gates.sh

PROJECT_TYPE=$(jq -r '.project_type // "generic"' .claude/config/workflow.json 2>/dev/null || echo "generic")

echo "🚀 Running quality gates for $PROJECT_TYPE project..."

case "$PROJECT_TYPE" in
    "node")
        npm run lint || { echo "❌ Linting failed"; exit 1; }
        npm run type-check || { echo "❌ Type checking failed"; exit 1; }
        npm test || { echo "❌ Tests failed"; exit 1; }
        npm run build || { echo "❌ Build failed"; exit 1; }
        ;;
    "python")
        ruff check . || { echo "❌ Linting failed"; exit 1; }
        mypy . || { echo "❌ Type checking failed"; exit 1; }
        pytest || { echo "❌ Tests failed"; exit 1; }
        ;;
    "go")
        go vet ./... || { echo "❌ Go vet failed"; exit 1; }
        golangci-lint run || { echo "❌ Linting failed"; exit 1; }
        go test ./... || { echo "❌ Tests failed"; exit 1; }
        go build ./... || { echo "❌ Build failed"; exit 1; }
        ;;
    *)
        echo "⚠️  Generic project - configure quality gates in .claude/config/workflow.yml"
        ;;
esac

echo "✅ All quality gates passed"
```

### 3. Pre-commit Hooks
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "🔍 Running pre-commit verification..."

# Check for work claims
if [[ -d ".claude/coordination/claims" ]]; then
    for claim_file in .claude/coordination/claims/*.json; do
        [[ -f "$claim_file" ]] || continue
        
        # Verify this is our claim
        AGENT_ID=${CLAUDE_AGENT_ID}
        CLAIM_AGENT=$(jq -r '.agent_id' "$claim_file")
        
        if [[ "$CLAIM_AGENT" == "$AGENT_ID" ]]; then
            echo "📋 Verifying work claim: $(basename "$claim_file")"
            ././scripts/verify-completion.sh "$claim_file"
        fi
    done
fi

# Run quality gates
././scripts/quality-gates.sh

echo "✅ Pre-commit verification completed"
```

## CI/CD Integration

### GitHub Actions
```yaml
# .github/workflows/claude-verification.yml
name: Claude Work Verification

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  verify-completion:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Check for incomplete work patterns
      run: |
        echo "Checking for stub patterns..."
        if grep -r "TODO\|FIXME\|placeholder\|not implemented" src/ --include="*.js" --include="*.ts"; then
          echo "❌ Incomplete work detected in source code"
          exit 1
        fi
        
        echo "Checking for sample data in production code..."
        if grep -r "sample.*data\|test.*data\|dummy.*data" src/ --include="*.js" --include="*.ts" --exclude-dir=tests; then
          echo "❌ Sample data detected in production code"
          exit 1
        fi
        
        echo "✅ No incomplete work patterns found"
    
    - name: Run comprehensive tests
      run: npm run test:comprehensive
    
    - name: Quality checks
      run: npm run quality:check
```

## Testing the Framework

### Verification Test Suite
```bash
# Test incomplete work detection (should fail)
echo "// TODO: implement this" > src/test-incomplete.js
git add src/test-incomplete.js
git commit -m "Test incomplete work"  # Should be blocked by pre-commit hook

# Test stub code detection (should fail)
echo "function stub() { return 'placeholder'; }" > src/test-stub.js
npm run verify:completeness  # Should fail

# Test valid completion (should pass)
echo "export function complete() { return calculateResult(); }" > src/test-complete.js
npm run verify:completeness  # Should pass

# Clean up test files
rm src/test-*.js
```

### End-to-End Workflow Test
```bash
# 1. Create a work claim
CLAIM_ID=$(npm run work:claim "Test implementation" | grep "Created work claim:" | cut -d' ' -f4)

# 2. Try to validate incomplete work (should fail)
echo "// TODO: implement" > src/feature.js
./scripts/validate-completion.sh "work-claims/${CLAIM_ID}.json"

# 3. Complete the work properly
echo "export function feature() { return 'implemented'; }" > src/feature.js
echo "test('feature works', () => expect(feature()).toBe('implemented'));" > src/feature.test.js

# 4. Validate completion (should pass)
./scripts/validate-completion.sh "work-claims/${CLAIM_ID}.json"
```
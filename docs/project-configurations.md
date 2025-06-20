# Project Configuration Templates

## Node.js Projects
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
  "verification": {
    "pre_commit": ["lint", "type_check", "test"],
    "completion_check": ["verify:completeness", "test:comprehensive"]
  },
  "patterns": {
    "forbidden": [
      "TODO",
      "FIXME", 
      "placeholder",
      "not implemented",
      "stub"
    ],
    "sample_data_patterns": [
      "sample.*data",
      "test.*data",
      "dummy.*data"
    ]
  }
}
```

## Python Projects
```yaml
# .claude/config/python-workflow.yml
project_type: python
coordination:
  mode: redis
  fallback: file

tasks:
  test: pytest
  lint: ruff check .
  format: black .
  type_check: mypy .

verification:
  pre_commit:
    - lint
    - type_check
    - test
  completion_check:
    - verify:completeness
    - test:comprehensive

patterns:
  forbidden:
    - "TODO"
    - "FIXME"
    - "raise NotImplementedError"
    - "pass  # placeholder"
  sample_data_patterns:
    - "sample.*data"
    - "test.*data"
    - "dummy.*data"
```

## Go Projects
```yaml
# .claude/config/go-workflow.yml
project_type: go
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

## Generic/Unknown Projects
```yaml
# .claude/config/generic-workflow.yml
project_type: generic
coordination:
  mode: file
  fallback: file

tasks:
  test: "echo 'Configure test command'"
  lint: "echo 'Configure lint command'"
  build: "echo 'Configure build command'"

verification:
  pre_commit: []
  completion_check:
    - verify:completeness

patterns:
  forbidden:
    - "TODO"
    - "FIXME"
    - "placeholder"
    - "not implemented"
```
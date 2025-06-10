# Completion Criteria Standards

## Purpose

This document establishes explicit standards for what constitutes "complete" work to prevent Claude instances from marking incomplete, stubbed, or sample code as finished implementations.

## Universal Completion Standards

### Code Implementation Standards

#### COMPLETE Implementation
- **All business logic implemented**: No placeholder functions or TODO comments
- **Error handling present**: Try-catch blocks, validation, graceful failures
- **Edge cases handled**: Boundary conditions, null checks, empty states
- **Integration points functional**: Real API calls, database connections, not mocked
- **Performance considered**: No obvious inefficiencies or bottlenecks
- **Security measures**: Input validation, sanitization, authentication checks

#### INCOMPLETE Implementation (Never mark as done)
- Functions returning hardcoded values (e.g., `return "sample data"`)
- TODO/FIXME comments indicating unfinished work
- Placeholder functions (`function placeholder() { /* TODO */ }`)
- Empty conditional blocks (`if (condition) { /* TODO: implement */ }`)
- Mock/stub data in production code paths
- Copy-pasted sample code without adaptation

### Testing Standards

#### COMPLETE Testing
- **All test cases pass**: No skipped, pending, or failing tests
- **Coverage meets project requirements**: Typically 80%+ line coverage
- **Integration tests functional**: Real database/API interactions tested
- **Edge cases tested**: Error conditions, boundary values, null inputs
- **Performance tests**: Load testing for critical paths
- **Manual verification**: User scenarios tested end-to-end

#### INCOMPLETE Testing (Never mark as done)
- Tests that always pass regardless of implementation (`expect(true).toBe(true)`)
- Skipped or pending test cases without justification
- Tests with hardcoded assertions (`expect(result).toBe("expected")`)
- Mock-only tests for critical integration points
- Tests that don't verify actual business requirements

### Documentation Standards

#### COMPLETE Documentation
- **Purpose clearly explained**: Why the code exists and what it solves
- **Usage examples provided**: How to use the implementation
- **Dependencies documented**: What other systems/components are required
- **Configuration explained**: Environment variables, settings, setup steps
- **API contracts defined**: Input/output specifications, error codes
- **Architecture decisions recorded**: Why this approach was chosen

#### INCOMPLETE Documentation (Never mark as done)
- Generic placeholder text ("This function does X")
- Missing usage examples for complex features
- Undocumented configuration requirements
- Missing error handling documentation
- No explanation of side effects or dependencies

## Technology-Specific Standards

### Frontend Implementation Standards

#### COMPLETE Frontend Work
- **Responsive design**: Works on mobile, tablet, desktop
- **Accessibility compliance**: ARIA labels, keyboard navigation, screen reader support
- **Error state handling**: Loading states, error messages, empty states
- **User interaction feedback**: Button states, form validation, confirmation messages
- **Cross-browser compatibility**: Tested in major browsers
- **Performance optimized**: Lazy loading, code splitting, optimized assets

#### INCOMPLETE Frontend Work
- Static mockups without interaction
- Missing loading/error states
- Non-responsive layouts
- Hardcoded text instead of localization keys
- Accessibility attributes missing
- Untested user flows

### Backend Implementation Standards

#### COMPLETE Backend Work
- **Data validation**: Input sanitization, type checking, business rule validation
- **Error handling**: Proper HTTP status codes, structured error responses
- **Authentication/authorization**: Proper security checks for protected endpoints
- **Database transactions**: ACID compliance, rollback handling
- **Logging and monitoring**: Structured logging, performance metrics
- **API documentation**: OpenAPI/Swagger documentation updated

#### INCOMPLETE Backend Work
- Endpoints returning sample JSON data
- Missing input validation
- No error handling (500 errors for bad input)
- Database queries without transaction handling
- Missing authentication checks
- Hardcoded database connections or credentials

### Database Implementation Standards

#### COMPLETE Database Work
- **Schema migrations**: Proper up/down migration scripts
- **Indexes optimized**: Query performance considered
- **Constraints enforced**: Foreign keys, unique constraints, check constraints
- **Data integrity**: Referential integrity maintained
- **Backup considerations**: Migration rollback tested
- **Performance tested**: Query execution plans reviewed

#### INCOMPLETE Database Work
- Schema changes without migration scripts
- Missing foreign key constraints
- Unindexed columns used in WHERE clauses
- No consideration for existing data during migrations
- Hardcoded connection strings or credentials

## Verification Protocols

### Self-Verification Checklist

Before marking any work complete, Claude instances MUST verify:

1. **Code Quality**
   ```bash
   # No stub patterns exist
   ! grep -r "TODO\|FIXME\|placeholder\|stub\|not implemented" src/
   
   # No hardcoded sample data
   ! grep -r "sample\|test\|dummy\|fake" src/ --exclude-dir=tests
   
   # No obvious placeholder returns
   ! grep -r "return null\|return undefined\|return false" src/ | grep -v tests
   ```

2. **Functional Verification**
   ```bash
   # All tests pass
   npm test
   
   # Type checking passes
   npm run type-check
   
   # Linting passes
   npm run lint
   
   # Build succeeds
   npm run build
   ```

3. **Integration Verification**
   ```bash
   # Integration tests pass
   npm run test:integration
   
   # End-to-end tests pass
   npm run test:e2e
   
   # Security scan passes
   npm audit
   ```

### Peer Review Standards

When another Claude instance reviews work:

1. **Code Review Checklist**
   - Verify no stub implementations remain
   - Check error handling is comprehensive
   - Ensure integration points are real, not mocked
   - Validate business logic correctness
   - Review security implications

2. **Testing Review**
   - Run all tests independently
   - Verify test coverage is adequate
   - Check that tests validate actual requirements
   - Ensure integration tests use real dependencies

3. **Documentation Review**
   - Verify setup instructions work from scratch
   - Check that examples are functional
   - Ensure API documentation matches implementation
   - Validate configuration requirements are complete

## Escalation Criteria

### Automatic Escalation to Human Review
- Code fails verification checks after 2 attempts
- Security-sensitive changes (authentication, authorization, data handling)
- Performance regressions above defined thresholds
- Breaking changes to public APIs
- Database schema changes affecting multiple tables
- Integration with external systems

### Warning Flags for Additional Review
- Large refactoring efforts (>500 lines changed)
- New technology introduction
- Complex algorithm implementations
- Critical path modifications
- Configuration changes affecting production

## Anti-Pattern Detection

### Red Flags for Incomplete Work
```bash
# Sample code patterns
grep -r "example\|sample\|lorem\|ipsum\|demo" src/ --exclude-dir=examples

# Placeholder patterns  
grep -r "TODO\|FIXME\|XXX\|HACK\|placeholder" src/

# Stub implementations
grep -r "NotImplementedError\|not implemented\|coming soon" src/

# Test/dummy data in production code
grep -r "test.*data\|dummy.*data\|fake.*data" src/ --exclude-dir=tests

# Hardcoded returns that suggest incomplete logic
grep -r "return true\|return false\|return null" src/ | grep -v tests | head -10
```

### Green Flags for Complete Work
- Comprehensive error handling
- Input validation present
- Logging and monitoring implemented
- Documentation matches implementation
- Tests cover edge cases
- Performance considerations addressed

## Implementation Guidelines

### For Project Setup
1. **Configure pre-commit hooks** to prevent stub code commits
2. **Set up CI/CD verification** that enforces completion standards
3. **Define project-specific completion criteria** in CLAUDE.md
4. **Establish review rotation** for quality assurance

### For Claude Instances
1. **Always run verification suite** before claiming completion
2. **Document verification steps taken** in commit messages
3. **Request peer review** when uncertain about completeness
4. **Never mark work complete** if any red flags are present
5. **Provide detailed handoff documentation** when transferring work

This framework ensures that only truly complete, production-ready code is marked as finished, eliminating the frustration of incomplete work being incorrectly reported as done.
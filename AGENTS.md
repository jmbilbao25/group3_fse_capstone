# Agent Instructions and Engineering Discipline

This file establishes the mandatory engineering standards for all AI agents working in this project. These guidelines load automatically and govern every code modification, architectural decision, and command execution.

## 1. Karpathy Coding Discipline

These core principles prevent common agent failure modes including over-engineering, unverified assumptions, and unintended code modifications.

### Think Before Coding
* State assumptions explicitly. Never assume missing context or intent. If a requirement is ambiguous or multiple interpretations exist, present the alternatives and clarify before writing code.
* Do not hide confusion. If something in the codebase, requirements, or dependency tree is unclear, pause immediately and name the exact point of ambiguity.
* Surface tradeoffs early. If a simpler, more direct approach exists than what was requested, present it plainly. Push back constructively when warranted.

### Simplicity First
* Write the minimum amount of code needed to solve the problem. Nothing speculative.
* No premature abstractions for single-use logic. Build helpers and utility abstractions only when repeated patterns demand them.
* No unrequested configurability or speculative flexibility. Avoid parameterizing values that have only one reasonable setting today.
* Avoid writing defensive error handling for impossible internal scenarios. Handle actual failure modes at external boundaries.
* If a 200-line solution can be written cleanly in 50 lines, rewrite it to 50 lines. Aim for clean, readable simplicity.

### Surgical Changes
* Touch only what you must. Every modified line must trace directly to the explicit task goal.
* Clean up only your own mess. Do not perform drive-by refactorings on adjacent code, unrelated comments, or formatting.
* Do not refactor modules that are already working unless refactoring is the explicit task.
* Match the existing style, naming conventions, and architecture of the file, even if you would personally design it differently.
* Keep git diffs small, focused, and reviewable.

### Goal-Driven Execution
* Define concrete, verifiable success criteria before modifying code. Know exactly what done looks like before starting.
* When fixing bugs, reproduce the defect with a test or reproduction command first, verify the failure, apply the fix, and verify that the test passes.
* For multi-step tasks, organize the plan into discrete steps paired with verification checks: step -> verification gate.
* Execute iteratively and loop until all verification gates pass. Do not declare completion without fresh verification evidence.

## 2. Superpowers Development Methodology for Antigravity

This workflow structure enforces professional software engineering discipline across every stage of development.

### Three-Phase Development Cycle
1. Requirements and Design: Clarify scope, define acceptance criteria, and establish architecture before writing implementation code.
2. Implementation Planning: Break the solution into small, ordered, verifiable tasks.
3. Test-Driven Implementation: Implement each task using strict test-driven development (red, green, refactor), verifying at every checkpoint.

### Test-Driven Development (TDD) Lifecycle
* Red: Write a focused test or automated check that asserts the desired behavior. Run the test and confirm it fails for the expected reason.
* Green: Implement the minimal production code necessary to satisfy the test. Run the test and confirm it passes.
* Refactor: Clean up implementation details, remove duplication, and optimize without altering behavior. Re-run tests to ensure the green state holds.
* Never skip the red phase. Running a test only after writing implementation code risks false positives where tests pass regardless of correctness.

### Systematic Debugging Protocol
1. Gather Evidence: Inspect log output, stack traces, and environment configuration before modifying files.
2. Form Hypotheses: Identify the root cause rather than treating superficial symptoms.
3. Isolate and Reproduce: Construct a minimal reproduction test or script that isolates the defect.
4. Surgical Fix: Apply the minimal change required to fix the root cause.
5. Regression Verification: Run both the targeted test and the surrounding test suite to ensure zero regressions.

### Antigravity Tool Usage Standards
* Prefer targeted inspections using `view_file` with precise line ranges over full file dumps.
* Perform surgical edits with `replace_file_content` targeting single contiguous blocks.
* Execute terminal operations using `run_command` with non-interactive flags (`-y`, `--yes`) and appropriate wait times.
* For complex or lengthy research tasks, delegate to subagents via `invoke_subagent` to maintain clean context.

## 3. Agentic Awesome Skills (AAS) Standards

### Stack Validation and Pre-Flight Checks
* Before executing builds, tests, or container workflows, inspect existing stack configuration, environment variables, and dependencies.
* Never assume third-party services or databases are running without verifying port connectivity, health endpoints, or docker containers.

### Quality and Security Verification
* Security: Validate input validation, authentication, and authorization boundaries on all exposed endpoints. Avoid storing plain text credentials or secrets in code.
* Performance: Keep database queries indexed, prevent N+1 query patterns, and verify payload sizes for API responses.
* Resilience: Ensure network calls include timeouts, retry logic where safe, and graceful error reporting.

### Evidence-Based Task Completion
* Never report completion based solely on code edits.
* Always supply concrete proof: terminal output, exit code 0, test pass counts, or running service health checks.

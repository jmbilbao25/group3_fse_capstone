---
name: using-superpowers
description: >-
  Master Superpowers agentic software engineering framework: spec-driven development,
  systematic brainstorming, implementation planning, test-driven development (TDD),
  and verification loops using native Antigravity tools. Use PROACTIVELY when planning,
  architecting, executing complex features, or debugging.
---

# Superpowers Engineering Framework for Antigravity

Superpowers converts conversational AI coding into structured, professional software engineering. Instead of rushing to write code, follow disciplined phases: Brainstorm, Specify, Plan, Execute with TDD, and Verify.

---

## Antigravity Native Tool Protocol

When executing Superpowers workflows in Antigravity, map upstream operations directly to native tools:

| Operation | Native Antigravity Tool | Best Practice |
| :--- | :--- | :--- |
| Read File | `view_file` | Read specific line ranges; avoid reading multi-megabyte files entirely. |
| Edit File | `replace_file_content` | Target single contiguous replacement blocks; preserve indentation. |
| Create File | `write_to_file` | Use for greenfield files or complete rewrites. |
| Terminal / Shell | `run_command` | Use non-interactive flags (`-y`, `--yes`); avoid blocking sleeps. |
| Parallel Work | `invoke_subagent` | Launch isolated research or audit tasks to conserve context. |
| Task Monitoring | `manage_task` | Check status or send input without polling in tight loops. |

---

## 1. Brainstorming and Specification

Never write implementation code on an ambiguous or incomplete premise.

### Protocol:
1. Clarify the core intent: Understand the true problem being solved.
2. Explore alternatives: Present two to three viable architectural approaches with trade-offs.
3. Define acceptance criteria: Explicit, testable outcomes required for success.
4. Establish non-functional requirements: Performance limits, security constraints, and compatibility targets.

---

## 2. Implementation Planning

Translate specifications into concrete, bite-sized tasks.

### Plan Structure:
* Each task represents an incremental, logically atomic step.
* Every task must specify:
  1. Target files and components.
  2. Concrete changes required.
  3. Associated verification checkpoint (e.g., unit test command, curl verification, linter run).
* Order tasks strictly so that dependencies are satisfied before consumers are built.

---

## 3. Test-Driven Development (TDD) Cycle

Superpowers mandates strict red-green-refactor execution:

```
[Red] Write failing test -> Run test and verify expected failure
  |
[Green] Write minimal production code -> Run test and verify it passes
  |
[Refactor] Clean up code without altering behavior -> Verify tests remain green
```

### Critical Rules:
* Never write production logic before having a failing test or verifiable check.
* Verify test failure reason: Ensure the test fails because the feature is missing, not because of a syntax error or broken import.
* Write the minimum code needed to turn the test green. Avoid premature optimization during the green step.

---

## 4. Systematic Debugging Protocol

When a test fails, bug reports occur, or unexpected behavior is observed:

1. **Observe and Gather Evidence**: Read logs, stack traces, and relevant code. Do not guess.
2. **Form Hypothesis**: Identify the single root cause mechanism explaining the defect.
3. **Reproduce**: Create a minimal automated test or command demonstrating the bug.
4. **Isolate and Fix**: Apply the surgical fix addressing the root cause.
5. **Verify Zero Regressions**: Run the full test suite to guarantee surrounding behavior is intact.

---

## 5. Review and Evidence Delivery

Before reporting completion to the user:
* Run the complete test suite.
* Review git diff to ensure no unrelated files or formatting churn were introduced.
* Present the concrete terminal proof (test pass counts, build exit code 0) alongside a concise explanation.

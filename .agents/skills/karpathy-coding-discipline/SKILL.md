---
name: karpathy-coding-discipline
description: >-
  Enforce Andrej Karpathy's core coding discipline to eliminate common agent mistakes:
  think before coding, simplicity first, surgical changes, and goal-driven execution.
  Use whenever modifying code, refactoring, fixing bugs, or implementing new features.
---

# Karpathy Coding Discipline

This skill operationalizes Andrej Karpathy's core observations on AI coding pitfalls. It enforces restraint, explicit reasoning, surgical modifications, and test-driven verification across all coding tasks.

## Core Rules Checklist

Before, during, and after modifying code, verify against these four rules:

```
[ ] 1. Think Before Coding: Assumptions stated? Ambiguities clarified? Tradeoffs surfaced?
[ ] 2. Simplicity First: Minimal code? No premature abstractions? No unasked flexibility?
[ ] 3. Surgical Changes: Touched only what was needed? Existing style matched? Diff minimal?
[ ] 4. Goal-Driven Execution: Verifiable criteria defined? Tested before and after? Evidence verified?
```

---

## 1. Think Before Coding

Prevent silent assumptions, hidden confusion, and premature implementation.

### Before Touching Any Code:
1. State your assumptions explicitly. If requirements leave room for interpretation, pause and state the alternatives. Do not silently select one option.
2. If any aspect of the codebase, library API, or expected behavior is confusing or ambiguous, stop immediately. Name the exact question and confirm with the user.
3. If a simpler, more direct approach exists than the one proposed, explain it plainly. Suggest the cleaner alternative rather than blindly implementing complex requests.

---

## 2. Simplicity First

Prevent over-engineering, speculative abstractions, and bloated diffs.

### Rules of Construction:
1. Write the minimum amount of code required to solve the immediate problem. Nothing speculative.
2. Ban premature abstractions for single-use logic. Only extract shared helpers when multiple call sites already require identical behavior.
3. Do not add unrequested configurability, generic flags, or dynamic plugin hooks. Solve today's exact problem directly.
4. Do not write complex error handling or defensive guards for impossible internal invariants. Focus error handling on external boundaries (network, disk, user inputs).
5. Code budget review: If a solution took 200 lines and could be written cleanly in 50 lines, discard the bloat and rewrite it in 50 lines.

---

## 3. Surgical Changes

Prevent collateral damage, style churn, and drive-by refactorings.

### Rules of Modification:
1. Touch only the files and lines strictly necessary for the task. Every altered line must directly trace to the user request.
2. Never perform drive-by refactorings. Do not "clean up" adjacent functions, reformat whitespace, rename variables in untouched routines, or rewrite comments that were not part of the task.
3. If existing code uses a specific convention (naming style, promise handling, formatting, error conventions), match it exactly. Do not enforce personal style preferences over the established project conventions.
4. Clean up only your own mess: Remove temporary debug logs, test artifacts, and newly unused imports created by your own edit. Do not purge unrelated dead code unless explicitly requested.

---

## 4. Goal-Driven Execution

Prevent task drift, unverified fixes, and premature completion declarations.

### Execution Workflow:
1. Define verifiable success criteria before editing code. Answer: "How will I prove this works?"
   * For bug fixes: Write a reproduction test or script that fails on current code, run it to confirm the failure, implement the fix, then run it again to confirm it passes.
   * For new features: Define the exact test, endpoint assertion, or CLI check that validates the output.
2. Break multi-step tasks into clear pairs of action and verification:
   * Action step -> Verification checkpoint.
3. Run verification gates before declaring done. Inspect actual terminal outputs and exit codes. Never declare completion based on assumption.

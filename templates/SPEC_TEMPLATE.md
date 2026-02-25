# Project Spec: {{ PROJECT_NAME }}

<!--
HOW TO USE THIS TEMPLATE
─────────────────────────
1. Copy this file to your project root as SPEC.md
2. Answer the guiding questions (<!-- Q: ... -->) in each section
3. Replace all {{ PLACEHOLDERS }} with your decisions
4. Delete any section that genuinely does not apply
5. Reference this file in CLAUDE.md:
     "Read SPEC.md before making any changes. Interface contracts in Section 4 are immutable."

SECTIONS
  1. Overview & Goals
  2. Architecture Decisions
  3. Directory Structure
  4. Interface Contracts       ← most important for Claude Code
  5. Component Contracts
  6. Naming Contracts
  7. Configuration Rules
  8. Contract Tests
  9. Definition of Done
-->

---

## 1. Overview & Goals

<!-- Q: What problem does this project solve, in one sentence? -->
<!-- Q: What are the 2-3 non-negotiable design goals? (e.g. reproducibility, modularity, performance) -->

{{ ONE_SENTENCE_DESCRIPTION }}

This project is designed to achieve:

- {{ GOAL_1 }}
- {{ GOAL_2 }}
- {{ GOAL_3 }}

---

## 2. Architecture Decisions & Rationale

<!--
Q: What are the major structural choices made in this project?
Q: For each choice, why was it made over the alternative?
Q: What rules follow from each decision?

Format: one block per decision.
  - "Why X over Y?" — state the tradeoff
  - "Rule:" — the concrete constraint that follows

Example decisions: framework choice, config strategy, abstraction boundaries,
state management, persistence layer, communication pattern between modules.
-->

### Why {{ DECISION_1 }}?

{{ RATIONALE_1 }}

> **Rule:** {{ RULE_THAT_FOLLOWS_1 }}

### Why {{ DECISION_2 }}?

{{ RATIONALE_2 }}

> **Rule:** {{ RULE_THAT_FOLLOWS_2 }}

---

## 3. Directory Structure

<!--
Q: What are the top-level directories and what is each one responsible for?
Q: What is explicitly forbidden in each directory? (e.g. "no side effects in utils/")
Q: Where do tests live?
-->

```
{{ PROJECT_ROOT }}/
  {{ DIR_1 }}/    # {{ RESPONSIBILITY_1 }}
  {{ DIR_2 }}/    # {{ RESPONSIBILITY_2 }}
  {{ DIR_3 }}/    # {{ RESPONSIBILITY_3 }}
  tests/
    test_contracts.py   # Interface contract enforcement — always present
    {{ TEST_DIR }}/     # {{ WHAT_IS_TESTED }}
```

---

## 4. Interface Contracts

<!--
Q: What are the core abstractions in this project? (e.g. Model, DataLoader, Handler, Service)
Q: For each abstraction, what methods/functions MUST exist?
Q: What are the input and output types for each? Be as specific as possible.
Q: Which of these must never change without explicit sign-off?

⚠️  This section is the primary defense against Claude Code silently
    renaming functions or changing signatures. Be explicit and precise.
    Include actual code where possible — prose is not enough.
-->

> ⚠️ The contracts defined here must NOT be changed without explicit sign-off.
> This applies to: method signatures, return types, data shapes, and class hierarchy.
> Internal implementations are freely modifiable. Contracts are not.

### 4-1. Core Abstraction: {{ ABSTRACTION_NAME }}

```python
# {{ FILE_PATH }}  ← this file is the contract document

{{ INTERFACE_CODE }}

# Example:
#
# from abc import ABC, abstractmethod
#
# class BaseHandler(ABC):
#
#     @abstractmethod
#     def load(self, path: str) -> None:
#         """Load state from path."""
#         ...
#
#     @abstractmethod
#     def run(self, input: {{ INPUT_TYPE }}) -> {{ OUTPUT_TYPE }}:
#         """
#         Args:
#             input: {{ INPUT_DESCRIPTION }}
#         Returns:
#             {{ OUTPUT_DESCRIPTION }}
#         """
#         ...
#
#     @abstractmethod
#     def get_config(self) -> dict:
#         """Return serializable config."""
#         ...
```

### 4-2. Data Shape / Schema Contracts

<!--
Q: What are the shapes, types, or schemas of the primary data structures?
Q: What are the valid ranges or constraints?

Use a table. For ML: tensor shapes. For web: request/response schemas. For CLI: stdin/stdout format.
-->

| Variable | Type / Shape | Notes |
|----------|-------------|-------|
| {{ VAR_1 }} | {{ TYPE_1 }} | {{ NOTE_1 }} |
| {{ VAR_2 }} | {{ TYPE_2 }} | {{ NOTE_2 }} |

---

## 5. Component Contracts

<!--
Q: What are the major components (classes or modules) and what does each own?
Q: For each component, what methods are mandatory?
Q: What are the constraints on each method? (e.g. "no I/O in __init__", "must be idempotent")

One table per component.
-->

### {{ COMPONENT_1 }} (`{{ COMPONENT_1_PATH }}`)

| Method | Responsibility | Constraint |
|--------|---------------|------------|
| `{{ METHOD_1 }}` | {{ WHAT_IT_DOES }} | {{ CONSTRAINT }} |
| `{{ METHOD_2 }}` | {{ WHAT_IT_DOES }} | {{ CONSTRAINT }} |

> **Rule:** {{ KEY_RULE_FOR_THIS_COMPONENT }}

### {{ COMPONENT_2 }} (`{{ COMPONENT_2_PATH }}`)

| Method | Responsibility | Constraint |
|--------|---------------|------------|
| `{{ METHOD_1 }}` | {{ WHAT_IT_DOES }} | {{ CONSTRAINT }} |
| `{{ METHOD_2 }}` | {{ WHAT_IT_DOES }} | {{ CONSTRAINT }} |

> **Rule:** {{ KEY_RULE_FOR_THIS_COMPONENT }}

---

## 6. Naming Contracts

<!--
Q: What actions or concepts have a single correct name in this codebase?
Q: What names are explicitly forbidden to prevent ambiguity?

This prevents Claude Code from "improving" load() to load_weights() or from_checkpoint().
-->

| Action / Concept | Required Name | Forbidden Alternatives |
|-----------------|--------------|----------------------|
| {{ ACTION_1 }} | `{{ NAME_1 }}` | {{ FORBIDDEN_1 }} |
| {{ ACTION_2 }} | `{{ NAME_2 }}` | {{ FORBIDDEN_2 }} |
| {{ ACTION_3 }} | `{{ NAME_3 }}` | {{ FORBIDDEN_3 }} |

---

## 7. Configuration Rules

<!--
Q: How is configuration managed in this project?
Q: What must never be hardcoded?
Q: How are environment-specific overrides handled?
Q: What is the composition strategy? (layered configs, env vars, flags, etc.)
-->

- {{ CONFIG_RULE_1 }}  *(e.g. "No hardcoded paths — all go into config files")*
- {{ CONFIG_RULE_2 }}  *(e.g. "Environment overrides live in .env, never in source")*
- {{ CONFIG_RULE_3 }}  *(e.g. "Experiment configs override defaults, never duplicate them")*

---

## 8. Contract Tests (`tests/test_contracts.py`)

<!--
Q: What is the minimal set of tests that proves the contracts in Section 4 are intact?
Q: These tests must run on every commit — keep them fast and dependency-light.

Three test categories to always include:
  1. Structural — does the class hierarchy hold?
  2. Signature — have method signatures drifted?
  3. Behavior — does input → output match the contract?
-->

```python
import inspect
import pytest
from {{ MODULE_PATH }} import {{ BASE_CLASS }}, {{ CONCRETE_CLASS_1 }}


ALL_IMPLEMENTATIONS = [{{ CONCRETE_CLASS_1 }}]  # Register every implementation here


def test_all_implementations_extend_base():
    """No implementation may bypass the contract."""
    for cls in ALL_IMPLEMENTATIONS:
        assert issubclass(cls, {{ BASE_CLASS }}), \
            f"{cls.__name__} must extend {{ BASE_CLASS }}"


def test_core_method_signature_unchanged():
    """Catch accidental signature drift on the primary method."""
    sig = inspect.signature({{ BASE_CLASS }}.{{ CORE_METHOD }})
    params = list(sig.parameters.keys())
    assert params == {{ EXPECTED_PARAMS }}, \
        f"Signature changed to: {params}"


@pytest.mark.parametrize("cls", ALL_IMPLEMENTATIONS)
def test_output_contract(cls):
    """Verify output matches the contract in Section 4-2."""
    instance = cls()
    result = instance.{{ CORE_METHOD }}({{ DUMMY_INPUT }})
    assert isinstance(result, {{ EXPECTED_OUTPUT_TYPE }})
    # Add shape / schema assertions specific to your contract
```

---

## 9. Definition of Done

<!--
Q: What does "this feature is complete" mean for this project?
Q: What must always be true, regardless of the feature?

Keep this as a checklist. Claude Code should be able to self-check against it.
-->

A feature is complete when **all** of the following are true:

- [ ] Implements the contract defined in Section 4 — registered in `ALL_IMPLEMENTATIONS`
- [ ] No hardcoded values — all configuration follows Section 7
- [ ] `tests/test_contracts.py` passes
- [ ] At least one behavior test exists covering the primary input → output path
- [ ] Naming follows Section 6 — no forbidden alternatives used
- [ ] {{ PROJECT_SPECIFIC_CRITERION_1 }}
- [ ] {{ PROJECT_SPECIFIC_CRITERION_2 }}

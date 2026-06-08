# Changelog

All notable changes to hukuhaka-claude are documented here. The project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Plugin versions (`marketplace/<plugin>/.claude-plugin/plugin.json`) are
independent — see those files for their own history.

## [1.0.6] — 2026-06-08

### Fixed

- Installing `hukuhaka-project-mapper` on a host without `tree-sitter` is no
  longer blocked. The dependency preflight mistook the plugin's own internal
  Python modules for missing third-party packages and trapped the installer
  in a dependency prompt that could never be satisfied. Plugin Python imports
  are now treated as non-blocking, and `tree-sitter` is correctly optional
  (it accelerates symbol extraction; map-sync falls back to a generic
  extractor when it is absent). Regression introduced in 1.0.5.
- `install.sh` now exits `0` on a successful run (it previously leaked a
  non-zero status from its cleanup step), so `curl … | bash` callers that
  check the exit code see success.

## [1.0.5] — 2026-06-05

### Removed

- `codex-coworker` skill (`skills/codex-coworker/`) — retired. For Codex
  second opinions, use the official OpenAI plugin
  (`openai/codex-plugin-cc`) instead.
- `gemini-coworker` skill (`skills/gemini-coworker/`) — retired alongside
  its sibling; the Gemini CLI it wraps is being discontinued upstream.

### Changed

- `hukuhaka-project-mapper` plugin bumped 1.0.2 → 1.1.0.
  - `/map-sync` analyze stage restructured: code structure (symbols,
    import graph, TODOs, stack) is now extracted **deterministically by
    bundled scripts** with zero LLM involvement; two restricted agents
    (`describe`, `synth`) write only the prose over that skeleton from a
    script-assembled context bundle. Structural hallucination (invented
    paths/symbols) is rejected at merge time by construction. Generated
    doc format and quality are unchanged.
  - Measurably faster and cheaper: on the reference testbed, median sync
    wall-clock −52% and cost −42% versus the previous exploring
    analyzer, with the worst-case exploration tail eliminated.
  - New: when a sync completes, a hook reports the run's wall-clock and
    exact billed token usage inline.
  - The `analyzer` agent is unchanged and continues to power `/audit`.
- `hukuhaka-project-mapper` `/map-sync` structural extraction extended to
  multi-language repos (follow-up on top of 1.1.0; plugin version
  unchanged). Previously only Python files got real symbols and dependency
  edges — non-Python sources fell through to a generic stub:
  - Optional tree-sitter symbol extraction via `tree-sitter-language-pack`,
    with vendored tag queries for 13 languages (Apache-2.0, attributed).
    Without the dependency, every file falls back to the previous regex
    behavior — worst case is exactly the old output, and the fallback is
    counted on stderr so degradation is visible.
  - Import extraction for 9 language families, always on (regex,
    no extra dependency). Imports that resolve to a repo file become
    `depends_on` edges; externals are dropped. Resolvers: js/ts (relative
    + extension inference + `index` barrels), c/c++ (quoted includes,
    unique-basename fallback), go (`go.mod` module prefix), java/kotlin
    (package suffix match), ruby (`require_relative`).
  - Declaration files merge into their definitions when they share a
    directory and stem (`.h`/`.hpp` vs `.c`/`.cpp`, `.d.ts` vs `.ts`) —
    headers no longer appear as duplicate components.
  - Stack detection now reads `build.gradle(.kts)`, `pom.xml`, `go.mod`,
    `Cargo.toml`, `Gemfile`, and `CMakeLists.txt` in addition to
    `pyproject.toml`/`package.json`, at any directory depth (monorepo
    `frontend/`/`backend/` layouts contribute). Manifest-declared entry
    points (`mainClass`, `bin`, `add_executable`, `[[bin]]`) feed entry
    detection.
- Global router template (`templates/CLAUDE.md`) slimmed: "Think Before
  Coding" renamed to "Think Before Acting"; "Suggestions" and "Team vs
  Subagent" sections removed; "Proposing Changes" absorbed into a
  compressed "Reporting"; "Debug" tightened.

## [1.0.4] — 2026-06-02

### Added

- `hukuhaka-report-builder` skill (`skills/hukuhaka-report-builder/`) —
  staged-workflow generator for long-form editorial HTML reports
  (masthead + numbered article + hand-built inline-SVG figures +
  sources). A preflight locks the report's design axes and scaffolds a
  per-report directory with its own `spec.md` before drafting, so the
  visual identity is fixed up front instead of drifting mid-generation.
- `hukuhaka-project-mapper` `/map-scan` command — emits a
  `.claude/scan.md` scatter manifest (per-directory keep/scatter
  decisions) that `/map-sync` then consumes. Classification is
  script-driven; user overrides live below a marker in the same file.

### Changed

- `hukuhaka-project-mapper` plugin bumped 1.0.1 → 1.0.2.
  - `/map-sync` reordered to **scatter-first, then incremental**. It now
    regenerates only the scatter `CLAUDE.md` directories that changed
    since the last sync (git-diff based) instead of every scatter row on
    every run — a large cost reduction on big repos. First run, the
    `--full` flag, or a non-git project falls back to a full sync.
  - Skill → command collapse: the `map-setup` / `map-scan` /
    `map-maintain` / `map-sync` skills were folded directly into their
    slash commands, removing a layer of skill indirection.
  - A `SessionStart` hook now supplies project context in place of the
    previous global-`CLAUDE.md` injection.
- `hukuhaka-ltm`: commands now declare `allowed-tools`, dropping the
  per-tool permission prompts that previously interrupted runs.

### Removed

- `hukuhaka-project-mapper` `/map-validate` command and its orphaned
  helper script removed.

## [1.0.3] — 2026-05-22

### Changed

- `hukuhaka-ltm` plugin bumped 0.4.0 → 0.5.0. Distill agent prompts
  rewritten — numeric thresholds replaced with qualitative tone
  guidance, eliminating an echo-stub failure mode where writers
  copied frontmatter into the body. Body authoring now adapts to
  topic shape instead of length targets.

## hukuhaka-ltm plugin 0.5.0 — 2026-05-22

### Changed

- Distill agent prompts (writer, validate, cluster, l1-update,
  final-review) switched from numeric floors/caps to qualitative
  tone guidance.
- `scripts/distill.py`: removed an internal per-line cap on
  `pinned.md` additions; the 2KB total file cap remains.

## [1.0.2] — 2026-05-21

### Added

- `gemini-coworker` skill (`skills/gemini-coworker/`) — sibling to
  `codex-coworker`, ports the same ask / review / compare workflow to
  Google's Gemini CLI as a parallel second-opinion path. Read-only via
  `--approval-mode plan --skip-trust`; stdout/stderr captured
  separately so non-fatal Gemini warnings don't corrupt JSON output.
- Persona + per-command framing for both `codex-coworker` and
  `gemini-coworker`. The external model now receives a role-identity
  prefix and ask/compare framing inside the same heredoc that already
  carries prompt-injection defences. Eliminates the prior failure mode
  where the sibling model hedged across options because it didn't know
  Claude would synthesize its reply.
- `templates/CLAUDE.md`: new *Reporting* stance — for non-trivial
  changes, surface As-is → Problem → To-be in order before acting, so
  the user can intervene at any layer instead of reverse-engineering
  the proposal.

### Changed

- `hukuhaka-project-mapper` plugin bumped 1.0.0 → 1.0.1. Marketplace
  directory renamed `marketplace/project-mapper/` →
  `marketplace/hukuhaka-project-mapper/` for prefix consistency with
  the rest of the bundle. Plugin name in `plugin.json` and the
  `/hukuhaka-project-mapper:*` slash command namespace are unchanged —
  no end-user-visible behavior change, internal layout only.
- `hukuhaka-ltm` plugin bumped 0.1.0 → 0.4.0. See the per-version
  plugin entries below (0.2.0 → 0.2.1 → 0.2.2 → 0.4.0) for the full
  pipeline redesign. Short version: `/ltm:distill` collapsed from a
  7-agent lock-step into a 6-step skeleton (cluster → file-mapping →
  N parallel writers → validate → l1-update → final-review) with
  body-authoring writers and a main-context Step 2 file map.
- `team` skill renamed to `hukuhaka-team` for prefix consistency.
- `codex-coworker` un-deprecated. Previously default-off and marked
  deprecated; now an active sibling to `gemini-coworker`. Use either
  or both for cross-model triangulation.

### Removed

- `hukuhaka-report` skill removed entirely. The prior IBM/Carbon and
  Figma baselines were both wiped pending a fresh design pass. The
  skill will return under a new design in a later release.

## hukuhaka-ltm plugin 0.4.0 — 2026-05-21

### Changed (breaking — pipeline collapsed to 6-step skeleton)

- `/ltm:distill` collapsed from a 7-agent lock-step (cluster + plan +
  validate + cluster-l1 + plan-l1 + validate-l1 + writer with multi-stage
  YAML actions + 2-revise loops at each tier) to a **6-step skeleton**:
  **cluster** (subagent: L3 → axes) → **file mapping** (main context, not
  a subagent: maps each axis to one of `edit | create | create-merging |
  retire | noop` against the existing L2 corpus, surfaces an assignment
  YAML for the user gate) → **N parallel writers** (subagents, one per
  assignment: author full reference body, not just frontmatter fields) →
  **validate** (subagent: per-card cold-read for stub regression,
  evidence drift, cross-card duplication) → **l1-update** (single
  subagent that reads new L2 corpus + current pinned.md and edits
  pinned.md directly) → **final-review** (single subagent: end-to-end
  anomaly report; read-only).
- `plan.md`, `plan-l1.md`, `cluster-l1.md`, `validate-l1.md` agents
  deleted. Their responsibilities collapsed into main-context file
  mapping (Step 2) + the new `l1-update.md` + the new `final-review.md`.
- `agents/writer.md` rewritten — input is now one assignment row + L3
  bodies + (if applicable) existing card content. Writer uses Write/Edit
  directly to author the card *body* in addition to frontmatter; the old
  `_render_card_body` mechanical assembly is removed. Reference exemplar
  for body density is `index/git-publish-workflow.md` (the only
  hand-authored card from prior cycles).
- `agents/validate.md` rewritten — was per-axis cold-read of a PLAN
  document; now per-card cold-read of finished cards on disk, reporting
  `{issues: [{card, problem, severity}]}` rather than ship/revise/reject.

### Removed

- `_render_card_body`, `_body_was_hand_edited`, `_read_body_stdin`,
  `_write_card`, `cmd_apply`, `cmd_merge`, `cmd_retire`, `_TOPIC_RE`
  from `scripts/distill.py`. The `apply`, `merge`, and `retire` CLI
  subcommands are gone — v0.4.0 writers use Write/Edit directly.
- 6-op enum (`{create, extend, set-evidence, merge, retire, noop}`)
  presented as a constrained action menu in plan PLANs. Step 2 in the
  v0.4.0 command uses similar op names as descriptive labels, but no
  YAML schema is enforced — main context emits assignments freely.
- Per-axis revise loop (≤2 retries). Validators surface issues; user
  re-spins individual writers as needed via the Step 4 gate.

### Added

- `agents/l1-update.md` — one subagent that reads the new L2 corpus +
  current `pinned.md` + policy and edits `pinned.md` to align L1 with
  L2. Replaces the cluster-l1 + plan-l1 + validate-l1 + writer (add-pin
  / retire-pin) sequence. Same 2KB cap.
- `agents/final-review.md` — read-only cross-tier anomaly check: orphan
  L3, pinned line without L2 backing, cross-card content duplication,
  evidence-body mismatch, supersedes drift, pinned.md over-cap.
  Reports; does not auto-fix.

### Why

v0.3.0 distill produced 11 of 12 L2 cards with body = `# {summary}` +
`{context}` echo because `_render_card_body` mechanically assembled body
from frontmatter fields and plan agents had no body-authoring contract.
The only "real" reference card (`git-publish-workflow.md`) was
hand-edited by the user. Cluster + plan also had a structural gap that
made cross-axis L2 merge impossible: cluster grouped L3s without seeing
L2; per-axis plans couldn't touch other axes' cards. The result was
monotonic index growth (10 → 12 over two cycles, with no retires) and
five single-L3 axes that obviously belonged together.

v0.4.0 fixes both: writers author body, and main-context file mapping
in Step 2 sees the full L2 corpus + cluster's axes simultaneously,
enabling `create-merging` and `retire` decisions that the per-axis plan
agents couldn't reach. The "trust AI" alignment is intentional — every
v0.1→v0.3 increment added schema to fight echo and produced new echo
surfaces; v0.4.0 removes schema and adds peer review (validate) +
user-gated assignment + final-review anomaly scan instead.

### Migration

L2 card frontmatter shape, L3 `distilled-into` 3-state pointer, and the
reproject + pin scan/apply CLI utilities are unchanged. Existing L2
cards with stub bodies will be detected and rewritten by writers on the
first v0.4.0 distill cycle. Hand-authored bodies (e.g.,
`git-publish-workflow.md`) are preserved by writer prompts when their
density already exceeds the stub bar.

## hukuhaka-ltm plugin 0.2.2 — 2026-05-20

### Changed (breaking — pipeline architecture)

- `/ltm:distill --retroactive` rebuilt as a **fluid 3-phase pipeline**:
  **cluster** (one agent reads all L3, decomposes into semantic axes with
  no mechanical size rule and no axis cap) → **plan** (axis-parallel
  fan-out — one agent per axis, sees axis L3 + full L2 corpus, writes a
  free-form markdown PLAN ending in a YAML actions block composing
  write-API actions `{create, extend, set-evidence, merge, retire,
  noop}`) → **validate** (axis-parallel fan-out, cold read — fresh agent
  per axis sees L3 + L2 + PLAN markdown only, returns `ship | revise |
  reject` + reason; revise loop bound = 2 retries per axis) → dry-run
  gate → **writer** (sequential per approved action) → deterministic
  `distill.py reproject`.
- v0.2.1's `extractor`, `clusterer`, `reconciler` agents deleted. Their
  responsibilities collapse into the new `cluster` + `plan` + `validate`
  triad. The 6-op enum, mandatory `counter_evidence` schema, reserved-
  phrase blocklist, and mechanical `size >= 2 → promote_candidate` rule
  are all removed — defence against echo migrates from schema gates to
  independent cold-read peer review.
- `agents/writer.md` slimmed — input is now an action dict parsed from
  PLAN YAML, not a reconciler proposal. Action types map 1:1 to existing
  `distill.py` write subcommands.
- `scripts/validate_proposals.py` deleted. Structural validation is
  replaced by validator agent's cold-read judgment. YAML parsing happens
  inline in the command orchestrator (Python heredoc, `yaml.safe_load`).

### Why

v0.2.1's staged pipeline + structural schema closed the v0.2.0 "already
cited" echo path on `extend`/`create`/`set-evidence`/`merge`/`retire` but
left `keep` exempt from `counter_evidence` burden. Real-data run on this
project produced 7 single-L3 "already cited" `keep` proposals — the v0.2.0
echo failure migrated one op over. v0.2.2 stops adding schema gates and
instead removes the menu entirely: the plan agent composes actions (not
picks from an enum); the validate agent peer-reviews cold. Same architectural
shape as `project-mapper`'s analyzer/auditor/verifier pattern.

### Migration

None for data shape — L2 card frontmatter, L3 `distilled-into` 3-state
pointer, and `distill.py` write API are all unchanged. Re-run `/ltm:distill
--retroactive` after upgrade; the new pipeline re-reconciles the full
corpus and proposes `retire` for paraphrase cards that v0.2.1's `keep`
loophole let through.

## hukuhaka-ltm plugin 0.2.1 — 2026-05-19

### Changed (breaking)

- `/ltm:distill --retroactive` rebuilt again — body-first reconciliation
  pipeline replaces v0.2.0's frontmatter-only discoverer/validator/writer
  triad. New 4-stage pipeline: **extractor** (reads full L3 bodies, emits
  atomic claims with line refs) → **clusterer** (semantic grouping with
  mechanical `size >= 2 → promote_candidate` rule, L2-blind) →
  **reconciler** (sees L2 for the first time, emits 6 ops `{extend,
  create, set-evidence, merge, retire, keep}` with structural
  `counter_evidence`) → orchestrator-side substring validation + dry-run
  gate → **writer** (sequential per approved op) → deterministic
  `distill.py reproject`. Same-class sweep on every run.
- `discoverer.md` and `validator.md` agents deleted (v0.2.0 contracts
  too entangled with the frontmatter-only failure mode for clean rewrite).
  Replaced by `extractor.md`, `clusterer.md`, `reconciler.md`.
- `distill.py apply --action` now accepts `set-evidence` (replaces the
  evidence list rather than merging). `extend` semantics unchanged.
- `keep` is a first-class reconciler op — explicit "no meaningful change"
  outcome, distinct from absence. Coverage invariant: every L2 card +
  every cluster appears in exactly one proposal modulo `keep`.

### Added

- `agents/extractor.md`, `agents/clusterer.md`, `agents/reconciler.md` —
  three new body-first agents replacing v0.2.0's three.
- `distill.py merge --topic <winner> --merge-from <loser>` — union
  evidence of winner + loser into winner, auto-add loser to `supersedes`,
  delete loser. Refuses if winner body has been hand-edited (auto-render
  mismatch detection).
- `distill.py retire --topic <slug>` — delete card. Reconciler-emitted op
  (gated by dry-run). `undo` retained as the user-driven escape (different
  audit trail).
- `scripts/validate_proposals.py` — orchestrator-side structural
  validation of reconciler output. For every non-`keep` proposal: checks
  every `counter_evidence` row's `l3_id` resolves to a log file, the
  `line_ref` parses, and the `entails` string is a literal substring of
  the cited L3 file at that line range. Also blocks v0.2.0 echo phrases
  (`"already cited"`, `"likely cited at"`, etc.) in `reason` fields.
  Drop rate > 30% triggers reconciler retry once.

### Migration

None — v0.2.0 data shape (3-state `distilled-into` pointer, L2 card
frontmatter) unchanged. v0.2.1 only changes how the pipeline computes
deltas. First v0.2.1 `--retroactive` run re-reconciles the full L2
corpus from scratch — expect `retire` proposals for any 1:1-paraphrase
cards that v0.2.0's permissive rubric let through.

## hukuhaka-ltm plugin 0.2.0 — 2026-05-19

### Changed (breaking)

- `/ltm:distill --retroactive` rebuilt around a 4-step subagent pipeline:
  `discoverer` (proposes L2 state delta from full L3 + L2 corpus + project
  policy) → user assent gate → `validator` (per-row peer review reading
  full bodies) → `writer` (per-row card create/extend) → deterministic
  `reproject` (syncs L3 `distilled-into` from L2 evidence). Replaces the
  v0.1.x for-each-cluster draft loop that was prone to single-entry
  narrative over-promotion.
- L3 frontmatter: `distilled: true|false` boolean **removed**. Replaced
  by `distilled-into` 3-state pointer (absent = unscanned, `[]` =
  scanned-uncited, `[index/foo.md, ...]` = currently cited). L2 evidence
  list is now the single source of truth; L3 pointer is a derived cache
  that `reproject` rebuilds every distill.
- `distill.py apply` requires `--action {extend,create}`. `extend` rejects
  if the card doesn't exist; `create` rejects if it does. Output is JSON
  `{card, action, evidence_added}`.
- `distill.py undo` no longer reverts a per-entry boolean — it deletes
  the card and auto-runs `reproject` so previously-citing L3 entries
  lose the pointer to the removed card.
- `scan` subcommand removed entirely (the discoverer subagent supersedes
  slug-prefix clustering + undistilled filter).

### Added

- `agents/discoverer.md`, `agents/validator.md`, `agents/writer.md` —
  the three subagents the new pipeline spawns sequentially.
- `distill.py reproject` — deterministic L3 pointer sync. Idempotent.
  Handles v0.1.x → v0.2.x migration (drops legacy `distilled` boolean,
  rewrites scalar `distilled-into` strings as lists). Reports orphan
  citations to stderr.
- Project-level policy surface: `.claude/ltm/CLAUDE.md` may declare L2
  axis inventory, cardinality caps, single-card topics, naming
  conventions, kind-based promotion overrides. Fed verbatim to the
  discoverer; honored as preconditions.

### Migration

First `/ltm:distill --retroactive` on a v0.1.x project runs `reproject`
automatically — drops the legacy boolean from every L3, rewrites any
scalar `distilled-into: index/foo.md` as `distilled-into: [index/foo.md]`.
No manual migration needed. Idempotent — running `reproject` standalone
beforehand is also safe.

## [1.0.1] — 2026-05-19

### Changed

- `skills/hukuhaka-report/`: hero display token bumped 54px → 60px. One step
  above Carbon `display-04`, calibrated for the 1200 max-width report
  hero container so it carries more typographic weight without
  inheriting the marketing-hero scale of `fluid-display-05` (76px).

## [1.0.0] — 2026-05-14

Fresh start. The pre-1.0 git history was discarded as part of a repository
architecture migration. The public repository was reinitialized to host only
the publish artifacts (`marketplace/`, `skills/`, `templates/`, `scripts/`,
plus `README`, `LICENSE`, `CHANGELOG`, `VERSION`). Internal development
artifacts (the eval framework, project documentation, `.claude/` workspace,
LTM history) now live in a separate private repository and never reach this
repo.

### Plugins at 1.0.0

- **hukuhaka-project-mapper** `1.0.0` — codebase analysis and `.claude/` documentation
  generation. Skills: `map-setup`, `map-sync`, `map-maintain`, `map-spec`,
  `audit`, `trace`, `backlog`.
- **hukuhaka-ltm** `0.1.0` — long-term memory plugin with three-tier
  storage (L1 pinned, L2 indexed cards, L3 raw log), autonomous L3 append
  via `<ltm-record>` markers parsed by the Stop hook, batch L2 distillation
  via `/hukuhaka-ltm:ltm-distill`.

### Notes

- Pre-1.0 development tracked plugin features, the eval framework, install
  flow, and documentation. That history is preserved in the private
  development repository but is not relevant to public consumers of the
  marketplace plugins.
- The split between development repository and public repository is the
  governance change that motivated 1.0.0 — see internal documentation.

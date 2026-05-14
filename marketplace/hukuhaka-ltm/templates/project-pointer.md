<!-- hukuhaka-ltm:begin -->
## LTM (Long-Term Memory)

This project uses [hukuhaka-ltm](https://github.com/hukuhaka/hukuhaka-claude/tree/main/marketplace/hukuhaka-ltm) for accumulated knowledge that does not belong in code or current-state docs.

- Location: `.claude/ltm/`
- Rules: see `.claude/ltm/CLAUDE.md` (loaded lazily by `ltm-recall` / `ltm-append` skills)
- Entry point: `/ltm:init` to bootstrap, `/ltm:declare-rule` to evolve rules
<!-- hukuhaka-ltm:end -->

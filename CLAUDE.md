# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace Overview

This workspace contains two independent projects:

- **[fsi-aml-fraud-detection/](fsi-aml-fraud-detection/)** — ThreatSight 360: financial fraud detection + AML/KYC compliance system (dual-backend microservices)
- **[pixelden/](pixelden/)** — Gaming e-commerce platform (Next.js 14)

---

## ThreatSight 360 (fsi-aml-fraud-detection)

Full development guidance is in [fsi-aml-fraud-detection/docs/CLAUDE.md](fsi-aml-fraud-detection/docs/CLAUDE.md) and [fsi-aml-fraud-detection/aml-backend/CLAUDE.md](fsi-aml-fraud-detection/aml-backend/CLAUDE.md).

### Quick Commands

```bash
make setup_all      # Install all dependencies
make dev_all        # Start all three services
make dev_fraud      # Main backend only (port 8000)
make dev_aml        # AML backend only (port 8001)
make dev_frontend   # Frontend only (port 3000)
make test_all       # Run all tests
```

### Architecture

Three services running concurrently:

1. **Main Backend** (`backend/`, FastAPI, port 8000) — transaction screening, risk scoring, fraud pattern detection via AWS Bedrock + MongoDB Vector Search
2. **AML Backend** (`aml-backend/`, FastAPI, port 8001) — entity resolution, KYC compliance, relationship network analysis; uses clean architecture (models → repositories → services)
3. **Frontend** (`frontend/`, Next.js 15+, port 3000) — LeafyGreen UI, Cytoscape.js network visualization, App Router

Key integration points: MongoDB Atlas (Search + Vector Search + Change Streams) and AWS Bedrock (Claude-3 Sonnet embeddings).

---

## PixelDen (pixelden)

### Commands

```bash
cd pixelden
npm run dev     # Development server (port 3000)
npm run build   # Production build
npm run lint    # Linter
npm start       # Production server (after build)
```

### Issue Tracking (bd/beads)

This project uses `bd` (beads) — **do not use markdown TODOs**.

```bash
bd ready --json                    # Find available work
bd show <id>                       # View issue details
bd update <id> --claim --json      # Claim a task atomically
bd create "title" -t bug|feature|task -p 0-4 --json  # Create issue
bd close <id> --reason "Done"      # Complete work
bd sync                            # Sync with git
```

Always use `--json` flag for programmatic output. Link discovered work with `--deps discovered-from:<parent-id>`.

### Session Completion (Landing the Plane)

Work is **not complete** until `git push` succeeds:

```bash
git pull --rebase && bd sync && git push
```

Close finished issues in bd, create new issues for remaining work before ending session.

### Architecture

Next.js 14 App Router with Tailwind CSS and TypeScript. State managed via React Context (`context/` — CartContext, AuthContext, OrderContext) and the `mayor/rig/` module. Static data lives in `data/`. No backend — purely frontend application.

Shell commands: always use non-interactive flags (`cp -f`, `mv -f`, `rm -f`) to avoid hanging on confirmation prompts.

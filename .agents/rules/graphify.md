---
trigger: always_on
description: Consult the graphify knowledge graph at graphify-out/ for codebase and architecture questions.
---

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- **Never grep blindly before querying the graph:** When `graphify-out/graph.json` exists, always start codebase, domain, or UI-library lookups with `query_graph`, `get_node`, `get_neighbors`, `get_community`, or `shortest_path` (MCP) — or `graphify query "<question>"`, `graphify path "<A>" "<B>"`, `graphify explain "<concept>"` (CLI).
- Use cases: (1) Impact analysis on existing `lib/` symbols before editing, (2) Locating `forui` widget/theme concepts in `forui-llms-full.txt` and `DESIGN.md` rules without scanning full files, (3) Tracing domain rules across `PRODUCT.md` and `GLOSSARY.md`.
- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost).

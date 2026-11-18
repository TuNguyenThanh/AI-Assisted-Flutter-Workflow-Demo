# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp>=1.2,<2", "pyyaml>=6"]  # pinned: mcp 2.x renamed FastMCP
# ///
"""project-docs MCP server.

Gives Claude Code direct, read-only access to the project's requirements
and API contract, so the agent works from the *source of truth* instead of
whatever the developer remembers to paste into the prompt.

In a real team this server wraps the Jira / Confluence REST API; here it
reads markdown tickets and an OpenAPI file from `docs/` so the demo runs
offline.

Run standalone:  uv run --script tool/project_mcp/server.py
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import yaml
from mcp.server.fastmcp import FastMCP

ROOT = Path(os.environ.get("PROJECT_ROOT", ".")).resolve()
REQ_DIR = ROOT / "docs" / "requirements"
SPEC_DIR = ROOT / "docs" / "specs"
OPENAPI = ROOT / "docs" / "api" / "openapi.yaml"
TICKET_ID = re.compile(r"^[A-Z]+-\d+$")

mcp = FastMCP("project-docs")


def _title(path: Path) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem


@mcp.tool()
def list_requirements() -> list[dict[str, str]]:
    """List all requirement tickets (id, title, file)."""
    return [
        {"id": p.stem.split("-", 2)[0] + "-" + p.stem.split("-", 2)[1],
         "title": _title(p),
         "file": str(p.relative_to(ROOT))}
        for p in sorted(REQ_DIR.glob("*.md"))
    ]


@mcp.tool()
def get_requirement(ticket_id: str) -> str:
    """Return the full requirement ticket (markdown) plus its approved spec,
    if one exists. `ticket_id` looks like 'AUTH-001'."""
    ticket_id = ticket_id.strip().upper()
    if not TICKET_ID.match(ticket_id):
        return f"Invalid ticket id: {ticket_id!r}. Expected e.g. AUTH-001."

    matches = sorted(REQ_DIR.glob(f"{ticket_id}-*.md"))
    if not matches:
        return f"No requirement found for {ticket_id}."

    out = [matches[0].read_text(encoding="utf-8")]
    spec = SPEC_DIR / f"{ticket_id}-spec.md"
    if spec.exists():
        out.append("\n---\n# Approved spec\n")
        out.append(spec.read_text(encoding="utf-8"))
    return "\n".join(out)


@mcp.tool()
def get_api_contract(path: str = "") -> str:
    """Return the OpenAPI contract. With `path` (e.g. '/auth/login') only
    that endpoint plus referenced schemas are returned, to save context."""
    spec = yaml.safe_load(OPENAPI.read_text(encoding="utf-8"))
    if not path:
        return yaml.safe_dump(spec, sort_keys=False)

    paths = spec.get("paths", {})
    if path not in paths:
        return f"Unknown path {path!r}. Available: {', '.join(paths)}"
    subset = {
        "servers": spec.get("servers"),
        "paths": {path: paths[path]},
        "components": spec.get("components", {}),
    }
    return yaml.safe_dump(subset, sort_keys=False)


if __name__ == "__main__":
    mcp.run()

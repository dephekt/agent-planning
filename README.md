# Agent Planning

Durable design briefs and exploration→plan docs for agent-driven work, mirroring
the `~/upsun/dephekt/agent-planning` docs system (mkdocs + Material). One markdown
file per topic ("slug") under `docs/briefs/`; Mermaid diagrams render inline.

## Serve / build

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
mkdocs serve        # http://127.0.0.1:8000
mkdocs build        # static site → site/
```

## Briefs

- `docs/briefs/grow-control-system.md` — MQTT/multi-site grow control architecture.

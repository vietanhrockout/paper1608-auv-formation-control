# Scripts

- `validation/` — Phase B validation and Phase C post-analysis launchers.
- `diagnostics/` — historical C0 and K–P investigation launchers.

Launchers resolve the repository from their own file locations, so they can be invoked from any working directory, for example:

```bash
matlab -batch "run('scripts/validation/run_b3.m')"
```

The supported production entrypoint remains [`../run_phase_c.m`](../run_phase_c.m). Diagnostic launchers are preserved for provenance; several target intentionally invalidated or computationally expensive solver paths, so read the corresponding comments and [`../docs/HANDOFF.md`](../docs/HANDOFF.md) before running them.

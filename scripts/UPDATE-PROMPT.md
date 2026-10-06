# Update this temporary branch

Use `bash scripts/update.sh --config-only` from a clone of the requested branch.
It pulls the current branch, not main. For a ZIP download or offline copy, run:

```bash
python3 scripts/install-config.py
python3 scripts/install-config.py --verify
```

See `docs/COMPANY-MACHINE.md` for destination paths, backups and verification.
The portable update preserves MCPs, settings, credentials and local learnings.

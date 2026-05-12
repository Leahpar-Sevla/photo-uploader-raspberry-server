# Project maturity status

The Photo Uploader project is currently in a **controlled field validation phase**.

The technical base has already been validated in the lab. The next goal is to validate real-world operation with collaborators before expanding to multiple Raspberry Pi devices.

## Current maturity level

| Level | Status | Description |
|------|--------|-------------|
| M0 | Done | Idea and architecture defined |
| M1 | Done | Raspberry base structure created |
| M2 | Done | Camera import into local sessions |
| M3 | Done | Raspberry diagnostic workflow |
| M4 | Done | Linux server integration with Raspberry |
| M5 | Done | Manual server pull validated |
| M6 | Done | Automatic server pull using systemd timer |
| M7 | Done | Safe cleanup of Raspberry `enviados/` |
| M8 | In progress | Field validation with collaborator |
| M9 | Planned | 15-day usage report |
| M10 | Planned | 30-day usage report |
| M11 | Planned | Expansion to multiple Raspberry Pi devices |

## Validated technical capabilities

- [x] Raspberry local folder structure is standardized.
- [x] Camera import script exists.
- [x] Raspberry diagnostic script exists.
- [x] Linux server connects to Raspberry via Tailscale and SSH.
- [x] Server pulls ready sessions from Raspberry.
- [x] Server uses `rsync` over SSH.
- [x] Server runs automatic pull using `systemd timer`.
- [x] Server copies sessions to `.tmp` before final destination.
- [x] Server creates `.PULLED_BY_SERVER` after successful pull.
- [x] Server records downloads in `.controle/baixados.log`.
- [x] Server records errors in `.controle/erros.log`.
- [x] Raspberry moves pulled sessions to `enviados/`.
- [x] Raspberry cleanup acts only on `enviados/`.
- [x] Logs exist on both Raspberry and server.

## Field validation goals

The field test must prove that the system works under real operational conditions, not only in a technical lab.

The validation must confirm:

- [ ] The collaborator can operate the workflow without technical commands.
- [ ] Photos appear on the server without manual intervention.
- [ ] The camera is reliably detected.
- [ ] The Raspberry remains stable using the selected power source.
- [ ] Sessions do not remain stuck in `importando/`.
- [ ] Ready sessions do not remain stuck in `pendentes/`.
- [ ] Incomplete sessions do not appear in the server final folder.
- [ ] Samba users access only the Linux server, not the Raspberry.
- [ ] Backup includes `EXTERNAS/` and preserves `.controle/`.

## Expansion criteria

New Raspberry Pi devices should only be added after positive field reports.

Minimum criteria for expansion:

- [ ] 15 days of use with no photo loss.
- [ ] 30 days of use with no recurring critical failure.
- [ ] Collaborator can operate the process without constant technical support.
- [ ] Photos appear on the server without manually running scripts.
- [ ] No ready session remains stuck in `pendentes/`.
- [ ] No incomplete session appears in the server final folder.
- [ ] Server `.controle/` folder remains preserved.
- [ ] Backup includes `EXTERNAS/` and does not delete `.controle/`.
- [ ] Logs do not show repeated SSH, Tailscale, rsync, or permission errors.
- [ ] Import and pull times are acceptable for real operation.
- [ ] Power supply or powerbank keeps the Raspberry stable during real use.

If any critical item fails, expansion must be paused until correction and a new validation cycle.

## Operational status

| Area | Status | Notes |
|-----|--------|-------|
| Architecture | Approved | Server pulls from Raspberry |
| Raspberry CAM-01 | Field validation | Initial real-world test |
| Server | Lab approved | Automatic pull validated |
| Real camera workflow | In progress | Continuous use must be validated |
| Collaborator operation | In progress | Reports required |
| 15-day report | Pending | Required before expansion |
| 30-day report | Pending | Required before expansion |
| Multiple Raspberrys | Planned | Only after positive reports |

## Main architectural decision

The Raspberry does **not** actively push photos to the server.

Official flow:

```text
Camera
↓
Raspberry imports photos
↓
Raspberry creates a session in pendentes/ with .READY
↓
Linux server pulls the session via SSH/rsync
↓
Server stores files in EXTERNAS/CAM-XX/
↓
Server creates .PULLED_BY_SERVER
↓
Server moves the remote session to enviados/
↓
Raspberry periodically cleans enviados/
```

This keeps the Raspberry lightweight and lets the Linux server centralize storage, logs, Samba access, and backup.

## Production note

This project should not be described as a mass-production deployment yet.

Current recommended wording:

```text
Technical base validated in the lab.
Operational pilot in progress.
Expansion depends on positive 15-day and 30-day field reports.
```

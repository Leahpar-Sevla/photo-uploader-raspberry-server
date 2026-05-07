# Step 06 — Raspberry sent cleanup

Script:

```text
/opt/photo-uploader/bin/cleanup_sent.sh
```

Timer:

```text
photo-cleanup-sent.service
photo-cleanup-sent.timer
```

Rule:

```text
if enviados/ has fewer than 10 sessions:
  delete nothing

if enviados/ has 10 or more sessions:
  delete old sessions
  keep only the newest one
```

Never clean automatically:

```text
pendentes/
importando/
erro/
logs/
controle/
```

Safe test:

```bash
DRY_RUN=1 /opt/photo-uploader/bin/cleanup_sent.sh
```

# Step 07 — Full homologation

Validate the complete workflow before production use.

Checklist:

```text
[ ] camera detected
[ ] import_from_camera.sh imports real photos
[ ] session appears in pendentes/
[ ] session contains .READY
[ ] server pulls automatically
[ ] files appear in EXTERNAS/CAM-XX/
[ ] .PULLED_BY_SERVER is created
[ ] baixados.log is updated
[ ] remote session moves to enviados/
[ ] cleanup does not delete before threshold
[ ] cleanup works at threshold
[ ] Samba can access EXTERNAS
[ ] backup preserves .controle/
[ ] backup ignores .tmp as final session
```

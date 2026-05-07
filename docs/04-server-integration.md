# Step 04 — Server integration

Validate that the server can access the Raspberry.

Checklist:

```text
ping or tailscale ping works
SSH with password works
SSH key works
server can list /var/photo-spool/CAM-XX/pendentes
rsync --dry-run works
EXTERNAS/CAM-XX exists on server
```

Example dry-run:

```bash
rsync -av --dry-run \
  -e "ssh -i /home/photo-sync/.ssh/rasp_cam01" \
  photo-sync@100.xxx.xxx.xxx:/var/photo-spool/CAM-01/pendentes/ \
  /srv/server/EXTERNAS/CAM-01/
```

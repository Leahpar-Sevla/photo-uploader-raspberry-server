# Step 05 — Server pull

Script:

```text
/opt/photo-server/bin/pull_externas.sh
```

Config:

```text
/etc/photo-server/rasps.conf
```

Rules:

```text
read rasps.conf
find sessions with .READY
copy to .tmp first
move to final folder after success
create .PULLED_BY_SERVER
write baixados.log
move remote session from pendentes/ to enviados/
```

Timer:

```text
photo-pull-externas.service
photo-pull-externas.timer
```

Default interval:

```text
45 seconds
```

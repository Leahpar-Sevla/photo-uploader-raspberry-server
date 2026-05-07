# Step 02 — Camera import

Script:

```text
/opt/photo-uploader/bin/import_from_camera.sh
```

Responsibilities:

```text
detect camera with gphoto2
copy files to importando/
create manifest.txt
create .READY
move complete session to pendentes/
```

The server will later pull sessions from `pendentes/`.

The script does not delete files from the camera.

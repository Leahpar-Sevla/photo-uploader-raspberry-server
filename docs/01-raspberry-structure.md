# Step 01 — Raspberry base structure

Creates the base structure on the Raspberry.

Creates:

```text
/etc/photo-uploader/config.env
/opt/photo-uploader/bin/
/var/photo-spool/CAM-XX/
```

The Raspberry does not send files to the server. It only prepares local folders and configuration.

Run:

```bash
sudo /opt/photo-uploader/bin/setup_structure.sh
```

Expected structure:

```text
/var/photo-spool/CAM-XX/
├── importando/
├── pendentes/
├── enviados/
├── erro/
├── logs/
└── controle/
```

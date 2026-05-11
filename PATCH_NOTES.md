# Patch notes — 2026-05-11

Este pacote atualiza o projeto Photo Uploader com os ajustes testados em laboratório no Raspberry Pi 3.

## Arquivos novos/alterados

```text
raspberry/scripts/import_from_camera.sh
raspberry/scripts/import_from_camera_incremental.sh
raspberry/scripts/diagnostic.sh
raspberry/scripts/cleanup_sent.sh
raspberry/systemd/photo-cleanup-sent.service
raspberry/systemd/photo-cleanup-sent.timer
server/config/rasps.conf.example
docs/importacao-incremental.md
docs/homologacao-lab-2026-05-11.md
examples/field-operator-flow.md
```

## Principal mudança

Foi adicionada a importação incremental:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh
```

Ela evita reimportar fotos antigas do cartão da câmera.

## Como aplicar no repositório local

Na raiz do repositório:

```bash
cp -r photo-uploader-update-2026-05-11/* .
git status
git add raspberry/scripts/import_from_camera.sh \
        raspberry/scripts/import_from_camera_incremental.sh \
        raspberry/scripts/diagnostic.sh \
        raspberry/scripts/cleanup_sent.sh \
        raspberry/systemd/photo-cleanup-sent.service \
        raspberry/systemd/photo-cleanup-sent.timer \
        server/config/rasps.conf.example \
        docs/importacao-incremental.md \
        docs/homologacao-lab-2026-05-11.md \
        examples/field-operator-flow.md \
        PATCH_NOTES.md

git commit -m "Add Raspberry Pi 3 lab updates and incremental camera import"
git push
```

## Como aplicar no Raspberry

```bash
sudo cp raspberry/scripts/*.sh /opt/photo-uploader/bin/
sudo chmod +x /opt/photo-uploader/bin/*.sh
sudo chown dev:dev /opt/photo-uploader/bin/*.sh

sudo cp raspberry/systemd/photo-cleanup-sent.service /etc/systemd/system/
sudo cp raspberry/systemd/photo-cleanup-sent.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now photo-cleanup-sent.timer
```

## Uso do incremental

Criar base inicial do cartão atual sem copiar fotos:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh --seed-current
```

Uso normal depois disso:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh
```

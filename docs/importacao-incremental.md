# Importação incremental da câmera

## Objetivo

Evitar que o Raspberry copie novamente todas as fotos da câmera quando o fotógrafo esquece de formatar o cartão.

O script incremental lista os arquivos da câmera, compara com um histórico local e baixa apenas os arquivos novos.

Script:

```text
/opt/photo-uploader/bin/import_from_camera_incremental.sh
```

Histórico local:

```text
/var/photo-spool/CAM-XX/controle/camera_imported_files.tsv
```

## Como funciona

Chave de comparação usada:

```text
nome do arquivo + tamanho + timestamp informado pelo gphoto2
```

Fluxo:

```text
câmera conectada
↓
gphoto2 --list-files
↓
compara com camera_imported_files.tsv
↓
baixa só arquivos novos com gphoto2 --get-file
↓
cria manifest.txt
↓
cria .READY
↓
move sessão para pendentes/
↓
atualiza histórico somente após sucesso
```

## Criar base inicial sem baixar de novo

Use quando o cartão já tem fotos que foram importadas antes:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh --seed-current
```

Esse comando marca os arquivos atuais da câmera como conhecidos.
Não cria sessão em `pendentes/`.
Não copia fotos.

## Importar somente fotos novas

Depois do seed inicial:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh
```

Resultado esperado:

```text
Arquivos encontrados na câmera: N
Arquivos novos para importar: X
Baixando novo arquivo...
Criando manifest.txt
Criando marcador .READY
Movendo sessão para pendentes/
```

## Atenção operacional

`--seed-current` não é comando de importação.
Ele serve para dizer ao Raspberry: "considere o cartão atual como já conhecido".

Uso normal em campo:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh
```

## Compatibilidade com o fluxo oficial

A arquitetura continua igual:

```text
Raspberry importa fotos
↓
Raspberry cria sessão em pendentes/ com .READY
↓
Servidor puxa via SSH/rsync
↓
Servidor move sessão remota para enviados/
```

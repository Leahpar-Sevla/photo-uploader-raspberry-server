# Homologacao - Hotplug e importacao incremental por arquivos novos

Data: 2026-05-11
Raspberry: rp3-cam-01
CAM_ID: CAM-01
Servidor: dev-server
Destino no servidor: /srv/server/EXTERNAS/CAM-01

## Objetivo

Registrar o ajuste do fluxo automatico de camera para que a sessao seja criada somente quando houver arquivos novos na camera.

Regra validada:

```text
Conexao USB = gatilho
Historico incremental = fonte da verdade
Arquivo novo = cria sessao
Sem arquivo novo = nao cria sessao
```

## Arquivos atualizados

```text
raspberry/scripts/on_camera_connected.sh
raspberry/scripts/import_from_camera_incremental.sh
raspberry/systemd/photo-camera-hotplug.service
raspberry/systemd/photo-camera-hotplug.timer
```

## Teste 1 - camera conectada sem fotos novas

Resultado observado:

```text
Arquivos encontrados na camera: 265
Arquivos novos para importar: 0
Nenhum arquivo novo encontrado.
Nenhuma sessao sera criada.
```

Status:

```text
[OK] Nenhuma sessao vazia foi criada.
[OK] Nada foi movido para pendentes/.
[OK] O historico incremental impediu duplicidade.
```

## Teste 2 - camera conectada com fotos novas

Resultado observado:

```text
Arquivos encontrados na camera: 268
Arquivos novos para importar: 3
Sessao: CAM-01_2026-05-11_161445
Baixando novo arquivo #266: _MG_0959.JPG -> 001__MG_0959.JPG
Baixando novo arquivo #267: _MG_0960.JPG -> 002__MG_0960.JPG
Baixando novo arquivo #268: _MG_0961.JPG -> 003__MG_0961.JPG
Criando manifest.txt
Criando marcador .READY
Movendo sessao para pendentes/
Atualizando historico incremental
```

Status:

```text
[OK] Sessao criada somente porque havia arquivos novos.
[OK] 3 fotos foram importadas.
[OK] manifest.txt foi criado.
[OK] .READY foi criado.
[OK] Sessao foi movida para pendentes/.
[OK] Historico incremental foi atualizado.
```

## Validacao do servidor

Sessao validada:

```text
CAM-01_2026-05-11_160619
```

Arquivos encontrados no servidor:

```text
001__MG_0932.JPG
002__MG_0933.JPG
003__MG_0934.JPG
004__MG_0935.JPG
manifest.txt
.PULLED_BY_SERVER
.READY
```

Registro em baixados.log:

```text
2026-05-11 19:06:56|CAM-01|CAM-01_2026-05-11_160619|/var/photo-spool/CAM-01/pendentes/CAM-01_2026-05-11_160619|/srv/server/EXTERNAS/CAM-01/CAM-01_2026-05-11_160619|FILES=5
```

Status:

```text
[OK] Servidor puxou a sessao.
[OK] Servidor criou .PULLED_BY_SERVER.
[OK] Servidor registrou em baixados.log.
[OK] Servidor moveu a sessao no Raspberry de pendentes/ para enviados/.
```

## Decisao final

A sessao nao sera mais tratada como cada conexao fisica da camera.

Definicao operacional:

```text
Sessao = lote de um ou mais arquivos novos encontrados na camera.
```

Isso evita:

```text
- sessao vazia
- sessao duplicada por oscilacao USB/PTP
- nova sessao quando o colaborador reconecta a camera sem tirar fotos
- dependencia de marcador de conexao fisica
```

## Status final

```text
[OK] Hotplug automatico ajustado
[OK] Importacao incremental ajustada
[OK] Sessao so nasce com arquivo novo
[OK] Sem arquivo novo, nenhuma sessao e criada
[OK] Servidor ja validado no fluxo de pull
```

# Benchmark - Importacao da camera no Raspberry

Data: 2026-05-12
Raspberry: rp3-cam-01
CAM_ID: CAM-01
Sessao testada: CAM-01_2026-05-12_100343

## Objetivo

Medir em tempo real quanto tempo o Raspberry leva para importar um lote real de fotos da camera.

## Resultado do teste

```text
Arquivos encontrados na camera: 397
Arquivos novos para importar: 48
Tempo total: 51s
Media: 1.06 segundos por foto
Velocidade: 56.47 fotos por minuto
Codigo de saida: 0
```

## Estimativa operacional

Com base no teste:

```text
30 fotos x 1.06s = aproximadamente 32s
```

Com o servidor puxando a cada 45 a 60 segundos, a expectativa pratica e:

```text
~32s para importar 30 fotos no Raspberry
+ ate 45-60s para o servidor encontrar a sessao
= cerca de 1 a 1,5 minuto para aparecer no servidor
```

## Validacao do fluxo

A sessao seguiu o fluxo seguro:

```text
importando/
manifest.txt
.READY
pendentes/
servidor puxa depois
```

## Status

```text
[OK] Raspberry importou 48 fotos em 51s
[OK] Media real: 1.06s/foto
[OK] Estimativa para 30 fotos: ~32s
[OK] Timer do servidor em 45s e adequado
```

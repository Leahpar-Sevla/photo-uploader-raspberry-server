# Fluxo operacional de campo

## Início do dia

1. Formatar o cartão pela própria câmera.
2. Confirmar que o Raspberry está ligado.
3. Confirmar que o servidor está online, quando houver rede.

## Durante o dia

1. Fotógrafo tira fotos normalmente.
2. Ao final da sessão/atendimento, conecta a câmera ao Raspberry.
3. Operador roda:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh
```

4. Se houver rede, o servidor puxa automaticamente.
5. Se a rede estiver ruim, a sessão fica em `pendentes/` no Raspberry e o servidor puxa depois.

## Regra importante

Não formatar a câmera se a sessão ainda não foi confirmada pelo menos no Raspberry.
O ideal é confirmar que a sessão saiu de `pendentes/` e entrou em `enviados/`, ou que o servidor criou `.PULLED_BY_SERVER`.

## Quando usar seed

Use somente para criar a base inicial do cartão atual, sem importar de novo:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh --seed-current
```

Depois disso, o uso normal é sem parâmetro:

```bash
/opt/photo-uploader/bin/import_from_camera_incremental.sh
```

# Homologação de laboratório — 2026-05-11

## Escopo

Validação em laboratório com Raspberry Pi 3, câmera Canon EOS 80D e servidor Linux de testes.

## Resultado geral

```text
[OK] Raspberry configurado como CAM-01
[OK] Hostname validado: rp3-cam-01
[OK] Estrutura /var/photo-spool/CAM-01 criada
[OK] gphoto2 detecta Canon EOS 80D
[OK] import_from_camera.sh importa sessão completa
[OK] tratamento de falha PTP move sessão parcial para erro/
[OK] diagnostic.sh executa e registra log
[OK] cleanup_sent.sh executa em DRY_RUN e pelo systemd service
[OK] photo-cleanup-sent.timer ativo no Raspberry
[OK] Tailscale conectado
[OK] servidor de testes acessa Raspberry via SSH por chave
[OK] rsync --dry-run aprovado
[OK] pull_externas.sh manual aprovado
[OK] photo-pull-externas.timer aprovado
[OK] fluxo completo câmera → Raspberry → servidor → enviados aprovado
[OK] importação incremental aprovada
```

## Ajustes aplicados

### 1. import_from_camera.sh

Foi ajustado para tratar falha durante `gphoto2 --get-all-files`.
Se a cópia falhar, a sessão parcial é movida de `importando/` para `erro/`.

### 2. import_from_camera_incremental.sh

Novo script criado para baixar somente fotos novas da câmera.

Teste validado:

```text
Arquivos na câmera: 137
Arquivos já conhecidos no histórico: 131
Arquivos novos importados: 6
Sessão criada: CAM-01_YYYY-MM-DD_HHMMSS
Servidor puxou automaticamente
Sessão movida para enviados/
```

### 3. cleanup_sent.sh

Limpa somente `enviados/`.
Com menos de 10 sessões, não apaga nada.
Com 10 ou mais, mantém apenas a sessão mais recente.

## Observações para produção

1. Não expor IPs reais de Tailnet em repositório público.
2. Confirmar o caminho real de EXTERNAS no servidor real antes de instalar.
3. No servidor real, verificar se já existe `photo-pull-externas.timer` ativo antes de mexer.
4. Preferir importação incremental em campo.
5. Em local com rede ruim, o Raspberry pode manter sessões em `pendentes/` até o servidor conseguir puxar.

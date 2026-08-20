# Cyrus CRM — backend FastAPI

Backend Python da migração do CRM. O serviço usa o schema PostgreSQL existente, sem Alembic ou alterações de banco.

## Requisitos

- Python 3.12 a 3.14
- [uv](https://docs.astral.sh/uv/)
- PostgreSQL já criado pelo projeto Rails

## Configuração

O serviço usa as mesmas variáveis que já existem no ambiente Rails. Não copie valores de produção para o repositório.

```dotenv
DATABASE_URL=postgresql://user:password@host:5432/crm
TEST_DATABASE_URL=postgresql://user:password@host:5432/crm_test
AR_ENCRYPTION_PRIMARY_KEY=...
AR_ENCRYPTION_DETERMINISTIC_KEY=...
AR_ENCRYPTION_KEY_DERIVATION_SALT=...
JWT_SECRET=...
```

`DATABASE_URL` é a única fonte da conexão de runtime. Durante `pytest`, o backend substitui esse valor por `TEST_DATABASE_URL`.

`JWT_SECRET` é obrigatório para login e rotas autenticadas. Nenhuma variável Meta é necessária para o cliente cadastrar seu próprio token: o endpoint de canais recebe o token e o cifra antes de persistir.

As variáveis abaixo são opcionais e só habilitam a entrada de webhooks Meta centralizados:

```dotenv
META_WEBHOOK_VERIFY_TOKEN=...
META_WEBHOOK_APP_SECRET=...
```

Sem elas, apenas as rotas de webhook retornam `503`; cadastro de canais e tokens continua disponível.

## Executar

```bash
cd backend
uv sync --group dev
uv run uvicorn app.main:app --reload
uv run pytest
```

O health check em `GET /health` retorna `200` somente depois de executar uma consulta simples no PostgreSQL; falhas retornam `503` sem dados de conexão.

## Endpoints migrados

- `POST /api/v1/profiles`: bootstrap do primeiro `super_admin`.
- `POST /api/v1/profiles/invite`: criação autenticada de perfis.
- `POST /api/v1/auth/login`: login e token Bearer JWT.
- `POST /api/v1/channels`: upsert de canal e token Meta/Instagram cifrado, fornecido pelo cliente.
- `POST /api/v1/contacts`, `GET /api/v1/conversations` e `POST /api/v1/conversations/{id}/messages`: atendimento básico por tenant.
- `POST /api/v1/conversations/{id}/handoff`: transfere conversa para a fila humana e cria uma notificação.
- `GET`/`PATCH /api/v1/settings`: configurações de IA do tenant.
- `GET`/`POST /api/v1/webhooks/meta`: verificação e ingestão idempotente de mensagens Meta.

## Compatibilidade de credenciais Rails

`whatsapp_access_token` e `instagram_access_token` são cifrados pelo Active Record Encryption. `app/rails_encryption.py` implementa apenas a leitura do formato não determinístico configurado neste Rails 8.1 (AES-256-GCM, PBKDF2-HMAC-SHA256 e serializer JSON), usando as três chaves de ambiente.

Essa camada cifra e lê tokens, mas nunca os inclui em schemas de resposta, logs ou exceções. Rotação de chaves e chamadas de saída para Meta/IA permanecem fora deste backend: a migração persiste a intenção e o estado da operação, sem enviar mensagens a provedores externos.

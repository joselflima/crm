# Cyrus CRM API

Backend multi-tenant do Cyrus CRM, construído com FastAPI, SQLAlchemy assíncrono e PostgreSQL. O banco existente é a fonte de verdade do schema; o projeto não executa migrations nem Alembic.

## Estrutura

| Caminho | Finalidade |
| --- | --- |
| `backend/app/` | Aplicação FastAPI, modelos, autenticação, rotas e cifragem compatível com Rails. |
| `backend/tests/` | Testes de regressão, contratos OpenAPI, modelos, banco e cifragem. |
| `backend/pyproject.toml` | Dependências e configuração do `uv`/pytest. |
| `AGENTS.md` | Regras obrigatórias de desenvolvimento, incluindo TDD. |

## Requisitos

- Python 3.12 a 3.14
- [uv](https://docs.astral.sh/uv/)
- Acesso ao PostgreSQL configurado no `.env`

## Configuração

Crie o arquivo local de configuração a partir do exemplo versionado:

```bash
cp .env.example .env
```

Preencha os valores reais apenas no `.env`, que não é versionado. `DATABASE_URL` é usada pela aplicação; durante `pytest`, ela é substituída por `TEST_DATABASE_URL`.

As chaves `AR_ENCRYPTION_*` permitem ler e gravar os tokens WhatsApp/Instagram no formato de cifragem existente. `JWT_SECRET` assina os JWTs de login; ele é uma chave do servidor, não o token do usuário. As variáveis `META_WEBHOOK_*` são opcionais e necessárias apenas para receber webhooks; o cadastro de tokens fornecidos pelo cliente não depende delas.

## Rodar localmente

```bash
cd /Users/joselucas/Desktop/Projetos/cyrus/crm/backend
uv sync --group dev
uv run uvicorn app.main:app --reload
```

O servidor inicia em `http://127.0.0.1:8000`.

Verifique banco e aplicação:

```bash
curl http://127.0.0.1:8000/health
```

## OpenAPI e Swagger

Com o servidor iniciado:

- [Swagger UI](http://127.0.0.1:8000/docs): explorar rotas, schemas, respostas e fazer requisições.
- [OpenAPI JSON](http://127.0.0.1:8000/openapi.json): contrato legível por ferramentas.
- [ReDoc](http://127.0.0.1:8000/redoc): documentação de referência.

Para usar rotas protegidas no Swagger:

1. Faça `POST /api/v1/auth/login`.
2. Copie o `access_token` retornado.
3. Clique em **Authorize** e cole o token Bearer.

## Onboarding inicial

1. Crie o primeiro `super_admin` em `POST /api/v1/profiles`, com `tenant_id: null`.
2. Faça login em `POST /api/v1/auth/login`.
3. Com esse JWT, crie um tenant via `POST /api/v1/tenants`.
4. Convide o primeiro `admin` do tenant por `POST /api/v1/profiles/invite`, usando o `tenant_id` retornado.
5. O admin faz login e cadastra canais em `POST /api/v1/channels`.

Um `super_admin` sem `tenant_id` não opera recursos de um tenant, como canais. Um `admin` ou `agent` só acessa dados do próprio tenant.

## Rotas atuais

| Método | Rota | Acesso | Descrição |
| --- | --- | --- | --- |
| `GET` | `/health` | Público | Confere aplicação e banco. |
| `POST` | `/api/v1/profiles` | Público, apenas bootstrap | Cria o primeiro `super_admin`. |
| `POST` | `/api/v1/profiles/invite` | Admin/super admin | Cria perfil adicional. |
| `POST` | `/api/v1/auth/login` | Público | Retorna JWT Bearer. |
| `POST` | `/api/v1/tenants` | Super admin | Cria tenant e configurações padrão. |
| `GET` | `/api/v1/channels` | Usuário do tenant | Lista os canais do tenant autenticado. |
| `POST` | `/api/v1/channels` | Admin do tenant | Cadastra/atualiza canal e cifra o token fornecido pelo cliente. |
| `POST` | `/api/v1/contacts` | Usuário do tenant | Cria contato. |
| `GET` | `/api/v1/conversations` | Usuário do tenant | Lista conversas do tenant. |
| `POST` | `/api/v1/conversations/{id}/messages` | Usuário do tenant | Persiste mensagem de saída. |
| `POST` | `/api/v1/conversations/{id}/handoff` | Usuário do tenant | Envia conversa à fila humana. |
| `GET`/`PATCH` | `/api/v1/settings` | Admin do tenant | Consulta/altera configurações de IA. |
| `GET`/`POST` | `/api/v1/webhooks/meta` | Meta | Verifica e recebe webhook assinado. |

Tokens de API e hashes de senha não são retornados por nenhuma rota.

## Testes

Execute toda a suíte:

```bash
cd /Users/joselucas/Desktop/Projetos/cyrus/crm/backend
uv run pytest
```

Execute um grupo específico:

```bash
uv run pytest tests/test_channels_endpoint.py
uv run pytest tests/test_tenants_endpoint.py
uv run pytest tests/test_rails_encryption.py
```

Os testes estão em `backend/tests/`:

- `test_channels_endpoint.py`: contrato, autenticação e isolamento de tenant para canais.
- `test_tenants_endpoint.py`: contrato e autorização do cadastro de tenants.
- `test_database.py`: driver assíncrono e sessão.
- `test_health.py`: health check e falha de conexão segura.
- `test_models.py`: tabelas, relações, constraints e enums PostgreSQL.
- `test_openapi.py`: rotas publicadas no contrato OpenAPI.
- `test_rails_encryption.py`: leitura/escrita compatível de tokens cifrados.

## Desenvolvimento

Toda mudança de comportamento segue TDD, conforme `AGENTS.md`:

1. Criar teste de contrato ou regressão que falhe.
2. Implementar a menor mudança necessária.
3. Rodar `cd backend && uv run pytest`.

Não expor tokens, hashes, valores cifrados ou segredos em respostas, erros ou logs. Para dados por tenant, a autorização deve sempre partir do `tenant_id` do perfil autenticado.

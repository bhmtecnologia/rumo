# Rumo

App de transporte sob demanda (estilo Uber). Versão web: solicitar corrida, ver preço estimado, sem login.

## Stack

- **Backend:** Node.js, Express, PostgreSQL (Supabase)
- **Frontend:** React, Vite
- **Banco:** Supabase (PostgreSQL) ou PostgreSQL local (Docker)

## Pré-requisitos

- Node.js 18+
- Conta no [Supabase](https://supabase.com) (ou Docker para Postgres local)

## Configuração

### 1. Variáveis de ambiente (backend)

Na pasta `backend`, crie um arquivo `.env` a partir do exemplo (nunca commite o `.env`). O backend usa `dotenv` e carrega o `.env` do diretório atual ao rodar os comandos.

```bash
cd backend
cp ../.env.example .env
```

Edite `.env` e defina a connection string do Supabase:

- No dashboard do Supabase: **Settings → Database → Connection string** (URI).
- Substitua `[YOUR-PASSWORD]` pela senha do banco. Se a senha tiver caracteres especiais (ex.: `$`), use aspas: `"sua$senha"`.

Exemplo (sem expor a senha no repositório):

```env
DATABASE_URL=postgresql://postgres:SUA_SENHA_AQUI@db.dgeqxfeucsyuxfhupujr.supabase.co:5432/postgres
```

### 2. Banco de dados

Rode a migração para criar as tabelas (`fare_config`, `rides`):

```bash
cd backend
npm install
npm run db:migrate
```

### 3. API

```bash
cd backend
npm run dev
```

API em: **http://localhost:3001**

### 4. Frontend

Em outro terminal:

```bash
cd frontend
npm install
npm run dev
```

App em: **http://localhost:5173** (proxy para `/api` na porta 3001).

## Testes

Sempre que alterar o backend, rode os testes.

### Testes unitários (não precisam de banco)

```bash
cd backend
npm run test:unit
```

Cobrem a lógica de tarifa e distância (`src/lib/fare.js`).

### Testes de integração (precisam de `DATABASE_URL`)

Com `.env` configurado (e migração já rodada):

```bash
cd backend
npm run test:integration
```

Cobrem as rotas da API (estimate, criar corrida, buscar, listar).

### Rodar todos os testes

```bash
cd backend
npm test
```

Os testes de integração são **pulados** se `DATABASE_URL` não estiver definido.

## Documentação

- **[docs/API.md](docs/API.md)** — Referência da API (endpoints, payloads, respostas).

## Uso do app

1. Abra http://localhost:5173
2. Informe **embarque** e **destino**
3. Clique em **Ver preço estimado**
4. Clique em **Solicitar Rumo**
5. Na confirmação, use **Nova corrida** para voltar

## Estrutura do projeto

```
rumo/
├── backend/           # API Node (Express)
│   ├── src/
│   │   ├── app.js     # App Express (exportado para testes)
│   │   ├── index.js   # Servidor
│   │   ├── db/        # Pool e migração
│   │   ├── lib/       # Lógica de tarifa
│   │   └── routes/    # Rotas e testes
│   └── package.json
├── frontend/          # React (Vite)
├── docs/
│   └── API.md
├── .env.example       # Exemplo de variáveis (sem senha)
├── .gitignore
└── README.md
```

## Tarifa

A tabela `fare_config` no banco define: tarifa base, valor por km, valor por minuto e valor mínimo. A migração insere valores padrão; você pode alterar direto no Supabase (SQL Editor ou tabela).

## Boas práticas adotadas

- **Senhas:** apenas em variáveis de ambiente (`.env`), nunca no código; `.env` no `.gitignore`.
- **Testes:** unitários para lógica de negócio; integração para API (com banco quando `DATABASE_URL` está definido).
- **Documentação:** README com setup e testes; `docs/API.md` com contrato da API.
- **Conexão com o banco:** suporte a `DATABASE_URL` (Supabase) ou variáveis `PG*` (Postgres local).

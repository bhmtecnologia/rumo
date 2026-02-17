# Deploy no Render

## URLs de produção

| Serviço | URL | Status |
|--------|-----|--------|
| **Frontend (Flutter web)** | **https://rumo-ddno.onrender.com** | ✅ Publicado (static site) |
| **Backend (API Node)** | **https://rumo-f09a.onrender.com** | ✅ Web Service no Render |

---

## Organização dos serviços no Render

Hoje só a **pasta web** (build do Flutter) está no Render, como **Static Site**. Para o app funcionar na internet de ponta a ponta:

1. **Manter o Static Site**  
   - Repositório/pasta que gera o build web (ex.: `rumo_app` com `flutter build web` ou a pasta que o Render usa).  
   - URL atual: **https://rumo-ddno.onrender.com**

2. **Criar um Web Service para a API**  
   - No Render: **New → Web Service**.  
   - Conectar o mesmo repositório (ou o que contém o backend).  
   - **Root Directory:** `backend` (ou o caminho onde está o Node/Express).  
   - **Build:** `npm install` (e `npm run db:migrate` se fizer sentido no deploy).  
   - **Start:** `npm start` ou `node src/index.js` (conforme seu `package.json`).  
   - **Environment:** definir variáveis (ex.: `DATABASE_URL`, `JWT_SECRET`, `APP_URL=https://rumo-ddno.onrender.com`).  

   O Render vai atribuir uma URL ao Web Service, por exemplo:  
   `https://rumo-api-xxxx.onrender.com`

3. **Apontar o frontend para a API**  
   - Rebuild do Flutter web com a URL do backend:
     ```bash
     cd rumo_app
     flutter build web --dart-define=API_BASE_URL=https://rumo-api-xxxx.onrender.com/api
     ```
   - Deploy de novo do static site (push ou re-deploy no Render).

4. **CORS**  
   - No backend, garantir que `Access-Control-Allow-Origin` permita `https://rumo-ddno.onrender.com` (além de localhost em dev).

---

## Resumo

- **Static Site (frontend):** já está no ar em **https://rumo-ddno.onrender.com**.
- **Web Service (backend):** ainda precisa ser criado no Render; depois, configurar env vars, CORS e rebuild do front com a URL da API.

A aplicação Flutter web usa a URL da API em **`rumo_app/lib/core/config.dart`**: em build de **release** (`flutter build web`) já aponta para `https://rumo-f09a.onrender.com/api`. Em desenvolvimento (`flutter run`) continua usando `http://localhost:3001/api`.

---

## Login no Render: usar Supabase via API (recomendado)

Para evitar **ENETUNREACH** (Render não consegue abrir conexão TCP com o Postgres do Supabase), o backend pode usar o **cliente Supabase JS** (`@supabase/supabase-js`): ele fala com o Supabase por **HTTPS**, sem conexão direta ao banco.

**No Render (Web Service rumo-f09a) → Environment:**

1. **SUPABASE_URL** — no Supabase: **Project Settings** → **API** → **Project URL** (ex.: `https://xxxx.supabase.co`).
2. **SUPABASE_SERVICE_ROLE_KEY** — na mesma página, em **Project API keys**, copie a **service_role** (secret; não use a anon key).

Com essas duas variáveis definidas, as rotas de **auth** (login, /me, alterar senha, recuperar senha, registro) e o **log de auditoria** passam a usar a API do Supabase. O login deixa de depender de conexão TCP e funciona no Render.

**Observação:** as demais rotas (corridas, units, centros de custo, usuários, relatórios etc.) ainda usam `pg` (DATABASE_URL). Para o app inteiro funcionar no Render sem TCP, seria preciso migrar essas rotas para o cliente Supabase também. Por enquanto, apenas auth + audit usam Supabase quando `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` estão definidos.

---

## Erro de login no Render: ENETUNREACH / conexão com o banco (alternativa: pooler)

Se o login falha no Render com algo como:

```text
Login error: Error: connect ENETUNREACH ... 5432
```

é porque a **conexão direta** do Supabase (porta **5432**) usa **IPv6**, e o ambiente do Render não consegue alcançar (ENETUNREACH).

**Solução:** usar o **Connection pooler** do Supabase em modo **Transaction** (porta **6543**), que funciona em IPv4.

1. No **Supabase**: Dashboard do projeto → **Project Settings** → **Database** → em **Connection string** escolha **Transaction** (ou “Use connection pooling”) e copie a URL. Ela deve terminar em **`:6543/postgres`** (e não `:5432/postgres`).
2. No **Render**: no seu Web Service (rumo-f09a) → **Environment** → defina **`DATABASE_URL`** com a URL do pooler.

   **Opção mais simples:** se hoje sua `DATABASE_URL` no Render é algo como  
   `postgresql://postgres:XXX@db.xxxxx.supabase.co:5432/postgres`,  
   altere só a porta **5432** para **6543**:  
   `postgresql://postgres:XXX@db.xxxxx.supabase.co:6543/postgres`  
   (mesmo host, mesma senha, só trocar `5432` → `6543`).

   **Ou** use a URL de “Transaction pooler” que o Supabase mostra em **Connect** → **Transaction** (pode usar host tipo `aws-0-XX.pooler.supabase.com:6543`).

3. Salve as variáveis e faça **Redeploy** do serviço no Render.

Depois disso, a API no Render passa a conectar no banco via pooler e o login deve funcionar.

---

## Ainda ENETUNREACH? Use o host do pooler (Session mode)

Se mesmo com porta **6543** e preferência IPv4 no código o erro continuar, o host **`db.xxx.supabase.co`** pode estar resolvendo só para IPv6 na rede do Render. Nesse caso use a URL que usa o **host do pooler**, não o host direto do banco.

1. No **Supabase**: Dashboard do projeto → **Project Settings** → **Database**.
2. Em **Connection string**, abra o seletor (ex.: "URI", "Direct", "Session", "Transaction").
3. Escolha **"Session"** (Session mode). A URL deve ter:
   - **Host:** `aws-0-XX.pooler.supabase.com` (ou similar, com **pooler.supabase.com**),
   - **Porta:** 5432,
   - **Usuário:** pode aparecer como `postgres.PROJECT_REF` (ex.: `postgres.dgeqxfeucsyuxfhupujr`).
4. Copie a URL **inteira** (com sua senha no lugar de `[YOUR-PASSWORD]`).
5. No **Render** → Web Service rumo-f09a → **Environment** → defina **`DATABASE_URL`** com essa URL de **Session** (host pooler).
6. **Save** e **Redeploy**.

O host **pooler.supabase.com** costuma ser acessível por IPv4 a partir do Render. O backend continua usando o driver `pg` (conexão TCP com Postgres); só muda o host/porta da string de conexão.

**Sobre PostgREST / “Enable Data API”:** isso ativa a API REST do Supabase (para o cliente Supabase no browser/app). O backend Rumo **não** usa PostgREST: ele usa conexão **direta** ao Postgres com o driver `pg`. Por isso o ENETUNREACH vem da conexão TCP ao banco (host/porta da `DATABASE_URL`), não das opções de Data API no dashboard.

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

## Erro de login no Render: ENETUNREACH / conexão com o banco

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

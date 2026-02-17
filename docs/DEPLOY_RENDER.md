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

# Plano de implementação por fases – Rumo

Com base no **Anexo C (Especificações Técnicas)** e **Anexo D (Relatórios)**, este documento organiza a implementação em fases, alinhadas ao que já existe no projeto.

---

## Estado atual (baseline)

| Área | O que existe |
|------|----------------------|
| **Backend** | Node/Express, Postgres (Supabase). Tabelas: `rides`, `fare_config`. Endpoints: `POST /api/rides/estimate`, `POST /api/rides`, `GET /api/rides`, `GET /api/rides/:id`. |
| **Flutter** | App com 3 módulos: **Passageiro** (home, escolher viagem, solicitar corrida), **Motorista** (placeholder), **Backoffice** (mapa + lista de corridas). |
| **Não existe** | Autenticação, units/centros de custo, perfis de acesso, fluxo completo da corrida (aceite, chegada, início, fim), restrições, relatórios, API de integração. |

---

## Fase 1 – Autenticação e perfis de acesso

**Objetivo:** Login/senha, perfis (Gestor Central, Gestor Unidade, Usuário) e base para vincular usuários a centros de custo.

| Item | Especificação | Implementação |
|------|----------------|----------------|
| Login/senha | Acesso por login e senha pessoal (web e mobile) | Auth (ex.: Supabase Auth ou JWT próprio). |
| Perfis | Gestor Central, Gestor Unidade, Usuário | Tabela/campo de perfil; regras de acesso por rota/tela. |
| Gestor Central | Acesso pleno a todos os centros de custo | Backend e front filtram por perfil. |
| Gestor Unidade | Limitado ao(s) centro(s) de custo vinculado(s); pode ter mais de um | Tabela usuário ↔ centro de custo (N:N para gestor). |
| Usuário | Só solicitação/finalização de corridas e dados da própria senha | Restringir telas e APIs ao perfil “usuário”. |
| Alteração de senha | Possibilidade de alteração a qualquer momento | Fluxo “alterar senha” (tela + API). |
| Recuperação de senha | Recuperação com envio de informações ao e-mail | Fluxo “esqueci minha senha” + e-mail (template). |

**Entregáveis:**  
- Cadastro de usuário (nome, e-mail, senha, perfil, vínculo a centro de custo quando aplicável).  
- Login (web e app).  
- Alteração e recuperação de senha.  
- Middleware/guard que bloqueia acesso conforme perfil.

**Ordem sugerida:**  
1) Modelo de usuário e perfis no banco; 2) API de auth (login, refresh, alterar/recuperar senha); 3) Tela de login no app e na web; 4) Guards/middleware por perfil.

---

## Fase 2 – Cadastros base (aplicação web)

**Objetivo:** Estrutura organizacional e cadastros necessários para restrições e relatórios.

| Item | Especificação | Implementação |
|------|----------------|----------------|
| Units (unidades) | Cadastramento de unidades (órgãos/entidades) | Tabela `units`; CRUD na web. |
| Centros de custo | Unidades administrativas vinculadas a uma unit | Tabela `cost_centers` com FK para `units`; CRUD na web. |
| Usuários e perfis | Cadastro com perfis diferenciados | Ampliar: perfil, vínculo(s) a centro(s) de custo (N:N); telas de cadastro/edição. |
| Motivos de solicitação | Cadastramento de motivos | Tabela `request_reasons`; CRUD na web. |

**Entregáveis:**  
- Telas web: Units, Centros de custo, Usuários, Motivos de solicitação.  
- APIs correspondentes (CRUD) com checagem de perfil (Gestor Central vs Gestor Unidade).

**Ordem sugerida:**  
1) Migrações: units, cost_centers, request_reasons, user_cost_centers; 2) APIs; 3) Telas no backoffice/web.

---

## Fase 3 – Limites de despesa e restrições

**Objetivo:** Limites e regras que podem bloquear ou restringir solicitações.

| Item | Especificação | Implementação |
|------|----------------|----------------|
| Limite de despesa | Por perfil de cliente | Tabela/config de limite por perfil e/ou por centro de custo; checagem na solicitação. |
| Restrição origem/destino | Bloquear se origem/destino não parametrizados | Cadastro de endereços/polígonos permitidos por centro de custo; validação no request. |
| Limite de despesas (mês) | Bloquear se valor do mês > parametrizado | Soma de corridas do usuário/centro no mês; comparar com teto. |
| Horário da solicitação | Restrição por horário parametrizado | Cadastro de faixas de horário permitidas; validar no momento da solicitação. |
| Categoria | Restrição por categoria da credenciada | Tabela categorias; vínculo centro de custo ↔ categorias permitidas. |
| Quilometragem máxima | Restrição por km máx | Parâmetro por centro de custo; comparar com estimativa da corrida. |
| Bloqueio por centro de custo | Bloqueio do centro bloqueia todos os usuários | Flag “bloqueado” no centro de custo; mensagem clara na solicitação. |

**Entregáveis:**  
- Cadastros/parâmetros de limites e restrições (telas web).  
- Validações no backend ao criar/estimar corrida (e retorno de mensagem específica quando houver bloqueio).

**Ordem sugerida:**  
1) Modelo de dados (limites, restrições, bloqueio); 2) Regras no backend; 3) Telas de parametrização; 4) Mensagens no app quando restrição bloquear.

---

## Fase 4 – Fluxo completo da corrida (tempo real)

**Objetivo:** Ciclo de vida da corrida e acompanhamento em tempo real (web e mobile), conforme especificação.

### 4.1 Estados e eventos

| Estado | Descrição | Quem altera |
|--------|-----------|--------------|
| `requested` | Corrida solicitada | Sistema (criação). |
| `accepted` | Motorista aceitou | Motorista. |
| `driver_arrived` | Veículo chegou na origem | Motorista. |
| `in_progress` | Viagem iniciada | Motorista. |
| `completed` | Viagem finalizada | Motorista. |
| `cancelled` | Cancelada (usuário ou motorista) | Usuário ou motorista. |

Incluir timestamps: solicitação, aceite, chegada na origem, início da corrida, fim da corrida, cancelamento (e contestação se aplicável).

### 4.2 Acompanhamento da solicitação (tempo real)

- Informações na plataforma web e no app: data/hora da solicitação, tempo estimado para chegada do veículo, valor estimado, identificação do veículo (placa) e do motorista (nome).  
- Mensagem de chegada do veículo na origem (web + app).  
- Cancelamento pelo usuário, com possibilidade de taxa de cancelamento (regra de tempo/distância).  
- *Desejável:* trajeto geoprocessado até a origem; comunicação usuário–motorista.

### 4.3 Acompanhamento da viagem e finalização

- Início da viagem, tempo estimado para finalização, trajeto geoprocessado.  
- Finalização: endereços efetivos, tempo de deslocamento, data/hora início e fim, valor da viagem, km percorrida, avaliação do serviço.

### 4.4 Dados geoprocessados (mobile)

- Formato UTM WGS84 (lat/lng), amostragem mínima de um ponto a cada 10 s.  
- Armazenar trajeto (tabela de pontos ou JSON) para relatório e e-mail pós-corrida.

### 4.5 Alertas e pós-corrida

- Alertas (in-app; depois e-mail/SMS): aceite/cancelamento pelo motorista, chegada do veículo na origem.  
- E-mail pós-corrida: histórico e recibo (origem/destino efetivos, datas/horas, valor, motorista).

### 4.6 Avaliação

- Obrigatória no mobile; desejável na web. Persistir na corrida e nos relatórios.

**Entregáveis:**  
- Backend: novos estados, endpoints (aceitar, chegada, iniciar, finalizar, cancelar), armazenamento de trajeto (lat/lng a cada 10 s).  
- App motorista: aceitar/recusar, “cheguei”, “iniciar viagem”, “finalizar” (com valor/km).  
- App passageiro e web: acompanhamento em tempo real (polling ou WebSocket).  
- Cancelamento com regra de taxa.  
- Tela de avaliação (obrigatória no app).  
- E-mail pós-corrida (template + envio).  
- Alertas in-app (e depois e-mail/SMS se previsto).

**Ordem sugerida:**  
1) Migrações (campos de timestamp, motorista, veículo, trajeto, avaliação); 2) APIs de transição de estado; 3) App motorista (fluxo mínimo); 4) Acompanhamento em tempo real (polling ou WS); 5) Cancelamento e avaliação; 6) E-mail e alertas.

---

## Fase 5 – Backoffice e relatórios (Anexo D)

**Objetivo:** Gestão por perfil e relatórios com exportação.

| Item | Especificação | Implementação |
|------|----------------|----------------|
| Gestor Central | Acesso a todos os centros de custo e dados | Filtros e listagens sem restrição de centro. |
| Gestor Unidade | Apenas seu(s) centro(s) de custo | Filtro por centro de custo vinculado ao usuário. |
| Relatórios de corridas | Dados do Anexo D (identificador, orçamento, unit/centro de custo, usuário, endereços, motivo, datas, motorista, veículo, categoria, trajeto, distância, valores, ateste, avaliação, etc.) | Consulta + exportação XLS/CSV/XML. |
| Relatórios cadastrais | Units, centros de custo, perfis, status, dados dos cadastros | Telas de consulta + exportação. |
| Histórico em tempo real | Visualização do histórico de corridas em tempo real | Listagem/atualização contínua (polling ou WS). |

**Entregáveis:**  
- Telas de relatórios (corridas e cadastrais) com filtros por perfil.  
- Exportação XLS, CSV, XML.  
- Garantir retenção e disponibilização dos dados por pelo menos 90 dias (política + onde aplicável, filtros por data).

**Ordem sugerida:**  
1) Endpoints de relatório (corridas e cadastrais) com filtros; 2) Exportação (biblioteca XLS/CSV/XML no backend ou geração no front); 3) Telas no backoffice; 4) Política de retenção (docs + implementação se necessário).

---

## Fase 6 – API de integração (Anexo C 4.1)

**Objetivo:** API para integração com a solução da CREDENCIANTE/CONTRATANTE.

| Endpoint / recurso | Especificação | Implementação |
|-------------------|----------------|----------------|
| Orçamento / pesquisa de preços | Pesquisa de preços (e solicitação/cancelamento) para todas as categorias | Documentar e estabilizar `POST /api/rides/estimate` (e criar se necessário endpoint de “pesquisa multi-empresa”). |
| Solicitação e cancelamento | Solicitação e cancelamento de corridas | Já existe criação; adicionar cancelamento; documentar. |
| Usuários | Consulta, criação, exclusão e edição | CRUD de usuários via API (com autenticação e perfil). |
| Recibo | Consulta de recibo de corrida | GET recibo por id da corrida (dados da finalização + valor). |
| Avaliação | Envio de avaliação | POST avaliação associada à corrida. |
| Centro de custo | Consulta, criação, exclusão e edição | CRUD de centros de custo via API. |
| Comunicação usuário–motorista | Canal de comunicação | Endpoint ou canal (chat/notas) entre usuário e motorista da corrida. |
| Relatórios | Dados mínimos do Anexo D | Endpoints de relatório (corridas e cadastrais) já previstos na Fase 5; expor de forma estável e documentada. |
| *Desejável* | Status da corrida e posição do motorista via webhooks | Webhooks para eventos (aceite, chegada, início, fim). |
| *Desejável* | API com polyline nos mapas | Endpoint ou campo com polyline do trajeto. |

**Entregáveis:**  
- Documentação da API (OpenAPI/Swagger ou equivalente).  
- Respostas em JSON (e opcionalmente XML conforme anexo).  
- Implementação dos endpoints faltantes e padronização dos existentes.

**Ordem sugerida:**  
1) Listar endpoints existentes vs. especificação; 2) Implementar faltantes; 3) Documentar; 4) Webhooks e polyline se priorizados.

---

## Fase 7 – Disponibilidade, auditoria e polish

**Objetivo:** Alinhar a requisitos gerais e uso em produção.

| Item | Especificação | Implementação |
|------|----------------|----------------|
| Disponibilidade | 24h por dia, 7 dias por semana | Deploy em ambiente estável; monitoramento e alertas (fora do escopo mínimo do código). |
| Auditoria e log | Garantia de disponibilidade e integridade; consulta a réplica/log de eventos | Log de eventos críticos (auth, alteração de corrida, alterações cadastrais); onde possível, uso de réplica para consulta. |
| Base de endereços | Base de endereços atualizada | Manter uso de geocoding (ex.: Nominatim/outro) e políticas de atualização/cache. |
| Manual de uso | Manual para web e app (solicitações, acompanhamento, relatórios) | Documento (ou ajuda in-app) atualizado conforme as fases. |
| Compatibilidade | Web: Safari, Chrome, Edge, Firefox; Mobile: Android e iOS | Testes e ajustes de layout/compatibilidade nas fases anteriores. |

**Entregáveis:**  
- Log de eventos críticos (estrutura e exemplos).  
- Nota ou doc sobre base de endereços e manual de uso.  
- Checklist de compatibilidade (navegadores e SOs).

---

## Resumo da ordem das fases

| Fase | Nome | Dependências |
|------|------|--------------|
| **1** | Autenticação e perfis | — |
| **2** | Cadastros base (web) | Fase 1 |
| **3** | Limites e restrições | Fase 2 |
| **4** | Fluxo completo da corrida | Fase 1 (usuário/motorista autenticados) |
| **5** | Backoffice e relatórios | Fases 1, 2, 4 |
| **6** | API de integração | Fases 1–5 (expõe o que já existe + endpoints faltantes) |
| **7** | Disponibilidade, auditoria e polish | Todas |

---

## Fase 1 – Concluída (base local)

Implementado:

- **Backend:** Tabela `users` (email, password_hash, name, profile, reset_token); coluna `requested_by_user_id` em `rides`. Rotas: `POST /api/auth/login`, `GET /api/auth/me`, `POST /api/auth/change-password`, `POST /api/auth/forgot-password`, `POST /api/auth/reset-password`, `POST /api/auth/register`. Middleware `requireAuth` (JWT). Todas as rotas `/api/rides` exigem login. Listagem de corridas: Gestor Central vê todas; demais perfis só as próprias.
- **Flutter:** `AuthService` (login, logout, token, alterar/recuperar/redefinir senha), modelo `AppUser`, telas Login, Esqueci senha, Redefinir senha (com token), Alterar senha. App inicia em Login ou no seletor de módulo conforme token válido. 401 dispara logout e volta ao login.
- **Uso:** Após `npm run db:migrate` e `npm run db:seed`, usar `admin@rumo.local` / `rumo123` para login. Alterar senha após o primeiro acesso. Estrutura preparada para trocar por Firebase/Google/Microsoft depois.

---

## Fase 2 – Concluída (units em vez de órgãos)

Implementado:

- **Documentação:** Plano atualizado para usar **units** (unidades) em vez de órgãos/entidades.
- **Backend:** Tabelas `units`, `cost_centers` (unit_id), `user_cost_centers` (N:N), `request_reasons`. Rotas: `GET/POST/PATCH/DELETE /api/units`, `GET/POST/PATCH/DELETE /api/cost-centers`, `GET/POST/PATCH/DELETE /api/request-reasons`, `GET/POST/PATCH /api/users` (e `GET /api/users/:id`). Gestor Central: acesso total. Gestor Unidade: vê apenas units/centros de custo/usuários vinculados aos seus centros de custo.
- **Flutter backoffice:** Drawer no Central com: Central, Units, Centros de custo, Motivos de solicitação, Usuários. Telas de listagem e CRUD (formulários em dialog) para cada cadastro. FAB e editar/excluir apenas para Gestor Central (exceto usuários: Gestor Central edita todos).

---

## Próximo passo sugerido

Iniciar pela **Fase 3 – Limites e restrições** ou **Fase 4 – Fluxo completo da corrida**, conforme prioridade.

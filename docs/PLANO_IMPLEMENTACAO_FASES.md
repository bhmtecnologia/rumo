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

## Fase 3 – Concluída (limites e restrições)

Implementado:

- **Backend:** Em `cost_centers`: campos `blocked`, `monthly_limit_cents`, `max_km`, `allowed_time_start`, `allowed_time_end`. Tabela `cost_center_allowed_areas` (cost_center_id, type origin|destination, lat, lng, radius_km, label). Em `rides`: coluna `cost_center_id`. Lib `restrictions.js`: `checkRestrictions(costCenterId, userId, options)` valida bloqueio, janela de horário, max_km, limite mensal (soma do mês) e áreas permitidas (haversine). Em `POST /api/rides/estimate` e `POST /api/rides`: resolução do centro de custo (body opcional `cost_center_id`; se usuário tem um só, usa; se vários, exige envio); validação via `checkRestrictions`; 403 com mensagem quando restrição falha. Login e `GET /api/auth/me` retornam `costCenterIds` do usuário. Rotas `GET /api/cost-centers/:id` (com `allowedAreas`), `PATCH /api/cost-centers/:id` (restrições), `POST /api/cost-centers/:id/areas`, `DELETE /api/cost-centers/:id/areas/:areaId`.
- **Flutter backoffice:** Tela **Restrições** por centro de custo (menu no item da lista): bloqueado, limite mensal (R$), distância máx (km), horário início/fim (HH:mm), áreas permitidas (origem/destino) com adicionar/remover. Apenas Gestor Central pode editar; Gestor Unidade pode visualizar.
- **Flutter passageiro:** Envio de `cost_center_id` em estimativa e criação de corrida: um centro → uso automático; vários → seletor na tela “Planeje sua viagem”. Erro 403 exibe a mensagem retornada pela API (restrições do centro de custo).
- **ApiService:** `getCostCenter(id)`, `updateCostCenter(id, ...)` com parâmetros opcionais de restrição, `addCostCenterArea`, `deleteCostCenterArea`; `getEstimate` e `createRide` aceitam `costCenterId` opcional e tratam 403.

---

## Fase 4 – Concluída (fluxo completo da corrida)

Implementado:

- **Backend:** Perfil `motorista` em `users`. Em `rides`: status `driver_arrived`; colunas `driver_user_id`, `driver_name`, `vehicle_plate`, `accepted_at`, `driver_arrived_at`, `started_at`, `completed_at`, `cancelled_at`, `actual_price_cents`, `actual_distance_km`, `actual_duration_min`, `trajectory` (JSONB), `rating`, `cancel_reason`, `cancelled_by_user_id`. Endpoints: `PATCH /api/rides/:id/accept` (motorista, body opcional `vehiclePlate`), `PATCH /api/rides/:id/arrived`, `PATCH /api/rides/:id/start`, `PATCH /api/rides/:id/complete` (body `actualPriceCents`, opcional `actualDistanceKm`, `actualDurationMin`), `PATCH /api/rides/:id/cancel` (solicitante ou motorista, body opcional `reason`), `POST /api/rides/:id/rate` (body `rating` 1–5, apenas solicitante). `GET /api/rides` para motorista: `?available=1` lista corridas com status `requested`; sem parâmetro lista corridas do motorista (`driver_user_id = eu`). `GET /api/rides/:id` retorna detalhe completo (acesso: solicitante, motorista da corrida ou gestor central).
- **Flutter:** Modelo `Ride` ampliado (driver, timestamps, valores efetivos, rating). `RideListItem` com `driverName`, `vehiclePlate`. ApiService: `getRide(id)`, `listRides(available: true|false)`, `acceptRide`, `markRideArrived`, `startRide`, `completeRide`, `cancelRide`, `rateRide`.
- **App motorista:** Lista de corridas disponíveis (status requested) e card “Sua corrida” quando há corrida aceita/em andamento. Aceitar com placa opcional; tela **Corrida ativa** com botões “Cheguei na origem”, “Iniciar viagem”, “Finalizar corrida” (formulário valor/km/duração) e “Cancelar corrida”.
- **App passageiro:** Tela “Solicitação enviada” com **polling** a cada 3 s; mensagens por status (motorista a caminho, chegou, viagem em andamento); botão **Cancelar corrida**; ao concluir, navega para **Avaliar corrida** (1–5 estrelas) e em seguida volta ao início.
- **Uso:** Criar usuário com perfil **motorista** pelo backoffice (Usuários). Login como motorista → módulo Motorista → ver corridas disponíveis e aceitar. Login como usuário/passageiro → solicitar corrida → acompanhar e, ao final, avaliar.

---

## Fase 5 – Concluída (backoffice e relatórios)

Implementado:

- **Backend:** Rotas `GET /api/reports/rides` (query: `from`, `to`, `costCenterId`, `unitId`) e `GET /api/reports/cadastrais` (query: `type` = units | cost_centers | users | request_reasons). Respeito ao perfil: Gestor Central vê todos os dados; Gestor Unidade apenas corridas e cadastros dos centros de custo a que está vinculado. Retorno em JSON para consumo pelo backoffice e exportação no cliente.
- **Flutter backoffice:** Item **Relatórios** no menu do backoffice. Tela com duas seções: (1) **Relatório de corridas** – filtros por data início/fim, unidade e centro de custo; botões Exportar CSV, Exportar XML e Exportar XLS (geração no cliente; download na web); (2) **Relatório cadastral** – tipo (Units, Centros de custo, Usuários, Motivos de solicitação); Exportar CSV, XML e XLS. Dependências: `excel` (XLS), `intl` (formato de data). Download de arquivo na web via `dart:html` (helper com stub para não-web).
- **Histórico em tempo real:** A Central do backoffice já atualiza a lista de corridas a cada 15 segundos (polling); os relatórios permitem consultar e exportar o histórico conforme filtros.
- **Política de retenção:** Documento `docs/POLITICA_RETENCAO_DADOS.md` descreve a retenção mínima de 90 dias (Anexo D 4) e a responsabilidade operacional de não apagar dados dentro dessa janela.

---

## Fase 6 – Concluída (API de integração)

Implementado:

- **Recibo:** `GET /api/rides/:id/receipt` — retorna recibo da corrida (apenas status `completed`): endereços, motorista, veículo, datas de início/fim, valor final, distância, duração, avaliação. Acesso: solicitante, motorista ou gestor central.
- **Comunicação usuário–motorista:** Tabela `ride_messages` (ride_id, user_id, text, created_at). `GET /api/rides/:id/messages` — lista mensagens da corrida; `POST /api/rides/:id/messages` (body: `text`) — envia mensagem (solicitante ou motorista).
- **Documentação:** `docs/api-openapi.yaml` — OpenAPI 3.0 com todos os endpoints: auth (login, me, change-password, forgot-password, reset-password, register), rides (estimate, criação, listagem, detalhe, accept/arrived/start/complete/cancel, rate, receipt, messages), units, cost-centers (e áreas), request-reasons, users, reports (rides e cadastrais). Autenticação Bearer JWT; respostas em JSON.
- **Flutter:** ApiService com `getRideReceipt(id)`, `getRideMessages(id)` e `sendRideMessage(id, text)` para uso futuro (telas de recibo e chat podem ser implementadas quando desejado).

Orçamento (estimate), solicitação e cancelamento, usuários, centros de custo, avaliação (rate) e relatórios já estavam implementados nas fases anteriores; a Fase 6 adiciona recibo, mensagens e documentação formal da API.

---

## Fase 7 – Concluída (disponibilidade, auditoria e polish)

Implementado:

- **Auditoria e log:** Tabela `audit_log` (event_type, user_id, resource_type, resource_id, details JSONB, created_at). Lib `audit.js` com `logAudit(...)`. Eventos registrados: auth (login, password_changed, password_reset, register), rides (accepted, driver_arrived, started, completed, cancelled), units (created, updated, deleted), cost_centers (created, updated, deleted), request_reasons (created, updated, deleted), users (created, updated). Migração aplicada via `npm run db:migrate`.
- **Documentação:** `docs/BASE_ENDERECOS.md` — uso de geocoding (Nominatim no app), políticas de cache e atualização da base de endereços; `docs/MANUAL_USO.md` — manual para web e app (solicitações, acompanhamento, relatórios, perfis); `docs/CHECKLIST_COMPATIBILIDADE.md` — checklist para navegadores (Safari, Chrome, Edge, Firefox) e mobile (Android, iOS).
- **Disponibilidade 24/7:** mantida como fora do escopo mínimo (deploy e monitoramento contínuo ficam a cargo da operação).

---

## Próximo passo sugerido

Todas as fases do plano foram implementadas. Próximos passos possíveis: deploy em ambiente de produção, monitoramento de disponibilidade, testes de compatibilidade usando o checklist e ajustes de polish conforme feedback dos usuários.

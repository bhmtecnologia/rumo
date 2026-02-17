# Checklist de compatibilidade – Rumo

Conforme Anexo C, a solução deve ser compatível com os seguintes ambientes:

- **Aplicação web:** navegadores que suportam HTML5, especialmente **Apple Safari**, **Google Chrome**, **Microsoft Edge** e **Mozilla Firefox**.
- **Aplicativo mobile:** sistemas operacionais **Android** e **iOS**.

Este documento serve como checklist para validação e registro de testes de compatibilidade.

---

## 1. Aplicação web

| Navegador | Versão mínima sugerida | Status | Observações |
|-----------|------------------------|--------|-------------|
| **Apple Safari** | Últimas 2 versões principais | ☐ OK / ☐ Falha | Testar em macOS e iOS (WebKit). |
| **Google Chrome** | Últimas 2 versões principais | ☐ OK / ☐ Falha | Desktop e Android. |
| **Microsoft Edge** | Últimas 2 versões principais (Chromium) | ☐ OK / ☐ Falha | Windows e macOS. |
| **Mozilla Firefox** | Últimas 2 versões principais | ☐ OK / ☐ Falha | Desktop e Android. |

### 1.1 Funcionalidades a validar na web

- [ ] Login e logout
- [ ] Alterar senha e recuperar senha (e-mail)
- [ ] Central: listagem e atualização de corridas
- [ ] Cadastros: Units, Centros de custo, Motivos de solicitação, Usuários (listagem, criação, edição, exclusão conforme perfil)
- [ ] Restrições por centro de custo (bloqueio, limite mensal, km, horário, áreas)
- [ ] Relatórios: filtros e exportação (CSV, XML, XLS)
- [ ] Recibo da corrida e mensagens (quando disponíveis na UI)
- [ ] Responsividade básica (telas menores / tablet)

---

## 2. Aplicativo mobile

| Plataforma | Versão mínima sugerida | Status | Observações |
|------------|------------------------|--------|-------------|
| **Android** | API 21+ (Lollipop) ou conforme definido no projeto | ☐ OK / ☐ Falha | Testar em dispositivo ou emulador. |
| **iOS** | Últimas 2 versões principais (ex.: iOS 14+) | ☐ OK / ☐ Falha | Testar em dispositivo ou simulador. |

### 2.1 Funcionalidades a validar no app

**Módulo Passageiro:**

- [ ] Login e logout
- [ ] Solicitar corrida (origem, destino, centro de custo, estimativa)
- [ ] Acompanhamento em tempo real (status, motorista, placa)
- [ ] Cancelar corrida
- [ ] Avaliar corrida ao final
- [ ] Alterar senha (se disponível no app)

**Módulo Motorista:**

- [ ] Login e logout
- [ ] Listar corridas disponíveis
- [ ] Aceitar corrida (com placa opcional)
- [ ] Cheguei na origem / Iniciar viagem / Finalizar corrida
- [ ] Cancelar corrida
- [ ] Mensagens (se disponível na UI)

**Módulo Backoffice (web ou app):**

- [ ] Acesso ao backoffice a partir do app (se existir) com as mesmas regras de perfil

---

## 3. Requisitos técnicos comuns

- **HTML5:** a aplicação web utiliza HTML5; navegadores devem suportar recursos usados (ex.: formulários, fetch/APIs, armazenamento local se aplicável).
- **Rede:** conexão à internet estável para login, APIs e atualização em tempo real (polling ou equivalente).
- **HTTPS:** em produção, acesso via HTTPS para segurança de credenciais e dados.

---

## 4. Registro de testes

- **Data do teste:** _______________
- **Versão da aplicação web:** _______________
- **Versão do app (build):** _______________
- **Testador:** _______________

Preencher status (OK/Falha) e observações para cada item conforme os testes forem realizados. Em caso de falha, registrar o navegador/versão/OS e a descrição do problema para correção.

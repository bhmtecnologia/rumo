# Política de retenção e disponibilização de dados (Anexo D 4)

As informações das solicitações, corridas e dados cadastrais devem ser mantidas e disponibilizadas por **pelo menos 90 (noventa) dias** após o encerramento da vigência contratual.

## Implementação

- **Backend:** Os relatórios (`GET /api/reports/rides` e `GET /api/reports/cadastrais`) não excluem dados por idade. Os filtros de data (parâmetros `from` e `to` em `/reports/rides`) permitem consultar corridas no intervalo desejado; recomenda-se que a base de dados conserve registros de corridas e cadastros pelo menos 90 dias.
- **Operação:** Cabe à operação/contratante definir processo de backup e retenção (ex.: não apagar dados de corridas com `created_at` ou `completed_at` dentro da janela de 90 dias). Não há purge automático no código; a política deve ser aplicada por procedimento operacional ou job de limpeza configurado fora do escopo mínimo do app.

## Durante a vigência

Os dados devem estar disponíveis a qualquer tempo, com periodicidade mínima de atualização diária quando houver integração (API, base de dados ou transferência de arquivos para a CREDENCIANTE/CONTRATANTE).

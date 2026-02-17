# ANEXO C - ESPECIFICAÇÕES TÉCNICAS

## 1. REQUISITOS DA SOLUÇÃO TECNOLÓGICA

### 1.1. Requisitos gerais

A solução tecnológica a ser disponibilizada pela CREDENCIADA/CONTRATADA, consideradas as condições constantes neste documento e contemplando as funcionalidades de operação e gestão do serviço especificadas, deverá atender aos seguintes requisitos:

1. **Disponibilidade ininterrupta** durante 24h (vinte e quatro horas) por dia, inclusive aos sábados, domingos e feriados;
2. **Acesso às funcionalidades** pelos usuários por meio de plataforma web e aplicativo mobile, com utilização de login e senha pessoal, observando perfis de acesso estabelecidos;
3. **Possibilidade de agendar** data e horário para atendimento;
4. **Funcionalidades de gestão** acessadas pela aplicação web e funcionalidades operacionais pela plataforma web e aplicativo mobile;
5. **Características de auditoria** para fins de garantia da disponibilidade e integridade das informações;
6. **Acesso de consulta**, a qualquer tempo, à réplica do banco de dados para análise do log de eventos;
7. **Compatibilidade**:
   - Aplicação web: navegadores que suportam HTML5, especialmente **Apple Safari**, **Google Chrome**, **Microsoft Edge** e **Mozilla Firefox**;
   - Aplicativo mobile: sistemas operacionais **Android** e **iOS**.
8. **Cadastramento e gerenciamento de perfis de acesso**, com previsão de, no mínimo, as seguintes funcionalidades:
   - **Gestor Central**: responsável pelo monitoramento e acompanhamento dos serviços em geral, com acesso a todas as funcionalidades do sistema;
   - **Gestor Unidade (centro de custo)**: responsável pelo monitoramento e pelo acompanhamento dos serviços no âmbito do centro de custo a ele vinculada a responsabilidade, sendo responsável pelo cadastramento de usuários e geração de relatórios em seu âmbito de atuação;
     - Um mesmo Gestor Unidade pode ser responsável por mais de 1 (um) centro de custo.
   - **Usuário**: responsável pelo registro da solicitação dos serviços, de acordo com a política estabelecida pelo Gestor de Unidade.
   - **Regras de acesso por perfil**:
     - O Gestor Central deve ter acesso pleno aos dados e informações de todos os centros de custo;
     - Os Gestores de Unidade devem estar limitados ao(s) centro(s) de custo a que estão vinculados;
     - Os demais usuários somente às funcionalidades diretamente relacionadas à **SOLICITAÇÃO** e finalização de **CORRIDAS** e àquelas que se vinculam às senhas pessoais.
   - De acordo com o direcionamento da fiscalização, a CREDENCIADA/CONTRATADA também será responsável pelo cadastramento dos usuários, com as informações disponibilizadas pela CREDENCIANTE/CONTRATANTE.
9. **Manual de uso**: a CREDENCIADA/CONTRATADA deve disponibilizar para a CREDENCIANTE/CONTRATANTE, sempre que solicitado, Manual de Uso da Tecnologia (plataforma web e aplicativo mobile), contendo as instruções necessárias para o registro e acompanhamento das solicitações e emissão de relatórios das corridas.
10. **Base de endereços**: a solução deverá ter base de endereços atualizada cadastrada.

---

## 2. FUNCIONALIDADES DA APLICAÇÃO WEB

### 2.1. Condições básicas

A aplicação web da solução tecnológica da CREDENCIADA/CONTRATADA deve contemplar as funcionalidades necessárias para a operação e a gestão do serviço, considerando as seguintes condições básicas:

#### 2.1.1. Cadastro

1. Cadastramento de órgãos e entidades;
2. Cadastramento de unidades administrativas de órgãos e entidades (centro de custos);
3. Cadastramento de usuários e perfis de acesso diferenciados;
4. Cadastramento de motivos de solicitação.

#### 2.1.2. Limite de despesa e restrições

1. Cadastramento dos limites de despesas para custeio do serviço, por perfil de cliente.
2. Possibilidade de restrições por centro de custo, conforme definido abaixo:
   1. **Origem e/ou destino**: possibilidade de restrição da solicitação, caso o local de origem e/ou destino não sejam aqueles parametrizados para o usuário;
   2. **Limite de despesas**: possibilidade de restrição da solicitação, caso o valor total das corridas daquele usuário, ou para o centro de custo, para o mês corrente, esteja acima do valor parametrizado no sistema;
   3. **Horário da solicitação**: possibilidade de restrição da solicitação, caso o horário da solicitação de corridas daquele usuário, para o mês corrente, esteja fora daqueles parametrizados no sistema;
   4. **Categoria**: possibilidade de restrição de corridas por categoria da CREDENCIADA/CONTRATADA;
   5. **Quilometragem máxima**: possibilidade de restrição de corridas mais longas do que determinada quilometragem parametrizada no sistema;
   6. **Bloqueio por Centro de Custo**: no caso de bloqueio de utilização de serviço para um Centro de Custo, todos os usuários a ele vinculados deverão ser bloqueados automaticamente, exibindo-se mensagem específica quando de eventual solicitação.

#### 2.1.3. Senha

1. Cadastramento de senha de acesso à solução tecnológica, com possibilidade de alteração e recuperação a qualquer momento pelo usuário, com encaminhamento de informações desta operação para o seu e-mail.

#### 2.1.4. SOLICITAÇÃO

##### 2.1.4.1. Acompanhamento da solicitação (tempo real)

Acompanhamento da solicitação pelo usuário, em tempo real, com no mínimo:

1. Encaminhamento de informações da solicitação e mensagem na plataforma web e aplicativo mobile;
2. Data e hora da solicitação;
3. Tempo estimado para chegada do veículo no endereço de origem;
4. Valor estimado;
5. Identificação do veículo (placa) e motorista (nome);
6. *Desejável*: imagem geoprocessada do percurso desde a aceitação da solicitação até o endereço de origem;
7. *Desejável*: possibilidade de comunicação entre o usuário e o motorista;
8. Encaminhamento de informação da chegada do veículo no endereço de origem e mensagem na aplicação web e no aplicativo mobile;
9. Cancelamento de solicitação pelo usuário, ressalvada a possibilidade de cobrança da taxa de cancelamento pela CREDENCIADA/CONTRATADA, se o cancelamento ocorrer após o decurso de tempo e/ou distância definido pela CREDENCIADA/CONTRATADA.

##### 2.1.4.2. Acompanhamento da viagem (tempo real)

Acompanhamento da viagem pelo usuário, com no mínimo:

1. Encaminhamento de informação sobre o início da viagem;
2. Tempo estimado para finalização;
3. Imagem geoprocessada do percurso.

##### 2.1.4.3. Acompanhamento da finalização (tempo real)

Acompanhamento da finalização da viagem pelo usuário, em tempo real, com no mínimo:

1. Endereços de origem e destino efetivo;
2. Tempo desde o início até o final do deslocamento;
3. Data e horário de início e fim da viagem;
4. Imagem geoprocessada do percurso;
5. Valor da viagem;
6. Quilometragem percorrida;
7. Avaliação do serviço.

##### 2.1.4.4. Alertas (tempo real)

Deve ser facultado ao usuário a possibilidade de recebimento de alertas por e-mail, SMS e/ou no aplicativo, em tempo real, com no mínimo as seguintes informações: aceite/cancelamento de viagem pelo motorista e chegada do veículo no local de origem.

##### 2.1.4.5. E-mail pós-corrida

Após a confirmação da finalização da corrida, deve ser encaminhado no e-mail do usuário o histórico da corrida e o recibo, contendo, no mínimo, as seguintes informações: endereços de origem e destino efetivo; data e hora da solicitação; data e hora do início e finalização da corrida; valor da tarifa; e nome do motorista.

#### 2.1.5. Avaliação do serviço

1. *Desejável* avaliação do serviço.

---

## 3. FUNCIONALIDADES DO APLICATIVO MOBILE (solicitar, avaliar e consultar histórico)

### 3.1. Condições básicas

O aplicativo mobile da solução tecnológica da CREDENCIADA/CONTRATADA deve contemplar as funcionalidades necessárias para a operação, considerando as seguintes condições básicas:

#### 3.1.1. Senha

1. Cadastramento de senha de acesso à solução tecnológica, com possibilidade de alteração e recuperação da senha a qualquer momento, com encaminhamento de informações desta operação para o seu e-mail.

#### 3.1.2. Solicitação

##### 3.1.2.1. Acompanhamento da solicitação (tempo real)

Acompanhamento da solicitação pelo usuário, em tempo real, com no mínimo:

1. Encaminhamento de informações da solicitação e mensagem na plataforma web e aplicativo mobile;
2. Data e hora da solicitação;
3. Tempo estimado para chegada do veículo no endereço de origem;
4. Valor estimado;
5. Identificação do veículo (placa) e motorista (nome);
6. Dados geoprocessados do trajeto em formato **UTM WGS84** contendo no mínimo informação de latitude e longitude com amostragem mínima de um ponto a cada 10s (dez segundos);
7. Possibilidade de comunicação entre o usuário e o motorista;
8. Encaminhamento de informação da chegada do veículo no endereço de origem e mensagem na aplicação web e no aplicativo mobile.

##### 3.1.2.2. Cancelamento de solicitação

Cancelamento de solicitação pelo usuário, ressalvada a possibilidade de cobrança da taxa de cancelamento pela CREDENCIADA/CONTRATADA, se o cancelamento ocorrer após o decurso de tempo e/ou distância definido pela CREDENCIADA/CONTRATADA.

##### 3.1.2.3. Acompanhamento da corrida (tempo real)

Acompanhamento da corrida pelo usuário, em tempo real, com no mínimo:

1. Encaminhamento de informação sobre o início da corrida;
2. Tempo estimado para finalização;
3. Imagem geoprocessada do percurso.

##### 3.1.2.4. Acompanhamento da finalização (tempo real)

Acompanhamento da finalização da viagem pelo usuário, em tempo real, com no mínimo:

1. Endereços de origem e destino efetivo;
2. Tempo desde o início até o final do deslocamento;
3. Data e horário de início e fim da corrida;
4. Imagem geoprocessada do percurso;
5. Tarifa da corrida;
6. Quilometragem percorrida;
7. Avaliação do serviço.

##### 3.1.2.5. Alertas (tempo real)

Deve ser facultado ao usuário a possibilidade de recebimento de alertas por e-mail, SMS e/ou no aplicativo, em tempo real, com no mínimo as seguintes informações: aceite/cancelamento da solicitação pelo motorista e chegada do veículo no local de origem.

##### 3.1.2.6. E-mail pós-corrida

Após a confirmação da finalização da corrida, deve ser encaminhado no e-mail do usuário o histórico da corrida e o recibo, contendo, no mínimo, as seguintes informações: endereços de origem e destino efetivo; data e hora da solicitação; data e hora do início e finalização da corrida; valor da tarifa; e nome do motorista.

#### 3.1.3. Avaliação do serviço

1. Obrigatória a disponibilização de funcionalidade de avaliação do serviço.

---

## 4. INTEGRAÇÃO COM PLATAFORMA DE SOLUÇÕES DE MOBILIDADE CORPORATIVA DA CREDENCIANTE/CONTRATANTE

### 4.1. Integração via API

A CREDENCIADA/CONTRATADA deverá integrar sua plataforma à solução interna desenvolvida ou contratada pela CREDENCIANTE/CONTRATANTE, via API (Application Programming Interface).

1. A modalidade de integração deve permitir que todas as funcionalidades do sistema da CREDENCIADA/CONTRATADA, conforme requisitos deste anexo, sejam mantidas quando integradas na solução interna desenvolvida ou contratada pela CREDENCIANTE/CONTRATANTE.
2. A integração do sistema da CREDENCIADA/CONTRATADA será realizada mediante comunicação prévia da CREDENCIANTE/CONTRATANTE, com prazo máximo de 30 (trinta) dias corridos para início dos serviços, já integrados.
3. A CREDENCIADA/CONTRATADA deverá permitir integração por intermédio de API (Application Programming Interface) para no mínimo os seguintes itens:
   1. Endpoint de pesquisa de preços (orçamento), solicitação e cancelamento para todas as categorias da CREDENCIADA/CONTRATADA;
   2. Endpoint de consulta, criação, exclusão e edição de usuário;
   3. Endpoint de consulta de recibo de corrida;
   4. Endpoint para avaliação;
   5. Endpoint para consulta, criação, exclusão e edição de centro de custo;
   6. Endpoint para comunicação entre o usuário e o motorista;
   7. Endpoint de relatórios com, no mínimo, os dados do **Anexo D - Relatórios**.
4. *Desejável* a disponibilização de informação de status da corrida e posição do motorista via webhook’s.
5. *Desejável* a disponibilização de API com recurso polyline nos mapas.

### 4.2. Arquivo de respostas

Fornecer, sempre que solicitado pela CREDENCIANTE/CONTRATANTE, arquivo com as respostas das requisições realizadas, preferencialmente no formato **JSON** ou **XML**.

---

# ANEXO D - RELATÓRIOS

## 1. Relatórios de corridas

O sistema deverá disponibilizar on-line todos os dados das corridas para consulta pela CREDENCIANTE/CONTRATANTE, com armazenamento de relatórios de gerenciamento com possibilidade de exportação para arquivos eletrônicos nos formatos **XLS**, **XML** ou **CSV**, com no mínimo os seguintes dados:

a) Identificador único da corrida;  
b) Dados da pesquisa de preços relacionada à corrida com, no mínimo: relação de todas as empresas CREDENCIADAS/CONTRATADAS disponíveis no momento, categoria, tempo estimado para a chegada e valor estimado de cada uma;  
c) Órgão e Unidade (centro de custos);  
d) Usuário solicitante;  
e) Endereços de origem e de destino (registrados e efetivos);  
f) Motivo da solicitação do serviço;  
g) Data e hora da solicitação;  
h) Data e hora do aceite da solicitação pelo motorista;  
i) Data e hora da chegada do veículo ao endereço de origem;  
j) Data e hora do início da corrida;  
k) Data e hora de finalização do atendimento;  
l) Data e hora do cancelamento, se ocorrer;  
m) Data e hora da contestação, se ocorrer;  
n) Identificação do motorista (nome) designado para o atendimento;  
o) Identificação do veículo (placa) designado para o atendimento;  
p) Categoria utilizada;  
q) Dados geoprocessados do trajeto em formato **UTM WGS84** contendo no mínimo informação de latitude e longitude com amostragem mínima de um ponto a cada 10s (dez segundos);  
r) Distância percorrida, calculada automaticamente, considerando o percurso realizado desde o embarque até a finalização do atendimento;  
s) Valores do atendimento;  
t) Data e hora do ateste;  
u) Avaliação realizada.

## 2. Relatórios de dados cadastrais

Relatórios de dados cadastrais de todos os cadastros da CREDENCIANTE/CONTRATANTE:

a) Órgão ou Entidade a que o Gestor ou Usuário está vinculado;  
b) Unidades administrativas a que o Gestor ou Usuário está vinculado;  
c) Perfil de acesso e status do usuário; e  
d) Consulta a todos os dados dos cadastros dos Órgãos ou Entidades e unidades administrativas.

## 3. Histórico em tempo real

Os relatórios de gerenciamento deverão permitir a visualização do histórico de todas as corridas realizadas em tempo real.

## 4. Retenção e disponibilização de dados

As informações das solicitações, corridas e dados cadastrais deverão ser mantidos e disponibilizados pela CREDENCIADA/CONTRATADA por, pelo menos, **90 (noventa) dias** do encerramento da vigência contratual.

### 4.1. Atualização e transferência

Durante a vigência contratual, os dados deverão estar disponíveis a qualquer tempo com periodicidade mínima de atualização diária, via API, acesso à base de dados ou qualquer outro método de transferência de arquivos para a CREDENCIANTE/CONTRATANTE (ex. sFTP).

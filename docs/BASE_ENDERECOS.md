# Base de endereços e geocoding

Este documento descreve o uso de endereços e geocoding na solução Rumo, em conformidade com a exigência de “base de endereços atualizada cadastrada” (Anexo C).

---

## 1. Visão geral

- **Web (backoffice):** endereços são informados como texto (origem/destino) na estimativa e na corrida; coordenadas podem ser obtidas no cliente ou no backend conforme a necessidade.
- **App (passageiro/motorista):** o aplicativo utiliza **geocoding** para converter endereços em coordenadas (lat/lng) e, quando aplicável, para exibir endereços a partir de coordenadas (reverse geocoding), garantindo consistência com o formato UTM WGS84 usado em trajetos e restrições por área.

---

## 2. Serviço de geocoding

### 2.1 Nominatim (OpenStreetMap)

O aplicativo mobile pode utilizar o **Nominatim** (serviço de geocoding da OpenStreetMap) para:

- **Geocoding:** endereço (texto) → latitude/longitude.
- **Reverse geocoding:** latitude/longitude → endereço legível.

**Referência:**  
[https://nominatim.org/release-docs/develop/api/Overview/](https://nominatim.org/release-docs/develop/api/Overview/)

**Políticas de uso (Nominatim):**

- Respeitar a [Usage Policy](https://operations.osmfoundation.org/policies/nominatim/) do serviço (ex.: máximo 1 requisição por segundo por cliente, uso de User-Agent identificável).
- Em produção, considerar hospedagem própria de instância Nominatim ou uso de provedor comercial se o volume exigir.
- Cache no app: evitar requisições repetidas para o mesmo endereço ou ponto; sugerido TTL de cache (ex.: 24 h para endereços já resolvidos).

### 2.2 Alternativas

- **Google Geocoding API** ou **Google Places:** podem ser adotados conforme contrato e custos.
- **Outros provedores:** qualquer serviço que retorne coordenadas WGS84 e endereços pode ser integrado; o backend e o app devem manter o padrão **WGS84 (lat/lng)** para trajetos e áreas permitidas.

---

## 3. Políticas e boas práticas

| Aspecto | Recomendação |
|--------|----------------|
| **Formato de coordenadas** | Sempre WGS84 (latitude, longitude) em toda a aplicação (trajetos, áreas permitidas, geocoding). |
| **Atualização da base** | O uso de Nominatim/OSM ou provedor externo mantém a base de endereços atualizada pela própria fonte; não é necessário “cadastro” interno de ruas. |
| **Cache** | Cachear no app (e, se fizer sentido, no backend) resultados de geocoding/reverse por endereço ou ponto para reduzir chamadas e respeitar limites do provedor. |
| **Fallback** | Se o geocoding falhar, permitir que o usuário informe endereço em texto e, quando possível, usar apenas texto no backend (sem coordenadas) para estimativa; trajeto e restrições por área podem ficar limitados. |
| **Privacidade** | Enviar ao serviço de geocoding apenas o estritamente necessário (endereço ou coordenadas); não incluir dados pessoais na requisição. |

---

## 4. Uso no sistema

- **Restrições por área:** os centros de custo podem ter áreas permitidas (origem/destino) definidas por ponto (lat/lng) e raio (km). O app pode usar geocoding para converter o endereço escolhido pelo passageiro em coordenadas antes de enviar a solicitação.
- **Estimativa e criação de corrida:** a API aceita origem e destino em texto; o backend pode, se implementado, usar geocoding para obter coordenadas quando necessário para cálculo de distância/valor.
- **Trajeto (geoprocessado):** os pontos do trajeto são armazenados em WGS84 (amostragem mínima de um ponto a cada 10 s, conforme especificação), compatíveis com a base de endereços e mapas.

---

## 5. Responsabilidade operacional

- Manter o User-Agent e a identificação da aplicação conforme política do provedor de geocoding.
- Monitorar limites de uso (requisições por segundo/dia) e implementar cache e fallbacks para evitar bloqueios.
- Em ambiente regulado ou de alta disponibilidade, avaliar SLA e redundância do provedor ou instância própria de geocoding.

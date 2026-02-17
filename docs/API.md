# API Rumo

Base URL: `http://localhost:3001` (desenvolvimento).

## Health

- **GET /health** — Verificação de saúde do serviço.
  - Resposta: `{ "ok": true }`.

## Corridas

Todas as rotas de corridas estão sob o prefixo **/api/rides**.

### Calcular preço estimado

- **POST /api/rides/estimate**

Corpo (JSON):

| Campo               | Tipo   | Obrigatório | Descrição                          |
|---------------------|--------|-------------|------------------------------------|
| pickupAddress       | string | sim         | Endereço de embarque               |
| destinationAddress  | string | sim         | Endereço de destino                |
| pickupLat           | number | não         | Latitude do embarque (melhora o cálculo) |
| pickupLng           | number | não         | Longitude do embarque              |
| destinationLat      | number | não         | Latitude do destino                |
| destinationLng      | number | não         | Longitude do destino               |

Se as coordenadas forem enviadas, a distância é calculada (Haversine) e o preço usa essa distância e tempo estimado. Caso contrário, são usados valores padrão.

Resposta 200:

```json
{
  "distanceKm": 2.5,
  "durationMin": 12,
  "estimatedPriceCents": 1375,
  "formattedPrice": "R$ 13,75"
}
```

Erros: 400 (campos obrigatórios faltando), 500 (erro interno).

---

### Solicitar corrida

- **POST /api/rides**

Corpo (JSON):

| Campo                  | Tipo   | Obrigatório | Descrição                    |
|------------------------|--------|-------------|------------------------------|
| pickupAddress          | string | sim         | Endereço de embarque         |
| destinationAddress     | string | sim         | Endereço de destino          |
| estimatedPriceCents    | number | sim         | Preço estimado em centavos   |
| pickupLat / pickupLng  | number | não         | Coordenadas do embarque     |
| destinationLat / destinationLng | number | não  | Coordenadas do destino      |
| estimatedDistanceKm    | number | não         | Distância em km (opcional)   |
| estimatedDurationMin   | number | não         | Duração em min (opcional)    |

Resposta 201:

```json
{
  "id": "uuid",
  "pickup_address": "...",
  "destination_address": "...",
  "estimated_price_cents": 1375,
  "estimated_distance_km": 2.5,
  "estimated_duration_min": 12,
  "status": "requested",
  "created_at": "...",
  "formattedPrice": "R$ 13,75"
}
```

Erros: 400 (campos obrigatórios), 500 (erro interno).

---

### Buscar corrida por ID

- **GET /api/rides/:id**

Resposta 200: objeto da corrida (incluindo `formattedPrice`).

Erros: 404 (não encontrada), 500 (erro interno).

---

### Listar corridas

- **GET /api/rides**

Retorna as últimas 50 corridas (para demonstração).

Resposta 200: array de objetos (id, endereços, preço, status, created_at, formattedPrice).

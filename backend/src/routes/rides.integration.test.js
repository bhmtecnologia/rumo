import 'dotenv/config';
import { describe, it } from 'node:test';
import assert from 'node:assert';
import request from 'supertest';
import app from '../app.js';

const hasDb = !!process.env.DATABASE_URL;

describe('API /api/rides', { skip: !hasDb }, () => {
  describe('POST /api/rides/estimate', () => {
    it('retorna 400 sem pickupAddress', async () => {
      const res = await request(app)
        .post('/api/rides/estimate')
        .send({ destinationAddress: 'Rua X' })
        .expect(400);
      assert.ok(res.body.error);
    });

    it('retorna 400 sem destinationAddress', async () => {
      const res = await request(app)
        .post('/api/rides/estimate')
        .send({ pickupAddress: 'Rua Y' })
        .expect(400);
      assert.ok(res.body.error);
    });

    it('retorna 200 com preço estimado quando endereços são enviados', async () => {
      const res = await request(app)
        .post('/api/rides/estimate')
        .send({
          pickupAddress: 'Av. Paulista, 1000',
          pickupLat: -23.5615,
          pickupLng: -46.6559,
          destinationAddress: 'Praça da Sé',
          destinationLat: -23.5505,
          destinationLng: -46.6333,
        })
        .expect(200);
      assert.ok(typeof res.body.distanceKm === 'number');
      assert.ok(typeof res.body.durationMin === 'number');
      assert.ok(typeof res.body.estimatedPriceCents === 'number');
      assert.ok(res.body.formattedPrice.includes('R$'));
    });
  });

  describe('POST /api/rides', () => {
    it('retorna 400 sem campos obrigatórios', async () => {
      const res = await request(app)
        .post('/api/rides')
        .send({})
        .expect(400);
      assert.ok(res.body.error);
    });

    it('cria corrida e retorna 201 com id e formattedPrice', async () => {
      const res = await request(app)
        .post('/api/rides')
        .send({
          pickupAddress: 'Origem Teste',
          destinationAddress: 'Destino Teste',
          estimatedPriceCents: 1500,
        })
        .expect(201);
      assert.ok(res.body.id);
      assert.strictEqual(res.body.pickup_address, 'Origem Teste');
      assert.strictEqual(res.body.destination_address, 'Destino Teste');
      assert.strictEqual(res.body.estimated_price_cents, 1500);
      assert.strictEqual(res.body.status, 'requested');
      assert.ok(res.body.formattedPrice);
    });
  });

  describe('GET /api/rides/:id', () => {
    it('retorna 404 para id inexistente', async () => {
      await request(app)
        .get('/api/rides/00000000-0000-0000-0000-000000000000')
        .expect(404);
    });

    it('retorna 200 e corrida quando id existe', async () => {
      const create = await request(app)
        .post('/api/rides')
        .send({
          pickupAddress: 'A',
          destinationAddress: 'B',
          estimatedPriceCents: 1000,
        })
        .expect(201);
      const id = create.body.id;
      const res = await request(app).get(`/api/rides/${id}`).expect(200);
      assert.strictEqual(res.body.id, id);
      assert.strictEqual(res.body.pickup_address, 'A');
      assert.ok(res.body.formattedPrice);
    });
  });

  describe('GET /api/rides', () => {
    it('retorna 200 e array de corridas', async () => {
      const res = await request(app).get('/api/rides').expect(200);
      assert.ok(Array.isArray(res.body));
      if (res.body.length > 0) {
        assert.ok(res.body[0].id);
        assert.ok(res.body[0].formattedPrice);
      }
    });
  });
});

describe('GET /health', () => {
  it('retorna 200 e { ok: true }', async () => {
    const res = await request(app).get('/health').expect(200);
    assert.strictEqual(res.body.ok, true);
  });
});

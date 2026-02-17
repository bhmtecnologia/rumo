import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  calculateFare,
  getDistanceAndDuration,
} from './fare.js';

describe('fare', () => {
  describe('calculateFare', () => {
    it('retorna tarifa mínima quando o valor calculado é menor', () => {
      const config = { base_fare_cents: 500, per_km_cents: 100, per_minute_cents: 50, min_fare_cents: 800 };
      assert.strictEqual(calculateFare(0, 0, config), 800);
      assert.strictEqual(calculateFare(1, 2, config), 800);
    });

    it('calcula base + km + minuto com config explícita', () => {
      const config = { base_fare_cents: 500, per_km_cents: 250, per_minute_cents: 50, min_fare_cents: 800 };
      // 500 + 2*250 + 10*50 = 500 + 500 + 500 = 1500
      assert.strictEqual(calculateFare(2, 10, config), 1500);
    });

    it('usa defaults quando config é null/undefined', () => {
      assert.ok(calculateFare(10, 20, null) >= 800);
      assert.ok(calculateFare(10, 20, undefined) >= 800);
    });

    it('arredonda corretamente o valor por km', () => {
      const config = { base_fare_cents: 0, per_km_cents: 100, per_minute_cents: 0, min_fare_cents: 0 };
      assert.strictEqual(calculateFare(1.234, 0, config), 123);
    });
  });

  describe('getDistanceAndDuration', () => {
    it('retorna distância e duração para dois pontos', () => {
      const { distanceKm, durationMin } = getDistanceAndDuration(-23.55, -46.63, -23.56, -46.64);
      assert.ok(distanceKm > 0);
      assert.ok(durationMin >= 1);
    });

    it('distância São Paulo → mesmo ponto é ~0', () => {
      const { distanceKm } = getDistanceAndDuration(-23.55, -46.63, -23.55, -46.63);
      assert.ok(distanceKm < 0.01);
    });

    it('duração mínima é pelo menos 1 minuto', () => {
      const { durationMin } = getDistanceAndDuration(-23.55, -46.63, -23.5501, -46.6301);
      assert.ok(durationMin >= 1);
    });
  });
});

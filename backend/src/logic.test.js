import test from 'node:test';
import assert from 'node:assert/strict';
import { haversineKm, etaRangeMinutes, availabilityLabel, routeKey } from './logic.js';

test('haversine distance for close points is positive', () => {
  const km = haversineKm(23.78, 90.41, 23.79, 90.42);
  assert.ok(km > 0.5 && km < 2.5);
});

test('eta range has min and max', () => {
  const eta = etaRangeMinutes(3);
  assert.ok(eta.min >= 2);
  assert.ok(eta.max > eta.min);
});

test('availability label buckets ratio', () => {
  assert.equal(availabilityLabel(7, 10), 'usually');
  assert.equal(availabilityLabel(4, 10), 'sometimes');
  assert.equal(availabilityLabel(1, 10), 'rare');
});

test('route key rounds coordinates', () => {
  assert.equal(routeKey(1.12345, 2.98765, 3.22222, 4.11111), '1.123,2.988->3.222,4.111');
});

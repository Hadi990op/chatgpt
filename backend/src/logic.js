export function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function etaRangeMinutes(distanceKm, speedKmh = 18) {
  const mins = (distanceKm / speedKmh) * 60;
  return {
    min: Math.max(2, Math.round(mins * 0.8)),
    max: Math.max(5, Math.round(mins * 1.3))
  };
}

export function routeKey(startLat, startLon, endLat, endLon) {
  const r = (v) => Number(v).toFixed(3);
  return `${r(startLat)},${r(startLon)}->${r(endLat)},${r(endLon)}`;
}

export function availabilityLabel(activeCount, sampleCount) {
  if (sampleCount === 0) return 'rare';
  const ratio = activeCount / sampleCount;
  if (ratio >= 0.6) return 'usually';
  if (ratio >= 0.3) return 'sometimes';
  return 'rare';
}

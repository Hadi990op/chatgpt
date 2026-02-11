import express from 'express';
import { readDb, writeDb, id } from './store.js';
import {
  haversineKm,
  etaRangeMinutes,
  routeKey,
  availabilityLabel
} from './logic.js';

const app = express();
app.use(express.json());

app.get('/health', (_, res) => res.json({ ok: true }));

app.post('/api/drivers/login', (req, res) => {
  const { name, phone, vehicleNo } = req.body;
  if (!name || !phone) {
    return res.status(400).json({ error: 'name and phone are required' });
  }
  const db = readDb();
  let driver = db.drivers.find((d) => d.phone === phone);
  if (!driver) {
    driver = {
      id: id('drv'),
      name,
      phone,
      vehicleNo: vehicleNo || '',
      active: false,
      updatedAt: new Date().toISOString()
    };
    db.drivers.push(driver);
  }
  writeDb(db);
  res.json({ driverId: driver.id, name: driver.name });
});

app.post('/api/drivers/:driverId/status', (req, res) => {
  const { driverId } = req.params;
  const { active, lat, lon, route } = req.body;
  const db = readDb();
  const driver = db.drivers.find((d) => d.id === driverId);
  if (!driver) return res.status(404).json({ error: 'driver not found' });

  driver.active = Boolean(active);
  driver.updatedAt = new Date().toISOString();

  if (driver.active) {
    db.activity.push({
      id: id('act'),
      driverId,
      route,
      lat: Number(lat).toFixed(3),
      lon: Number(lon).toFixed(3),
      at: new Date().toISOString()
    });
  }

  writeDb(db);
  res.json({ ok: true, active: driver.active });
});

app.get('/api/availability', (req, res) => {
  const startLat = Number(req.query.startLat);
  const startLon = Number(req.query.startLon);
  const endLat = Number(req.query.endLat);
  const endLon = Number(req.query.endLon);
  const hour = Number(req.query.hour ?? new Date().getHours());

  const route = routeKey(startLat, startLon, endLat, endLon);
  const db = readDb();

  const activeDrivers = db.drivers.filter((d) => d.active);
  const nearby = db.activity
    .filter((a) => a.route === route)
    .slice(-100)
    .map((a) => {
      const distanceKm = haversineKm(startLat, startLon, Number(a.lat), Number(a.lon));
      return {
        driverId: a.driverId,
        distanceKm: Number(distanceKm.toFixed(2)),
        eta: etaRangeMinutes(distanceKm)
      };
    })
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, 5);

  const byHour = db.activity.filter((a) => {
    if (a.route !== route) return false;
    const h = new Date(a.at).getHours();
    return h === hour;
  });

  const label = availabilityLabel(byHour.length, Math.max(1, 10));
  res.json({
    route,
    activeDriverCount: activeDrivers.length,
    availability: label,
    candidates: nearby,
    queriedHour: hour
  });
});

app.post('/api/routes/save', (req, res) => {
  const { travelerId, title, startLat, startLon, endLat, endLon } = req.body;
  if (!travelerId || !title) {
    return res.status(400).json({ error: 'travelerId and title are required' });
  }
  const db = readDb();
  const route = {
    id: id('rt'),
    travelerId,
    title,
    startLat,
    startLon,
    endLat,
    endLon,
    route: routeKey(startLat, startLon, endLat, endLon),
    createdAt: new Date().toISOString()
  };
  db.savedRoutes.push(route);
  writeDb(db);
  res.json(route);
});

app.get('/api/routes/saved/:travelerId', (req, res) => {
  const db = readDb();
  res.json(db.savedRoutes.filter((r) => r.travelerId === req.params.travelerId));
});

app.get('/api/history', (req, res) => {
  const startLat = Number(req.query.startLat);
  const startLon = Number(req.query.startLon);
  const endLat = Number(req.query.endLat);
  const endLon = Number(req.query.endLon);
  const route = routeKey(startLat, startLon, endLat, endLon);
  const db = readDb();

  const routeActivities = db.activity.filter((a) => a.route === route);
  const byHour = new Map();
  for (const a of routeActivities) {
    const hour = new Date(a.at).getHours();
    byHour.set(hour, (byHour.get(hour) || 0) + 1);
  }
  const history = [...byHour.entries()].map(([hour, count]) => ({
    hour,
    label: availabilityLabel(count, 10),
    reports: count
  }));

  res.json({ route, history });
});

app.get('/api/geo/search', async (req, res) => {
  const q = req.query.q;
  if (!q) return res.status(400).json({ error: 'q is required' });
  const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=8&q=${encodeURIComponent(q)}`;
  const r = await fetch(url, {
    headers: { 'User-Agent': 'RickshawPulse/1.0 (community-app)' }
  });
  const data = await r.json();
  res.json(data);
});

app.get('/api/geo/reverse', async (req, res) => {
  const { lat, lon } = req.query;
  if (!lat || !lon) return res.status(400).json({ error: 'lat and lon are required' });
  const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lon}`;
  const r = await fetch(url, {
    headers: { 'User-Agent': 'RickshawPulse/1.0 (community-app)' }
  });
  const data = await r.json();
  res.json(data);
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`API running on http://localhost:${port}`);
});

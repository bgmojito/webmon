const express = require('express');
const cors = require('cors');
const client = require('prom-client');
const { initDb, getTasks, createTask, updateTask, deleteTask } = require('./db');
const app = express();
app.use(cors());
app.use(express.json());
// === Prometheus metrics ===
const register = new client.Registry();
client.collectDefaultMetrics({ register });
const httpRequests = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});
const httpDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register]
});
app.use((req, res, next) => {
  const end = httpDuration.startTimer({ method: req.method, route: req.path });
  res.on('finish', () => {
    httpRequests.inc({ method: req.method, route: req.path, status: res.statusCode });
    console.log(`${new Date().toISOString()} ${req.method} ${req.path} ${res.statusCode}`);
    end();
  });
  next();
});
// === Routes ===
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.post('/webhook/alerts', (req, res) => {
  const alerts = req.body?.alerts || [];
  for (const a of alerts) {
    console.log(`[alertmanager] ${a.status} ${a.labels?.alertname} (${a.labels?.severity}) - ${a.annotations?.summary || ''}`);
  }
  res.status(200).json({ received: alerts.length });
});
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
app.get('/api/tasks', async (req, res) => {
  try {
    const tasks = await getTasks();
    res.json(tasks);
  } catch (e) {
    console.error('GET /tasks failed', e);
    res.status(500).json({ error: 'internal' });
  }
});
app.post('/api/tasks', async (req, res) => {
  try {
    const task = await createTask(req.body.title);
    res.status(201).json(task);
  } catch (e) {
    console.error('POST /tasks failed', e);
    res.status(500).json({ error: 'internal' });
  }
});
app.patch('/api/tasks/:id', async (req, res) => {
  try {
    const task = await updateTask(req.params.id, req.body.done);
    res.json(task);
  } catch (e) {
    console.error('PATCH /tasks failed', e);
    res.status(500).json({ error: 'internal' });
  }
});
app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const task = await deleteTask(req.params.id);
    if (!task) return res.status(404).json({ error: 'not found' });
    res.status(200).json(task);
  } catch (e) {
    console.error('DELETE /tasks failed', e);
    res.status(500).json({ error: 'internal' });
  }
});
const PORT = process.env.PORT || 3001;
initDb().then(() => {
  app.listen(PORT, () => console.log(`Backend listening on ${PORT}`));
}).catch(err => {
  console.error('DB init failed', err);
  process.exit(1);
});

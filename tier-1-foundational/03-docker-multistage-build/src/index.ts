import http from 'http';

const PORT = parseInt(process.env.PORT || '3000', 10);

const server = http.createServer((req, res) => {
    if (req.url === '/health' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', uptime: process.uptime() }));
        return;
    }

    if (req.url === '/' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ message: 'Hello from distroless container!' }));
        return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
    console.log(JSON.stringify({ level: 'info', message: `Server listening on :${PORT}`, env: process.env.NODE_ENV }));
});

process.on('SIGTERM', () => {
    console.log(JSON.stringify({ level: 'info', message: 'SIGTERM received, shutting down gracefully' }));
    server.close(() => process.exit(0));
});

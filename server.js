const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8765 });
const clients = { esp: null, flutter: [] };

wss.on('connection', (ws, req) => {
  ws.on('message', msg => {
    const text = msg.toString();
    // If it looks like JSON, it's the ESP32
    try {
      JSON.parse(text);
      clients.esp = ws;
      // Forward to all Flutter clients
      clients.flutter.forEach(c => {
        if (c.readyState === 1) c.send(text);
      });
    } catch {
      clients.flutter.push(ws);
      console.log('Flutter client connected');
    }
  });
  ws.on('close', () => {
    clients.flutter = clients.flutter.filter(c => c !== ws);
  });
});
console.log('Bridge running on port 8765');
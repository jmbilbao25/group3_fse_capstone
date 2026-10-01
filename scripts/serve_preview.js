const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
  const filePath = path.resolve(__dirname, '../azure_scaling_architecture_preview.html');
  const content = fs.readFileSync(filePath, 'utf-8');
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(content);
});

server.listen(8989, () => {
  console.log('Server running on http://localhost:8989');
});

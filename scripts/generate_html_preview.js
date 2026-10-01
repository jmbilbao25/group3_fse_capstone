const fs = require('fs');
const path = require('path');

const excalidrawPath = path.resolve(__dirname, '../azure_scaling_architecture.excalidraw');
const data = JSON.parse(fs.readFileSync(excalidrawPath, 'utf-8'));

let svgElements = '';

for (const el of data.elements) {
  if (el.type === 'rectangle') {
    const rx = el.roundness ? 8 : 0;
    const strokeDash = el.strokeStyle === 'dashed' ? 'stroke-dasharray="6,6"' : '';
    svgElements += `<rect x="${el.x}" y="${el.y}" width="${el.width}" height="${el.height}" rx="${rx}" fill="${el.backgroundColor}" stroke="${el.strokeColor}" stroke-width="${el.strokeWidth}" ${strokeDash} opacity="${el.opacity / 100}"/>\n`;
  } else if (el.type === 'text') {
    const lines = el.text.split('\n');
    const lineHeight = el.fontSize * (el.lineHeight || 1.3);
    lines.forEach((line, i) => {
      const y = el.y + el.fontSize + (i * lineHeight);
      const escaped = line.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
      svgElements += `<text x="${el.x}" y="${y}" fill="${el.strokeColor}" font-family="system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="${el.fontSize}px" font-weight="${el.fontSize > 15 ? 'bold' : 'normal'}">${escaped}</text>\n`;
    });
  } else if (el.type === 'arrow') {
    const p1 = el.points[0];
    const p2 = el.points[1];
    const x1 = el.x + p1[0];
    const y1 = el.y + p1[1];
    const x2 = el.x + p2[0];
    const y2 = el.y + p2[1];
    const strokeDash = el.strokeStyle === 'dashed' ? 'stroke-dasharray="5,5"' : '';
    
    // Draw line
    svgElements += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${el.strokeColor}" stroke-width="${el.strokeWidth}" ${strokeDash} marker-end="url(#arrowhead)"/>\n`;
  }
}

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Azure Cloud Scaling Architecture</title>
  <style>
    body {
      margin: 0;
      padding: 20px;
      background-color: #0b0f19;
      display: flex;
      justify-content: center;
      font-family: system-ui, sans-serif;
    }
    svg {
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7);
      border-radius: 12px;
      max-width: 100%;
      height: auto;
    }
  </style>
</head>
<body>
  <svg width="2000" height="2050" viewBox="0 0 2000 2050" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
        <polygon points="0 0, 10 3.5, 0 7" fill="#60a5fa" />
      </marker>
    </defs>
    <rect width="100%" height="100%" fill="#0b0f19" />
    ${svgElements}
  </svg>
</body>
</html>`;

const outputPath = path.resolve(__dirname, '../azure_scaling_architecture_preview.html');
fs.writeFileSync(outputPath, html, 'utf-8');
console.log(`Generated HTML/SVG preview at: ${outputPath}`);

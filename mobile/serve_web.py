import http.server
import socketserver
import os
import sys

PORT = 5000
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.js': 'application/javascript',
        '.wasm': 'application/wasm',
        '.json': 'application/json',
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

if __name__ == '__main__':
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(('0.0.0.0', PORT), Handler) as httpd:
        print(f"Serving Flutter Web Production build at http://0.0.0.0:{PORT}")
        sys.stdout.flush()
        httpd.serve_forever()

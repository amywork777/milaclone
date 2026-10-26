"""Local HTTPS fixture; no real notebook, credentials or external services."""
import hashlib
import http.server
import json
import pathlib
import ssl
import subprocess
import tempfile
import threading

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / '.build'
BUILD.mkdir(exist_ok=True)
subprocess.run(['xcrun', 'swiftc', str(ROOT/'Pinboard/Notebook.swift'), str(ROOT/'Pinboard/SyncClient.swift'), str(ROOT/'Tests/TransportChecks.swift'), '-o', str(BUILD/'transport-checks')], check=True)
with tempfile.TemporaryDirectory(dir=BUILD) as temp:
    temp = pathlib.Path(temp)
    cert, key = temp/'cert.pem', temp/'key.pem'
    subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(key), '-out', str(cert), '-days', '1', '-subj', '/CN=localhost'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    der = ssl.PEM_cert_to_DER_cert(cert.read_text())
    fingerprint = hashlib.sha256(der).hexdigest()
    requests = []
    workspace = {'rootCanvasId':'root','canvases':[{'id':'root','title':'Fixture','parentCanvasId':None,'color':None,'icon':None,'createdAt':0}],'items':[],'files':{}}
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def do_GET(self): self.respond()
        def do_POST(self): self.respond()
        def respond(self):
            requests.append((self.path, self.headers.get('Authorization')))
            if self.headers.get('Authorization') != 'Bearer test-only-token':
                self.send_response(401); self.end_headers(); return
            if self.path == '/redirect':
                self.send_response(302); self.send_header('Location','/never-follow'); self.end_headers(); return
            revision = 'revision-1'
            if self.command == 'POST':
                body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                assert body['workspace'] == workspace
                revision = 'revision-2'
            if self.path == '/conflict': revision = 'revision-1'
            payload = json.dumps({'revision':revision,'workspace':workspace}).encode()
            self.send_response(409 if self.path == '/conflict' else 200)
            self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(payload))); self.end_headers(); self.wfile.write(payload)
    server = http.server.HTTPServer(('127.0.0.1',0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
    try:
        subprocess.run([str(BUILD/'transport-checks'), f'https://127.0.0.1:{server.server_port}', fingerprint], check=True)
        assert not any(path == '/never-follow' for path, _ in requests)
        assert not any(token == 'Bearer must-not-be-sent' for _, token in requests)
        print('PASS: server received neither a redirected request nor the wrong-pin credential')
    finally:
        server.shutdown(); thread.join()

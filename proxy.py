from flask import Flask, request, Response
import requests

PI_BASE = "http://100.96.90.126:8080"  # <-- replace with your Pi's Tailscale IP:PORT

app = Flask(__name__)

@app.route('/', defaults={'path': ''}, methods=["GET","POST","PUT","DELETE","PATCH"])
@app.route('/<path:path>', methods=["GET","POST","PUT","DELETE","PATCH"])
def proxy(path):
    url = f"{PI_BASE}/{path}"

    # forward headers except Host
    headers = {k: v for k, v in request.headers if k.lower() != 'host'}

    # forward body
    resp = requests.request(
        method=request.method,
        url=url,
        headers=headers,
        data=request.get_data(),
        params=request.args,
    )

    return Response(
        resp.content,
        status=resp.status_code,
        headers=dict(resp.headers),
    )

if __name__ == '__main__':
    # listen on all interfaces so emulator can see it via 10.0.2.2
    app.run(host="0.0.0.0", port=5000)

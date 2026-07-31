"""config-service: minimal app for Lightwell patch demo."""
import os
import yaml
from flask import Flask, jsonify

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "1.0.0")
CVE_FIX_APPLIED = os.environ.get("CVE_FIX_APPLIED", "none")
LIGHTWELL_FIX = os.environ.get("LIGHTWELL_FIX", "none")


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "config-service"})


@app.route("/version")
def version():
    return jsonify({
        "service": "config-service",
        "version": VERSION,
        "pyyaml_version": yaml.__version__,
        "cve_fix_applied": CVE_FIX_APPLIED,
        "lightwell_fix": LIGHTWELL_FIX,
    })


@app.route("/parse", methods=["POST"])
def parse_config():
    """Endpoint that exercises pyyaml — the vulnerable dependency."""
    from flask import request
    try:
        data = yaml.safe_load(request.get_data(as_text=True))
        return jsonify({"parsed": True, "keys": list(data.keys()) if data else []})
    except yaml.YAMLError as exc:
        return jsonify({"parsed": False, "error": str(exc)}), 400


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

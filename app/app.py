# app.py
# This is the SAMPLE APPLICATION that a "developer" would have written.
# As a DevOps Engineer, you do NOT write this file in real life -
# you receive it already committed in GitHub by the dev team.
# It is included here only so the pipeline has something real to build & deploy.

from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "message": "Hello from the DevOps CI/CD Pipeline Demo App!",
        "hostname": socket.gethostname(),   # shows which pod/container answered
        "version": os.getenv("APP_VERSION", "1.0.0")
    })

@app.route("/health")
def health():
    # Kubernetes and load balancers call this to check if the app is alive.
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

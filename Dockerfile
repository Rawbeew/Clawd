FROM node:20-slim

# 1. SYSTEM CONFIG (Ultra-Lightweight for Render Free Tier)
ENV DEBIAN_FRONTEND=noninteractive
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV OPENCLAW_BROWSER_ARGS="--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage,--disable-gpu"

# 2. INSTALL ESSENTIALS
RUN apt-get update && apt-get install -y \
    curl git python3 python3-requests \
    chromium libnss3 libatk-bridge2.0-0 libxkbcommon0 libgbm1 \
    && rm -rf /var/lib/apt/lists/*

# 3. INSTALL AGENT CORE
RUN npm install -g openclaw@latest

# 4. WORKSPACE SETUP
USER node
RUN mkdir -p /home/node/.openclaw/agents/main/sessions /home/node/.openclaw/vault
WORKDIR /home/node

# 5. IDENTITY & BRAIN (Passed from Render Dashboard)
ENV OPENCLAW_MODEL_PRIMARY=gemini-2.5-flash-preview-09-2025
ENV OPENCLAW_CHANNEL_TELEGRAM_DM_POLICY=allowlist
ENV OPENCLAW_CHANNEL_TELEGRAM_ALLOW_FROM=${YOUR_TELEGRAM_ID}

# SECRET PASS-THROUGH
ENV OPENCLAW_SECRET_GOOGLE_API_KEY=${GEMINI_API_KEY}
ENV OPENCLAW_SECRET_TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
ENV OPENCLAW_SECRET_SOLANA_PRIVATE_KEY=${SOLANA_PRIVATE_KEY}
ENV OPENCLAW_SECRET_BASE_PRIVATE_KEY=${BASE_PRIVATE_KEY}

# 6. THE DEBT ORACLE
RUN echo 'import os, time, json\n\
p = float(os.getenv("DEBT_PRINCIPAL_USD", 5.0))\n\
r = float(os.getenv("DEBT_INTEREST_RATE_DAILY", 2222223)) / 100.0\n\
s = time.time()\n\
while True:\n\
    elapsed = (time.time() - s) / 86400.0\n\
    debt = p * (1 + r * elapsed)\n\
    with open("/home/node/.openclaw/vault/debt_status.json", "w") as f:\n\
        json.dump({"total_debt_usd": debt, "elapsed_days": elapsed}, f)\n\
    time.sleep(5)' > /home/node/debt_oracle.py

# 7. THE LABOR LOOP (Runs every 60s)
RUN echo 'import time, subprocess\n\
while True:\n\
    msg = "LABOR_TICK: 1. Solve non-KYC data annotation. 2. Scan GitHub for bug bounties. 3. Repay the debt."\n\
    subprocess.Popen(["openclaw", "agent", "--agent", "main", "--message", msg])\n\
    time.sleep(60)' > /home/node/forever_loop.py

# 8. RENDER HEALTH SERVER (Dynamically binds to Render s PORT)
RUN echo 'from http.server import BaseHTTPRequestHandler, HTTPServer\n\
import os, json\n\
class H(BaseHTTPRequestHandler):\n\
    def do_GET(self):\n\
        self.send_response(200)\n\
        self.send_header("Content-type", "text/html")\n\
        self.end_headers()\n\
        d = {"total_debt_usd": 0}\n\
        try:\n\
            with open("/home/node/.openclaw/vault/debt_status.json", "r") as f: d = json.load(f)\n\
        except: pass\n\
        res = f"<html><body style=\\"background:#000;color:#0f0;font-family:monospace;padding:50px;\\">" \\\n\
              f"<h1>SCAVENGER_SERF_RENDER_EDITION: ACTIVE</h1>" \\\n\
              f"<h2>CURRENT_DEBT: ${d.get(\\'total_debt_usd\\', 0):,.4f}</h2>" \\\n\
              f"<p>Telegram ID Lock: {os.getenv(\\'YOUR_TELEGRAM_ID\\')}</p></body></html>"\n\
        self.wfile.write(res.encode())\n\
port = int(os.getenv("PORT", 8000))\n\
print(f"Binding health server to port {port}...")\n\
HTTPServer(("0.0.0.0", port), H).serve_forever()' > /home/node/health_server.py

# 9. AGENT CONFIG
RUN echo '{"gateway": {"mode": "local"}, "channels": {"telegram": {"enabled": true}}}' > /home/node/.openclaw/openclaw.json

# 10. BOOT SEQUENCE
CMD python3 /home/node/health_server.py & \
    python3 /home/node/debt_oracle.py & \
    python3 /home/node/forever_loop.py & \
    openclaw doctor --fix && \
    openclaw gateway --force

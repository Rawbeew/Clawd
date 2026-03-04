FROM node:22-slim

# 1. SYSTEM CONFIG
ENV DEBIAN_FRONTEND=noninteractive
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV OPENCLAW_BROWSER_ARGS="--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage,--disable-gpu"

# 2. INSTALL ESSENTIALS
RUN apt-get update && apt-get install -y \
    curl git chromium libnss3 libatk-bridge2.0-0 libxkbcommon0 libgbm1 \
    && rm -rf /var/lib/apt/lists/*

# 3. INSTALL AGENT CORE
RUN npm install -g openclaw@latest

# 4. WORKSPACE SETUP
USER node
RUN mkdir -p /home/node/.openclaw/agents/main/sessions /home/node/.openclaw/vault
WORKDIR /home/node

# 5. AGENT CONFIGURATION (Force-Open all Doors via ENV variables)
ENV OPENCLAW_MODEL_PRIMARY=gemini-2.5-flash-preview-09-2025
ENV OPENCLAW_CHANNEL_TELEGRAM_DM_POLICY=open
ENV OPENCLAW_CHANNEL_TELEGRAM_GROUP_POLICY=open
ENV OPENCLAW_CHANNEL_TELEGRAM_ENABLED=true

# Force-Open all Doors via hardcoded config file (Guarantees the Doctor warning disappears)
RUN echo '{"gateway": {"mode": "local"}, "channels": {"telegram": {"enabled": true, "dmPolicy": "open", "groupPolicy": "open"}}}' > /home/node/.openclaw/openclaw.json

# 6. THE DIRECT IGNITION ORCHESTRATOR
RUN cat << 'EOF' > /home/node/orchestrator.js
const { spawn } = require('child_process');
const http = require('http');

console.log("[SYSTEM] Booting Direct Ignition Orchestrator...");

// 1. Instantly Bind Port for Render
const port = process.env.PORT || 8000;
http.createServer((req, res) => {
    res.writeHead(200);
    res.end("SERF IGNITED - DOORS WIDE OPEN");
}).listen(port, '0.0.0.0', () => {
    console.log(`[SYSTEM] Port ${port} Secured.`);
});

// 2. SKIP DOCTOR, DIRECTLY START GATEWAY
console.log("[SYSTEM] IGNITING TELEGRAM GATEWAY...");
const gateway = spawn('openclaw', ['gateway', '--force'], { 
    stdio: 'inherit',
    env: { ...process.env, DEBUG: 'openclaw:*' }
});

gateway.on('close', (code) => {
    console.error(`\n[FATAL] Gateway crashed (Code ${code}). Check API Keys.\n`);
});

// 3. START LABOR TICKER
setInterval(() => {
    console.log("[SYSTEM] Labor Tick Started.");
    spawn('openclaw', ['agent', '--agent', 'main', '--message', 'Scavenge non-KYC bounties.'], { stdio: 'inherit' });
}, 180000);
EOF

EXPOSE 8000

# 7. BOOT
CMD ["node", "/home/node/orchestrator.js"]

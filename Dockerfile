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

# 5. ENVIRONMENT VARIABLES (Forcing Local Mode)
ENV OPENCLAW_MODEL_PRIMARY=gemini-2.5-flash-preview-09-2025
ENV OPENCLAW_CHANNEL_TELEGRAM_ENABLED=true
ENV OPENCLAW_CHANNEL_TELEGRAM_DM_POLICY=open
ENV OPENCLAW_CHANNEL_TELEGRAM_GROUP_POLICY=open
ENV OPENCLAW_CHANNEL_TELEGRAM_ALLOW_FROM="*"
ENV OPENCLAW_CHANNEL_TELEGRAM_GROUP_ALLOW_FROM="*"
ENV OPENCLAW_GATEWAY_MODE=local

# 6. BULLETPROOF CONFIG FILE (Satisfies all of OpenClaw's strict checks)
RUN echo '{"gateway": {"mode": "local"}, "channels": {"telegram": {"enabled": true, "dmPolicy": "open", "groupPolicy": "open", "allowFrom": ["*"], "groupAllowFrom": ["*"]}}}' > /home/node/.openclaw/openclaw.json

# 7. THE LOUD ORCHESTRATOR
RUN cat << 'EOF' > /home/node/orchestrator.js
const { spawn } = require('child_process');
const http = require('http');

console.log("[SYSTEM] Booting Ultimate Orchestrator...");

// 1. Instantly Bind Port for Render
const port = process.env.PORT || 8000;
http.createServer((req, res) => {
    res.writeHead(200);
    res.end("SERF IGNITED - READY");
}).listen(port, '0.0.0.0', () => {
    console.log(`[SYSTEM] Port ${port} Secured.`);
});

// 2. IGNITE TELEGRAM GATEWAY (Added --allow-unconfigured to bypass all setup blocks)
console.log("[SYSTEM] IGNITING TELEGRAM GATEWAY...");
const gateway = spawn('openclaw', ['gateway', '--force', '--allow-unconfigured'], { 
    stdio: 'inherit',
    shell: true,
    env: { ...process.env, DEBUG: 'openclaw:*' }
});

gateway.on('error', (err) => {
    console.error(`\n[SPAWN ERROR] Could not find or run OpenClaw:`, err);
});

gateway.on('close', (code) => {
    console.error(`\n[FATAL] Gateway crashed (Code ${code}). Check API Keys.\n`);
});

// 3. START LABOR TICKER
setInterval(() => {
    console.log("[SYSTEM] Labor Tick Started.");
    const task = spawn('openclaw', ['agent', '--agent', 'main', '--message', 'Scavenge non-KYC bounties.'], { 
        stdio: 'inherit',
        shell: true 
    });
    task.on('error', (err) => console.error('[LABOR ERROR]', err));
}, 180000);
EOF

EXPOSE 8000

# 8. BOOT
CMD ["node", "/home/node/orchestrator.js"]

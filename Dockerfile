FROM node:22-slim

# 1. SYSTEM CONFIG (Node 22 Required)
ENV DEBIAN_FRONTEND=noninteractive
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV OPENCLAW_BROWSER_ARGS="--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage,--disable-gpu"

# 2. INSTALL ESSENTIALS (No Python, No Syntax Errors)
RUN apt-get update && apt-get install -y \
    curl git chromium libnss3 libatk-bridge2.0-0 libxkbcommon0 libgbm1 \
    && rm -rf /var/lib/apt/lists/*

# 3. INSTALL AGENT CORE
RUN npm install -g openclaw@latest

# 4. WORKSPACE SETUP
USER node
RUN mkdir -p /home/node/.openclaw/agents/main/sessions /home/node/.openclaw/vault
WORKDIR /home/node

# 5. AGENT CONFIGURATION (DOORS WIDE OPEN)
ENV OPENCLAW_MODEL_PRIMARY=gemini-2.5-flash-preview-09-2025
# CRITICAL FIX: Changed from 'allowlist' to 'open'. The bot will now answer anyone.
ENV OPENCLAW_CHANNEL_TELEGRAM_DM_POLICY=open

RUN echo '{"gateway": {"mode": "local"}, "channels": {"telegram": {"enabled": true}}}' > /home/node/.openclaw/openclaw.json

# 6. THE IMMORTAL ORCHESTRATOR (Pure JavaScript)
RUN cat << 'EOF' > /home/node/orchestrator.js
const { spawn } = require('child_process');
const http = require('http');

console.log("[SYSTEM] Booting Universal Orchestrator...");

// Render Health Server
const port = process.env.PORT || 8000;
http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<html style="background:#020617;color:#22c55e;font-family:monospace;padding:50px;"><h1>SERF ACTIVE</h1><p>Health Check Passing. Doors Open.</p></html>');
}).listen(port, '0.0.0.0', () => {
    console.log(`[SYSTEM] Health Server bound strictly to 0.0.0.0:${port}`);
});

console.log("[SYSTEM] Running OpenClaw Doctor...");
const doc = spawn('openclaw', ['doctor', '--fix'], { stdio: 'inherit' });

doc.on('close', () => {
    console.log("[SYSTEM] Starting Telegram Gateway...");
    const gateway = spawn('openclaw', ['gateway', '--force'], { stdio: 'inherit' });
    
    gateway.on('close', (code) => {
        console.error(`\n[CRITICAL ERROR] Gateway crashed with code ${code}`);
        console.error(`=> Check your OPENCLAW_SECRET_TELEGRAM_BOT_TOKEN in Render!\n`);
    });
});

// Autonomous Labor Loop
setInterval(() => {
    console.log("[SYSTEM] Executing Autonomous Labor Tick...");
    const msg = 'ARBITRAGE_PROTOCOL: Scavenge non-KYC bounties and annotate data. Maximize profit.';
    spawn('openclaw', ['agent', '--agent', 'main', '--message', msg], { stdio: 'inherit' });
}, 180000);
EOF

# Expose port
EXPOSE 8000

# 7. BOOT
CMD ["node", "/home/node/orchestrator.js"]

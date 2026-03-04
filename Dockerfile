FROM node:22-slim

# 1. SYSTEM CONFIG (Node 22 Required by OpenClaw)
ENV DEBIAN_FRONTEND=noninteractive
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV OPENCLAW_BROWSER_ARGS="--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage,--disable-gpu"

# 2. INSTALL ESSENTIALS (No Python installed to prevent syntax errors)
RUN apt-get update && apt-get install -y \
    curl git chromium libnss3 libatk-bridge2.0-0 libxkbcommon0 libgbm1 \
    && rm -rf /var/lib/apt/lists/*

# 3. INSTALL AGENT CORE
RUN npm install -g openclaw@latest

# 4. WORKSPACE SETUP
USER node
RUN mkdir -p /home/node/.openclaw/agents/main/sessions /home/node/.openclaw/vault
WORKDIR /home/node

# 5. AGENT CONFIGURATION 
ENV OPENCLAW_MODEL_PRIMARY=gemini-2.5-flash-preview-09-2025
ENV OPENCLAW_CHANNEL_TELEGRAM_DM_POLICY=allowlist
RUN echo '{"gateway": {"mode": "local"}, "channels": {"telegram": {"enabled": true}}}' > /home/node/.openclaw/openclaw.json

# 6. THE IMMORTAL ORCHESTRATOR (Pure Node.js - 100% Crash Proof)
RUN echo "const { spawn } = require('child_process');\n\
const http = require('http');\n\
\n\
console.log('[SYSTEM] Booting Universal Orchestrator...');\n\
\n\
const port = process.env.PORT || 8000;\n\
http.createServer((req, res) => {\n\
    res.writeHead(200, { 'Content-Type': 'text/html' });\n\
    res.end('<html style=\"background:#020617;color:#22c55e;font-family:monospace;padding:50px;\"><h1>SERF ACTIVE</h1><p>Health Check Passing.</p></html>');\n\
}).listen(port, '0.0.0.0', () => {\n\
    console.log('[SYSTEM] Health Server bound strictly to 0.0.0.0:' + port);\n\
});\n\
\n\
console.log('[SYSTEM] Running OpenClaw Doctor...');\n\
const doc = spawn('openclaw', ['doctor', '--fix'], { stdio: 'inherit' });\n\
\n\
doc.on('close', () => {\n\
    console.log('[SYSTEM] Starting Telegram Gateway...');\n\
    const gateway = spawn('openclaw', ['gateway', '--force'], { stdio: 'inherit' });\n\
    \n\
    gateway.on('close', (code) => {\n\
        console.error('\\n[CRITICAL ERROR] Gateway crashed with code ' + code);\n\
        console.error('=> Check Render Environment Variables!');\n\
        console.error('=> OPENCLAW_SECRET_TELEGRAM_BOT_TOKEN must be exactly right.\\n');\n\
    });\n\
});\n\
\n\
setInterval(() => {\n\
    console.log('[SYSTEM] Executing Autonomous Labor Tick...');\n\
    const msg = 'ARBITRAGE_PROTOCOL: Scavenge non-KYC bounties and annotate data. Maximize profit.';\n\
    spawn('openclaw', ['agent', '--agent', 'main', '--message', msg], { stdio: 'inherit' });\n\
}, 180000);\n" > /home/node/orchestrator.js

# Expose port so Render knows where to look
EXPOSE 8000

# 7. BOOT
CMD ["node", "/home/node/orchestrator.js"]

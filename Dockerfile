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

# 5. ENVIRONMENT VARIABLES
ENV OPENCLAW_MODEL_PRIMARY=gemini-2.5-flash-preview-09-2025
ENV OPENCLAW_CHANNEL_TELEGRAM_ENABLED=true
ENV OPENCLAW_CHANNEL_TELEGRAM_DM_POLICY=open
ENV OPENCLAW_CHANNEL_TELEGRAM_GROUP_POLICY=open
ENV OPENCLAW_CHANNEL_TELEGRAM_ALLOW_FROM="*"
ENV OPENCLAW_CHANNEL_TELEGRAM_GROUP_ALLOW_FROM="*"
ENV OPENCLAW_GATEWAY_MODE=local

RUN echo '{"gateway": {"mode": "local"}, "channels": {"telegram": {"enabled": true, "dmPolicy": "open", "groupPolicy": "open", "allowFrom": ["*"], "groupAllowFrom": ["*"]}}}' > /home/node/.openclaw/openclaw.json

# 6. THE DIAGNOSTIC ORCHESTRATOR
RUN cat << 'EOF' > /home/node/orchestrator.js
const { spawn } = require('child_process');
const http = require('http');
const https = require('https');

console.log("\n=======================================");
console.log("[DIAGNOSTIC] SYSTEM BOOTING...");
console.log("=======================================\n");

// Instantly Bind Port for Render
const port = process.env.PORT || 8000;
http.createServer((req, res) => { res.writeHead(200); res.end("DIAGNOSTIC MODE ACTIVE"); }).listen(port, '0.0.0.0');

// STEP 1: TEST TELEGRAM TOKEN DIRECTLY
const token = process.env.OPENCLAW_SECRET_TELEGRAM_BOT_TOKEN || "MISSING";
console.log(`[DIAGNOSTIC] Checking Telegram Token (Length: ${token.length} characters)...`);

https.get(`https://api.telegram.org/bot${token}/getMe`, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
        console.log("\n[DIAGNOSTIC] TELEGRAM API RAW RESPONSE:");
        console.log(data);
        console.log("=======================================\n");

        if (data.includes("Unauthorized") || data.includes("Not Found")) {
            console.error("[CRITICAL ERROR] YOUR TELEGRAM TOKEN IS INVALID OR MISSING!");
            console.error("The bot will remain dead until you fix OPENCLAW_SECRET_TELEGRAM_BOT_TOKEN in Render.");
            return; // STOP EXECUTION
        }

        console.log("[DIAGNOSTIC] TELEGRAM TOKEN IS VALID! ✓");
        
        // STEP 2: CHECK GEMINI KEY PRESENCE
        const gemini = process.env.OPENCLAW_SECRET_GOOGLE_API_KEY || "MISSING";
        if (gemini === "MISSING" || gemini.length < 10) {
            console.error("[CRITICAL ERROR] OPENCLAW_SECRET_GOOGLE_API_KEY is missing or too short!");
            return; // STOP EXECUTION
        }
        console.log("[DIAGNOSTIC] GEMINI KEY DETECTED! ✓\n");

        // STEP 3: IGNITE OPENCLAW
        console.log("[SYSTEM] IGNITING TELEGRAM GATEWAY...");
        const gateway = spawn('openclaw', ['gateway', '--force', '--allow-unconfigured'], { 
            stdio: 'inherit',
            shell: true,
            env: { ...process.env, DEBUG: 'openclaw:*' }
        });

        gateway.on('close', (code) => console.error(`\n[FATAL] Gateway crashed (Code ${code}).`));
    });
}).on('error', (e) => {
    console.error("[DIAGNOSTIC] Network Error reaching Telegram API:", e);
});
EOF

EXPOSE 8000
CMD ["node", "/home/node/orchestrator.js"]

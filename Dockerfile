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

# 5. ENVIRONMENT VARIABLES (Forcing Google/Gemini Provider)
ENV OPENCLAW_MODEL_PRIMARY=gemini-2.5-flash-preview-09-2025
ENV OPENCLAW_PROVIDER_PRIMARY=google
ENV OPENCLAW_GATEWAY_MODE=local

# Hardcoded config to ensure Telegram is OFF and Google is ON
RUN echo '{"gateway": {"mode": "local"}, "channels": {"telegram": {"enabled": false}}, "providers": {"primary": "google"}}' > /home/node/.openclaw/openclaw.json

# 6. THE AUTO-AUTH ORCHESTRATOR
RUN cat << 'EOF' > /home/node/orchestrator.js
const { exec, spawn } = require('child_process');
const http = require('http');

console.log("[SYSTEM] Booting Auto-Auth Orchestrator...");
const port = process.env.PORT || 8000;

// STEP 1: FORCE AUTHENTICATION (Fixes the "No API key found" error)
const apiKey = process.env.OPENCLAW_SECRET_GOOGLE_API_KEY;
if (!apiKey) {
    console.error("[CRITICAL] OPENCLAW_SECRET_GOOGLE_API_KEY is missing from Render Variables!");
} else {
    console.log("[SYSTEM] Injecting Gemini Auth Profiles...");
    exec(`openclaw auth add --provider google --key ${apiKey}`, (err) => {
        if (err) console.error("[AUTH ERROR]", err);
        else console.log("[SYSTEM] Gemini Auth Verified. ✓");
    });
}

const HTML = `
<!DOCTYPE html>
<html>
<head>
    <title>SCAVENGER TERMINAL</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { background: #0a0a0a; color: #00ff41; font-family: 'Courier New', monospace; padding: 20px; margin: 0; display: flex; flex-direction: column; height: 100vh; box-sizing: border-box; }
        #chat { flex-grow: 1; overflow-y: auto; border: 1px solid #333; background: #000; padding: 20px; margin-bottom: 20px; white-space: pre-wrap; box-shadow: inset 0 0 10px #00ff4133; }
        .input-area { display: flex; gap: 10px; }
        input { flex-grow: 1; background: #111; color: #00ff41; border: 1px solid #333; padding: 15px; font-family: inherit; font-size: 16px; outline: none; }
        button { background: #00ff41; color: #000; border: none; padding: 15px 30px; cursor: pointer; font-weight: bold; font-family: inherit; }
        .u { color: #008f11; } 
        .b { color: #fff; }    
    </style>
</head>
<body>
    <div style="margin-bottom:10px;">[ STATUS: AUTH_INJECTED ] [ PROVIDER: GOOGLE ]</div>
    <div id="chat">BOT: Gemini Link established. I am ready for orders.</div>
    <div class="input-area">
        <input type="text" id="cmd" placeholder="Ask a question..." autocomplete="off" onkeypress="if(event.key === 'Enter') send()">
        <button onclick="send()">RUN</button>
    </div>
    <script>
        function send() {
            const i = document.getElementById('cmd');
            const chat = document.getElementById('chat');
            if(!i.value) return;
            
            chat.innerHTML += '\\n\\n<span class="u">>>> ' + i.value + '</span>\\n<span style="color:#444">Thinking...</span>';
            chat.scrollTop = chat.scrollHeight;
            
            fetch('/execute', { method: 'POST', body: i.value })
                .then(r => r.text())
                .then(t => {
                    chat.innerHTML = chat.innerHTML.replace('<span style="color:#444">Thinking...</span>', '') + '<span class="b">' + t + '</span>';
                    chat.scrollTop = chat.scrollHeight;
                });
            i.value = '';
        }
    </script>
</body>
</html>`;

http.createServer((req, res) => {
    if (req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(HTML);
    } else if (req.method === 'POST' && req.url === '/execute') {
        let b = '';
        req.on('data', c => b += c);
        req.on('end', () => {
            console.log(`[EXEC] ${b}`);
            // Force the agent to use the google provider in the command
            const cmd = `openclaw agent --agent main --provider google --message "${b.replace(/"/g, '\\"')}"`;
            exec(cmd, (err, stdout, stderr) => {
                res.writeHead(200, { 'Content-Type': 'text/plain' });
                res.end(stdout || stderr || "Task complete.");
            });
        });
    }
}).listen(port, '0.0.0.0', () => console.log(`[SYSTEM] Terminal Live on ${port}`));

setInterval(() => {
    spawn('openclaw', ['agent', '--agent', 'main', '--provider', 'google', '--message', 'Perform background scavenging.'], { shell: true });
}, 300000);
EOF

EXPOSE 8000
CMD ["node", "/home/node/orchestrator.js"]

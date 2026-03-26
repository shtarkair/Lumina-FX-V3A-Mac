// Thin wrapper: patches the HTML file path then loads the original server
const fs = require('fs');
const path = require('path');

// Read original server, replace the HTML file reference
let serverCode = fs.readFileSync(path.join(__dirname, 'lighting-server.js'), 'utf8');
serverCode = serverCode.replace(
  "const filePath = path.join(__dirname, 'lighting-app.html');",
  "const filePath = path.join(os.homedir(), 'Desktop', 'Lumina-FX-V1A-Mac', 'lighting-app-V2A.html');"
);

// Fix origin/master to use the correct remote branch for update checking
serverCode = serverCode.replace(/origin\/master/g, 'origin/claude/setup-mac-installation-GfViV');

// Add USB shows endpoint - scan /Volumes/ for .lumina files and list drives
const usbEndpoint = `
  if (req.url === '/api/list-usb-shows' && req.method === 'GET') {
    try {
      const shows = [];
      const drives = [];
      const internalNames = ['Macintosh HD', 'Preboot', 'Recovery', 'VM', 'Update', 'Data'];
      const volumes = fs.readdirSync('/Volumes/', { withFileTypes: true });
      for (const vol of volumes) {
        if (!vol.isDirectory()) continue;
        const volName = vol.name;
        if (internalNames.includes(volName)) continue;
        const volPath = path.join('/Volumes', volName);
        try { const stat = fs.statSync(volPath); drives.push({ name: volName, path: volPath }); } catch(e) { continue; }
        const scanDir = (dir, depth) => {
          if (depth > 2) return;
          try {
            const entries = fs.readdirSync(dir, { withFileTypes: true });
            for (const e of entries) {
              if (e.name.startsWith('.')) continue;
              const fp = path.join(dir, e.name);
              if (e.isFile() && e.name.endsWith('.lumina')) {
                const stat = fs.statSync(fp);
                let showName = e.name.replace('.lumina', '');
                try { const raw = JSON.parse(fs.readFileSync(fp, 'utf8')); if (raw.showName) showName = raw.showName; } catch(err) {}
                shows.push({ volume: volName, path: fp, filename: e.name, showName, size: stat.size, modified: stat.mtime.toISOString() });
              } else if (e.isDirectory() && depth < 2) {
                scanDir(fp, depth + 1);
              }
            }
          } catch(err) {}
        };
        scanDir(volPath, 0);
      }
      shows.sort((a, b) => new Date(b.modified) - new Date(a.modified));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, shows, drives }));
    } catch (e) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, shows: [], drives: [] }));
    }
    return;
  }

  if (req.url.startsWith('/api/load-usb-show/') && req.method === 'GET') {
    const fp = decodeURIComponent(req.url.replace('/api/load-usb-show/', ''));
    try {
      if (!fp.startsWith('/Volumes/')) { res.writeHead(403); res.end('Forbidden'); return; }
      const data = fs.readFileSync(fp, 'utf8');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(data);
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: false, error: e.message }));
    }
    return;
  }

  if (req.url === '/api/save-to-usb' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const { drive, showName, data } = JSON.parse(body);
        const drivePath = path.join('/Volumes', drive);
        if (!fs.existsSync(drivePath)) { res.writeHead(400, {'Content-Type':'application/json'}); res.end(JSON.stringify({ok:false,error:'Drive not found'})); return; }
        const luminaDir = path.join(drivePath, 'Lumina Shows');
        if (!fs.existsSync(luminaDir)) fs.mkdirSync(luminaDir, {recursive:true});
        const filePath = path.join(luminaDir, showName + '.lumina');
        fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ok:true, path: filePath}));
      } catch(e) {
        res.writeHead(500, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ok:false, error: e.message}));
      }
    });
    return;
  }
`;
// Inject USB endpoint after the list-shows endpoint
serverCode = serverCode.replace(
  "// --- Load a specific show",
  usbEndpoint + "\n  // --- Load a specific show"
);

// Add backup rotation for auto-saves
serverCode = serverCode.replace(
  "fs.writeFileSync(filepath, JSON.stringify(data, null, 2));",
  `if (data.isAutoSave) {
        // Rotate backups: backup-3 -> delete, backup-2 -> backup-3, backup-1 -> backup-2, current -> backup-1
        const backupBase = filepath.replace('.lumina', '');
        try { if(fs.existsSync(backupBase+'.backup-3.lumina')) fs.unlinkSync(backupBase+'.backup-3.lumina'); } catch(e){}
        try { if(fs.existsSync(backupBase+'.backup-2.lumina')) fs.renameSync(backupBase+'.backup-2.lumina', backupBase+'.backup-3.lumina'); } catch(e){}
        try { if(fs.existsSync(backupBase+'.backup-1.lumina')) fs.renameSync(backupBase+'.backup-1.lumina', backupBase+'.backup-2.lumina'); } catch(e){}
        try { if(fs.existsSync(filepath)) fs.renameSync(filepath, backupBase+'.backup-1.lumina'); } catch(e){}
        console.log('[AUTOSAVE] Backup rotated for:', name);
      }
      fs.writeFileSync(filepath, JSON.stringify(data, null, 2));`
);

// Execute with correct module resolution paths
const Module = require('module');
const m = new Module(path.join(__dirname, 'lighting-server-V2A.js'));
m.filename = path.join(__dirname, 'lighting-server-V2A.js');
m.paths = Module._nodeModulePaths(__dirname);
m._compile(serverCode, path.join(__dirname, 'lighting-server-V2A.js'));

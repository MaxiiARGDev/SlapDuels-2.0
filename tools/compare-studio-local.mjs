import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const WORKSPACE_ROOT = 'h:/repos-github/SlapDuels-2.0';
const PORT = 49153;

// Find all existing source files locally
function getAllLocalFiles(dir) {
    const results = [];
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            if (entry.name !== 'node_modules' && entry.name !== '.git') {
                results.push(...getAllLocalFiles(full));
            }
        } else if (entry.isFile()) {
            if (/\.(luau|lua)$/i.test(entry.name)) {
                results.push(full.replace(/\\/g, '/'));
            }
        }
    }
    return results;
}

const localFiles = getAllLocalFiles(path.join(WORKSPACE_ROOT, 'src')).map(p => 
    p.substring(WORKSPACE_ROOT.replace(/\\/g, '/').length + 1)
);

console.log(`Found ${localFiles.length} local source files in src/`);

function normalizeNewlines(str) {
    if (!str) return '';
    return str.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

// Build a mapping from potential studio target to local file
// e.g. "ServerScriptService/Services/MatchmakingService" -> "src/server/Services/MatchmakingService.luau"
const studioToLocalCandidate = new Map();

for (const rel of localFiles) {
    let clean = rel;
    // Strip src/ prefix
    let target = '';
    if (clean === 'src/server/RagdollModule.luau') {
        target = 'ServerStorage/RagdollModule';
    } else if (clean.startsWith('src/server/')) {
        target = 'ServerScriptService/' + clean.substring('src/server/'.length);
    } else if (clean.startsWith('src/client/')) {
        target = 'StarterPlayer/StarterPlayerScripts/' + clean.substring('src/client/'.length);
    } else if (clean.startsWith('src/shared/')) {
        target = 'ReplicatedStorage/Shared/' + clean.substring('src/shared/'.length);
    } else if (clean.startsWith('src/character/')) {
        target = 'StarterPlayer/StarterCharacterScripts/' + clean.substring('src/character/'.length);
    } else if (clean.startsWith('src/world/')) {
        target = 'Workspace/' + clean.substring('src/world/'.length);
    }

    if (target) {
        // Strip suffixes: .server.luau, .client.luau, .luau, /init.luau, etc.
        const key = target
            .replace(/\/init\.(server|client)\.(luau|lua)$/i, '')
            .replace(/\/init\.(luau|lua)$/i, '')
            .replace(/\.(server|client)\.(luau|lua)$/i, '')
            .replace(/\.(luau|lua)$/i, '');
        studioToLocalCandidate.set(key, rel);
    }
}

const receivedScripts = [];

const server = http.createServer((req, res) => {
    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                if (req.url === '/batch') {
                    const items = JSON.parse(body);
                    receivedScripts.push(...items);
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ status: 'ok', totalSoFar: receivedScripts.length }));
                    return;
                }

                if (req.url === '/finish') {
                    const shouldApply = req.headers['x-apply'] === 'true';
                    console.log(`Processing ${receivedScripts.length} received scripts from Studio (apply=${shouldApply})...`);

                    const matched = [];
                    const modified = [];
                    const identical = [];
                    const newInStudio = [];
                    const localTouched = new Set();

                    for (const item of receivedScripts) {
                        const studioPath = item.path;
                        const localRel = studioToLocalCandidate.get(studioPath);

                        if (localRel) {
                            localTouched.add(localRel);
                            const fullLocalPath = path.join(WORKSPACE_ROOT, localRel);
                            const localContent = fs.existsSync(fullLocalPath) ? fs.readFileSync(fullLocalPath, 'utf8') : null;
                            const normStudio = normalizeNewlines(item.source);
                            const normLocal = normalizeNewlines(localContent);

                            if (normStudio === normLocal) {
                                identical.push({ studioPath, localRel });
                            } else {
                                modified.push({
                                    studioPath,
                                    localRel,
                                    studioLen: normStudio.length,
                                    localLen: normLocal.length,
                                    studioLines: normStudio.split('\n').length,
                                    localLines: normLocal.split('\n').length,
                                    item
                                });

                                if (shouldApply) {
                                    fs.writeFileSync(fullLocalPath, item.source, 'utf8');
                                }
                            }
                        } else {
                            newInStudio.push(item);
                        }
                    }

                    const missingFromStudio = localFiles.filter(f => !localTouched.has(f));

                    const report = {
                        totalReceived: receivedScripts.length,
                        identicalCount: identical.length,
                        modifiedCount: modified.length,
                        newInStudioCount: newInStudio.length,
                        missingFromStudioCount: missingFromStudio.length,
                        modified: modified.map(m => ({
                            studioPath: m.studioPath,
                            localRel: m.localRel,
                            studioLines: m.studioLines,
                            localLines: m.localLines,
                            diffBytes: m.studioLen - m.localLen
                        })),
                        newInStudio: newInStudio.map(n => ({
                            path: n.path,
                            className: n.className,
                            lines: normalizeNewlines(n.source).split('\n').length
                        })),
                        missingFromStudio
                    };

                    fs.writeFileSync(
                        path.join(WORKSPACE_ROOT, 'tools/sync-report.json'),
                        JSON.stringify(report, null, 2),
                        'utf8'
                    );

                    console.log('--- AUDIT REPORT SUMMARY ---');
                    console.log(`Identical: ${identical.length}`);
                    console.log(`Modified: ${modified.length}`);
                    console.log(`New in Studio: ${newInStudio.length}`);
                    console.log(`Local files not in Studio: ${missingFromStudio.length}`);

                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify(report));

                    setTimeout(() => {
                        server.close();
                        process.exit(0);
                    }, 1000);
                    return;
                }

                res.writeHead(404);
                res.end();
            } catch (err) {
                console.error('Error handling request:', err);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
    } else {
        res.writeHead(404);
        res.end();
    }
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`Comparison server listening on http://127.0.0.1:${PORT}`);
});

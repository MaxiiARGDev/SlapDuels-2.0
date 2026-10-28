import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const WORKSPACE_ROOT = 'h:/repos-github/SlapDuels-2.0';
const PORT = 49154;

function ensureDir(filePath) {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
}

// Map each Studio path to target file in repo
function getTargetPath(studioPath, className) {
    // 1. ServerScriptService
    if (studioPath === 'ServerScriptService/GlobalAnnounce') {
        return path.join(WORKSPACE_ROOT, 'src/server/GlobalAnnounce.server.luau');
    }

    // 2. StarterPlayerScripts
    if (studioPath === 'StarterPlayer/StarterPlayerScripts/WindController') {
        return path.join(WORKSPACE_ROOT, 'src/client/WindController/init.client.luau');
    }
    if (studioPath === 'StarterPlayer/StarterPlayerScripts/WindController/WindLines') {
        return path.join(WORKSPACE_ROOT, 'src/client/WindController/WindLines.luau');
    }
    if (studioPath === 'StarterPlayer/StarterPlayerScripts/WindController/WindShake') {
        return path.join(WORKSPACE_ROOT, 'src/client/WindController/WindShake/init.luau');
    }
    if (studioPath === 'StarterPlayer/StarterPlayerScripts/WindController/WindShake/Settings') {
        return path.join(WORKSPACE_ROOT, 'src/client/WindController/WindShake/Settings.luau');
    }
    if (studioPath === 'StarterPlayer/StarterPlayerScripts/WindController/WindShake/Octree') {
        return path.join(WORKSPACE_ROOT, 'src/client/WindController/WindShake/Octree/init.luau');
    }
    if (studioPath === 'StarterPlayer/StarterPlayerScripts/WindController/WindShake/Octree/OctreeNode') {
        return path.join(WORKSPACE_ROOT, 'src/client/WindController/WindShake/Octree/OctreeNode.luau');
    }
    if (studioPath === 'StarterPlayer/StarterPlayerScripts/WindController/WindShake/Octree/OctreeRegionUtils') {
        return path.join(WORKSPACE_ROOT, 'src/client/WindController/WindShake/Octree/OctreeRegionUtils.luau');
    }

    if (studioPath === 'StarterPlayer/StarterPlayerScripts/ZoneShopMusicPause') {
        return path.join(WORKSPACE_ROOT, 'src/client/ZoneShopMusicPause.client.luau');
    }

    if (studioPath.startsWith('StarterPlayer/StarterPlayerScripts/GroupPromptTrigger/')) {
        const sub = studioPath.substring('StarterPlayer/StarterPlayerScripts/GroupPromptTrigger/'.length);
        return path.join(WORKSPACE_ROOT, `src/client/GroupPromptTrigger/${sub}.client.luau`);
    }

    // 3. ReplicatedStorage
    if (studioPath === 'ReplicatedStorage/DialogModule') {
        return path.join(WORKSPACE_ROOT, 'src/shared/DialogModule.luau');
    }

    // 4. StarterGui scripts
    if (studioPath.startsWith('StarterGui/')) {
        const sub = studioPath.substring('StarterGui/'.length);
        // Replace spaces or invalid characters if needed, keep clean path
        const sanitized = sub.replace(/\s+/g, '_');
        const ext = className === 'ModuleScript' ? '.luau' : 
                    (className === 'Script' ? '.server.luau' : '.client.luau');
        return path.join(WORKSPACE_ROOT, `src/ui/scripts/${sanitized}${ext}`);
    }

    return null;
}

const writtenFiles = [];

const server = http.createServer((req, res) => {
    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const items = JSON.parse(body);
                for (const item of items) {
                    const target = getTargetPath(item.path, item.className);
                    if (target) {
                        ensureDir(target);
                        fs.writeFileSync(target, item.source, 'utf8');
                        writtenFiles.push({
                            studioPath: item.path,
                            targetFile: target.replace(WORKSPACE_ROOT.replace(/\\/g, '/'), ''),
                            lines: item.source.split('\n').length,
                            bytes: Buffer.byteLength(item.source, 'utf8')
                        });
                        console.log(`Saved: ${item.path} -> ${target}`);
                    } else {
                        console.warn(`No target mapping for: ${item.path}`);
                    }
                }

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ status: 'ok', written: writtenFiles.length }));
            } catch (err) {
                console.error('Error saving files:', err);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
    } else if (req.url === '/done') {
        console.log(`Finished export! Total files written: ${writtenFiles.length}`);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ totalWritten: writtenFiles.length, files: writtenFiles }));
        setTimeout(() => {
            server.close();
            process.exit(0);
        }, 500);
    } else {
        res.writeHead(404);
        res.end();
    }
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`Export server listening on http://127.0.0.1:${PORT}`);
});

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const root = process.argv[2] || process.cwd();
const req = createRequire(path.join(root, 'package.json'));
const { createPackagedRuntimeNodeModuleResources } = req('./config/packaged-runtime-node-modules.cjs');

const distAsar = path.join(root, 'dist-asar');
fs.rmSync(distAsar, { recursive: true, force: true });
fs.mkdirSync(path.join(distAsar, 'resources'), { recursive: true });
fs.mkdirSync(path.join(distAsar, 'node_modules'), { recursive: true });

console.log("===> Copying package.json, resources, and out...");
fs.copyFileSync(path.join(root, 'package.json'), path.join(distAsar, 'package.json'));
fs.cpSync(path.join(root, 'resources'), path.join(distAsar, 'resources'), { recursive: true, dereference: true });
fs.cpSync(path.join(root, 'out'), path.join(distAsar, 'out'), { recursive: true, dereference: true });

console.log("===> Copying runtime node_modules...");
const resources = createPackagedRuntimeNodeModuleResources('linux');
for (const res of resources) {
  const dest = path.join(distAsar, res.to);
  if (!fs.existsSync(res.from)) {
    continue;
  }
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(res.from, dest, { recursive: true, dereference: true });
}

// Remove devDependencies in process-host if copied
const devProcessHostModules = path.join(distAsar, 'node_modules/@orca/process-host/node_modules');
if (fs.existsSync(devProcessHostModules)) {
  fs.rmSync(devProcessHostModules, { recursive: true, force: true });
}

// Ensure native modules compiled are copied into dist-asar
const findAndCopyNative = (name, binary) => {
  const modDir = path.join(root, 'node_modules', name);
  if (!fs.existsSync(modDir)) return;
  const realModDir = fs.realpathSync(modDir);
  const candidates = [
    path.join(modDir, 'build/Release', binary),
    path.join(realModDir, 'build/Release', binary)
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) {
      const destDir = path.join(distAsar, 'node_modules', name, 'build/Release');
      fs.mkdirSync(destDir, { recursive: true });
      fs.copyFileSync(c, path.join(destDir, binary));
      console.log(`===> Copied native binary ${binary} for ${name}`);
      break;
    }
  }
};

findAndCopyNative('node-pty', 'pty.node');
findAndCopyNative('@parcel/watcher', 'watcher.node');

console.log("===> Done preparing dist-asar.");

// settings.json을 macOS/Windows가 공유하므로, herdr가 OS별로 설치한 hook 스크립트로 넘긴다
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const win = process.platform === 'win32';
const script = path.join(__dirname, win ? 'herdr-agent-state.ps1' : 'herdr-agent-state.sh');
if (!fs.existsSync(script)) return; // herdr 미설치 기기
const [cmd, args] = win
  ? ['powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script]]
  : ['sh', [script]];
process.exitCode = spawnSync(cmd, [...args, ...process.argv.slice(2)], { stdio: 'inherit' }).status ?? 0;

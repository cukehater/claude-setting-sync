// settings.json을 macOS/Windows가 공유하므로, herdr가 OS별로 설치한 hook 스크립트로 넘긴다
const path = require('path');
const { spawnSync } = require('child_process');
const [cmd, args] = process.platform === 'win32'
  ? ['powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(__dirname, 'herdr-agent-state.ps1')]]
  : ['sh', [path.join(__dirname, 'herdr-agent-state.sh')]];
process.exitCode = spawnSync(cmd, [...args, ...process.argv.slice(2)], { stdio: 'inherit' }).status ?? 0;

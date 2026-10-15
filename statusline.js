const os = require('os');
let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  const d = JSON.parse(raw || '{}');
  const dir = (d.workspace?.current_dir || '').replace(os.homedir(), '~');
  const model = d.model?.display_name || '?';
  const used = Math.round(d.context_window?.used_percentage || 0);
  const filled = Math.round(used / 10);
  const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);

  const parts = [`DIR: ${dir}`, `MODEL: ${model} - [${bar}] ${used}%`];

  // rate_limits는 구버전 CLI 페이로드엔 없다. 값이 올 때만 붙인다.
  const fiveHour = d.rate_limits?.five_hour?.used_percentage;
  const sevenDay = d.rate_limits?.seven_day?.used_percentage;
  if (fiveHour != null) parts.push(`5H: ${Math.round(fiveHour)}%`);
  if (sevenDay != null) parts.push(`7D: ${Math.round(sevenDay)}%`);

  process.stdout.write(parts.join(' | '));
});

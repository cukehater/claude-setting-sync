# claude-setting-sync

Claude Code 사용자 설정(`~/.claude`)을 여러 디바이스에서 공유하기 위한 레포.

## 추적 대상

`~/.claude` 는 1GB를 넘고 대부분이 세션 기록·플러그인 캐시·인증 토큰이다. 그래서 `.gitignore`는 **전부 무시(`/*`)한 뒤 아래 5개만 화이트리스트로 되살리는** 방식이다. Claude Code가 새 캐시 디렉터리를 만들어도 자동으로 걸러진다.

| 대상 | 내용 |
|---|---|
| `settings.json` | 모델·언어·테마, 활성 플러그인, marketplace 목록, statusLine |
| `CLAUDE.md` | 전역 행동 지침 |
| `statusline.js` | 상태줄 스크립트 (`settings.json`이 `$HOME` 기준으로 참조) |
| `skills/git-commit/` | 레포 관례에 맞춘 커밋 메시지 작성 |
| `skills/squash-commit-range/` | 연관된 인접 커밋 묶기 |

**플러그인은 파일로 동기화하지 않는다.** `settings.json`의 `enabledPlugins` + `extraKnownMarketplaces` 선언만 있으면 Claude Code가 marketplace에서 다시 clone한다. `plugins/installed_plugins.json`은 절대경로가 박혀 있어 오히려 해로우므로 제외.

`skills/synced/`(Anthropic이 계정에 푸시하는 스킬)도 제외 — 자동으로 다시 내려온다.

## 새 디바이스 세팅

기존 `~/.claude`를 지우지 않고 그 자리에 히스토리만 얹는다.

```bash
cd "$HOME/.claude"
git init -b main
git remote add origin https://github.com/cukehater/claude-setting-sync.git
git fetch origin
git checkout -f -t origin/main
```

추적 대상 5개만 덮어쓴다. 나머지는 `.gitignore` 대상이라 건드리지 않는다. 이후 Claude Code를 재시작하면 플러그인이 설치된다.

## 기기 전용 설정

`settings.local.json`은 `.gitignore` 대상이다. 특정 기기·특정 레포에서만 쓰는 설정(auto mode 환경 정보, 경로 기반 permission 등)은 여기에 둔다.

---
name: e2e-regression
description: git 변경 범위(또는 `all` 옵션으로 앱 전체)에 해당하는 화면의 사용자 동작을 playwright-cli로 직접 조작해 e2e 진단하고, 실패 동작·재현 단계·증거·원인 추정을 리포트하는 1회성 회귀테스트 명령. 테스트 파일은 남기지 않는다. `--baseline <ref>`로 이전 버전과 동작을 대조하고, `--prod`로 production 빌드를 검사하며, `--plan`으로 같은 시나리오를 재실행할 수 있어 라이브러리·프레임워크 마이그레이션(Next.js 메이저 업그레이드 등) 검증에도 쓴다. `--browsers`·`--devices`로 크로스 브라우징·모바일 기기 에뮬레이션 테스트도 한다. 사용자가 "크로스 브라우징", "사파리/파이어폭스에서 확인", "모바일에서 깨지는지", "기기 테스트", "e2e 돌려줘", "회귀테스트", "이번 변경으로 깨진 거 없나 확인", "화면 동작 테스트", "브라우저로 기능 확인", "QA 해줘", "전수검사", "업그레이드 후 동작 확인", "마이그레이션 검증", "/e2e-regression" 등을 말하면 반드시 이 스킬을 쓴다. 무엇을 테스트할지 지시하지 않아도 diff에서 대상을 스스로 찾아낸다. spec 파일 작성·CI 설정(@playwright/test)은 이 스킬 범위가 아니다.
argument-hint: "[all | <git 범위>] [--baseline <ref>] [--prod] [--plan <파일>] [--browsers <목록>] [--devices <목록>]"
---

# e2e-regression

변경 코드가 영향을 주는 화면의 **모든 사용자 동작**을 실제 브라우저로 조작해 깨진 곳을 보고한다. 사용자가 테스트 대상을 지시하지 않아도 되게 하는 게 목적이므로, 대상 선정부터 판정까지 스스로 끝낸다. 진행 중 묻는 건 "멈추고 묻는 경우"뿐이다.

결과물은 대화에 출력하는 리포트와 프로젝트 밖의 `plan.md`(4절)뿐이다. 테스트 코드·spec 파일을 만들지 않고, 프로젝트에 흔적을 남기지 않는다(원래 gitignore된 빌드 산출물 제외).

## 인자

범위(하나):

| 인자 | 범위 |
|---|---|
| (없음) | 기본 브랜치와의 merge-base 이후 커밋 + 커밋 안 된 변경(staged/unstaged/untracked) |
| `<브랜치>` / `<커밋>` | 그 지점 이후 ~ 현재 작업 트리 |
| `A..B` | 해당 커밋 범위만 |
| `all` | diff 무시, 모든 라우트 전수검사 |

기본 브랜치: `git symbolic-ref --short refs/remotes/origin/HEAD` (없으면 `main`, 그다음 `master`).

옵션(조합 가능):

| 옵션 | 동작 |
|---|---|
| `--baseline <ref>` | 이전 ref와 같은 시나리오로 대조 (6절) |
| `--prod` | production 빌드 서버로 검사 (2절) |
| `--plan <파일>` | 이전 `plan.md` 재실행 (4절) |
| `--browsers <목록>` | 크로스 브라우징. 예: `chromium,firefox,webkit` (7절) |
| `--devices <목록>` | 기기 에뮬레이션. 예: `"iPhone 15,Pixel 7"` (7절) |

**마이그레이션 감지 시**(핵심 의존성 메이저 변경, 1절): 옵션이 없어도 계획 출력에 "마이그레이션: `--baseline <변경 전 ref> --prod` 권장"을 적고, 리포트에서 기대 동작 추론에 기댄 판정은 baseline 대조 전까지 잠정이라고 명시한다. 마이그레이션의 질문은 "이전과 똑같이 동작하나"인데, 추론한 기대 동작으로는 회귀와 원래 동작을 가를 수 없다.

## 1. 대상 화면 선정

`--plan`이 있으면 건너뛴다.

### diff 모드

1. `git diff --name-only <base>` + `git ls-files --others --exclude-standard`로 변경 파일 수집. 테스트·문서 등 런타임 무관 파일은 제외하되, 영향이 넓은 공용 설정(라우터, 전역 스타일, API 클라이언트, 상태 store, 미들웨어, 프레임워크 설정)은 포함.
2. 변경 파일을 import하는 곳을 grep으로 **위로 추적**해 라우트 진입점까지 도달. 라우트 정의는 실제 구조를 보고 판단(Next.js `app/**/page.*`·`pages/**`, React Router 설정, Vue Router `routes`, SvelteKit `routes/**/+page.*`, Nuxt `pages/**` 등).
3. `git diff <base> -- <file>`로 바뀐 내용을 읽는다. 바뀐 핸들러·조건부 렌더링·폼 검증·API 호출이 집중 검증 대상.
4. 공용 컴포넌트처럼 영향 화면이 많으면 전부 포함하되, 화면마다 그 컴포넌트 사용 지점을 우선 검증.

### 의존성 변경

`package.json`·lockfile 변경은 소스 diff 없이도 동작을 바꾼다:

1. `git diff <base> -- package.json`으로 버전이 바뀐(추가·제거 포함) 패키지를 뽑는다. lockfile만 바뀌었으면 주요 패키지의 해석 버전을 비교.
2. 각 패키지를 import하는 파일을 grep → 위 방식으로 화면까지 추적.
3. 프레임워크·런타임·라우터·상태관리·UI 키트(react, next, vue, nuxt, svelte, react-router, 디자인 시스템 등)가 **메이저** 변경이면 `all` 모드로 전환하고 계획에 이유를 적는다.
4. 3절 정적 검사를 반드시 실행.

### all 모드

라우트 정의를 전부 수집해 화면 목록을 만든다. 동적 라우트(`/items/[id]`)는 목록에서 실제 항목을 클릭해 진입한다(id를 추측하면 404를 버그로 오판한다). 화면이 많으면 핵심 흐름(인증·주요 CRUD·결제/제출) 먼저, 정적 페이지는 뒤로.

### 계획 출력

짧게 출력하고 **승인을 기다리지 않고** 진행:

```
대상: 4개 화면 (diff: main...HEAD + 작업 트리, 변경 파일 7개, 의존성 변경 2개)
- /cart        ← src/features/cart/CartItem.tsx (수량 변경 로직)
- /checkout    ← src/features/cart/useCart.ts
...
모드: dev · baseline 없음
```

## 2. 환경 준비

1. **패키지 매니저**: lockfile로 판단(`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock*` → bun, 그 외 npm). `node_modules`가 없거나 lockfile보다 오래됐으면 install. 출력의 peer 의존성 경고는 정적 검사용으로 기록.
2. **playwright-cli**: `playwright-cli --version` 실패 시 `npm i -g @playwright/cli@latest`(1회성 진단이라 프로젝트 package.json은 건드리지 않는다). 브라우저 실행 실패 시 `playwright-cli install-browser`.
3. **실행 폴더**: playwright-cli는 현재 디렉터리의 `.playwright-cli/`에 파일을 쓴다. `RUN_DIR=$(mktemp -d)`를 만들고 **모든 playwright-cli 명령을 `cd "$RUN_DIR" && playwright-cli ...`로** 실행한다. 경로 인자(업로드 파일 등)는 절대경로.
4. **서버**:
   - dev(기본): package.json의 `dev`(없으면 `start`/`serve`) 스크립트와 포트 확인. 포트가 이미 응답하면 그대로 쓰고, 아니면 백그라운드로 띄워 응답할 때까지 대기.
   - `--prod`: `build` 후 production 서버 실행. Next.js는 `next start`, `output: 'standalone'`이면 `node .next/standalone/server.js`(`.next/static`·`public`을 standalone 폴더로 복사해야 정적 자원이 뜬다), Vite 계열은 `preview`. `NODE_ENV=production`·`.env.production*` 로딩이 dev와 다르다. 업그레이드 위험(번들러 해석 실패, 이미지 최적화·캐시 기본값, 환경변수 로딩)은 production 쪽에 몰려 있다. **빌드 실패는 최우선 실패 항목** — 에러 원문과 원인 추정을 리포트하고, 서버를 띄울 수 없으면 브라우저 진단 없이 종료.
   - 서버 로그의 컴파일 에러·경고는 브라우저 진단 전에 확인. 종료는 **직접 띄운 서버만**.
5. **로그인**: 인증이 필요하면 `.env*`, `README`, seed 스크립트에서 테스트 계정(`E2E_`, `TEST_USER`, `SEED_` 등)을 찾아 로그인 화면으로 한 번 로그인하고 `state-save "$RUN_DIR/auth.json"`. 세션이 끊기면 `state-load`.

## 3. 진단 실행

### 정적 검사 (의존성 변경·`--prod`·`all`일 때)

브라우저로 안 보이는 변경을 먼저 거른다. package.json에 있는 스크립트만 쓰고 없으면 건너뛴다:

- 타입체크(`typecheck` 스크립트, 없고 TS면 `tsc --noEmit`), `lint` 스크립트
- peer 의존성 경고(install 출력 또는 `npm ls`의 invalid/unmet)
- 런타임 버전: package.json `engines`, `.nvmrc`/`.node-version`, `Dockerfile`의 `FROM node:`가 새 의존성 요구 버전과 맞는지

결과는 리포트 "빌드·정적 검사" 절에 적고, 실패해도 브라우저 진단은 계속한다.

### 화면별 진단

시작 전 `set-reduced-motion reduce`로 애니메이션 타이밍 오판을 줄인다. 화면마다:

1. `goto` → `snapshot`으로 인터랙티브 요소 전수 파악(버튼, 링크, 입력, 셀렉트, 체크박스, 탭, 모달 트리거, 드롭다운 등).
2. **모든 동작을 시나리오로 수행**하고, 수행하는 대로 `plan.md`에 기록. 깊이는 diff 관련도로 조절:
   - 변경된 동작: 정상 흐름 + 경계값(빈 값, 최대 길이, 잘못된 형식) + 오류 흐름(검증 메시지, 실패 응답 UI) + 상태 전이(로딩 → 완료, 활성/비활성).
   - 같은 화면의 나머지 동작: 정상 흐름 1회. 회귀는 대개 안 건드린 줄 알았던 옆 기능에서 난다.
   - 파일 업로드: 파일이 없다고 건너뛰지 않는다. 프로젝트 fixture가 있으면 우선 쓰고, 없으면 코드(`accept` 속성, 검증 로직, 서버 설정)에서 허용 확장자·용량·개수 제한을 찾아 `$RUN_DIR/fixtures/`에 만든다:
     - 허용 파일: 이미지면 진짜 PNG(1x1 PNG를 base64 디코딩), 문서면 작은 txt/pdf
     - 금지 확장자 파일(예: `.exe`, `.sh`)
     - 용량 초과 파일: `node -e "require('fs').writeFileSync(process.argv[1], Buffer.alloc(N))" <경로>` (N = 제한 + 1KB)
     - 개수 제한 + 1개 분량의 허용 파일
     - 제한값을 못 찾으면 허용 파일만 검증하고 제한 검증은 "미실행(제한값 불명)".
3. **판정은 관찰 가능한 결과로**: `snapshot`/`find`로 기대한 변화(텍스트, 목록 개수, URL, 요소 상태)를 확인. 에러 없이 클릭됐다는 것만으로는 통과가 아니다.
4. 동작마다 `console`·`requests` 확인. 콘솔 error, 4xx/5xx, 끝나지 않는 요청은 화면이 멀쩡해 보여도 실패 또는 경고. 의존성 변경이 있으면 console **warning**도 수집(마이그레이션 문제는 deprecation 경고로 먼저 드러난다).
5. **스스로 변하는 UI**(자동 슬라이드, 토스트, 폴링, 카운트다운)는 임의 시점 스냅샷 한 장으로 판정하지 않는다. hover·포커스로 멈추거나, 상태 전이 뒤 값을 보거나, 간격을 두고 두 번 스냅샷한다. 이런 요소가 걸린 실패는 판정 전 반드시 재확인.
6. **실패 처리**: 한 번 재시도해 재현 확인. 재현되면 `screenshot --filename="$RUN_DIR/<화면>-<동작>.png"`와 관련 콘솔/네트워크 응답 본문을 증거로 남기고, diff에서 의심 위치(`file:line`)와 이유를 추정. 코드는 수정하지 않는다.
7. 의도된 변경인지 버그인지 애매하면(문구 변경, 레이아웃 이동 등) "확인 필요"로 분류. `--baseline`이 있으면 대조로 확정.

### 브라우저 밖 검사

- **HTTP**: 미들웨어·리다이렉트·인증·i18n 라우팅이 범위에 들면 `curl -s -o /dev/null -D - <url>`로 상태 코드·`Location`·`Set-Cookie`를 기록한다. 브라우저는 리다이렉트를 따라가서 307→308 같은 변화를 놓친다.
- **API 모킹**: 브라우저 요청은 `playwright-cli route "<패턴>" --status ... --body ...`로 응답을 바꿔 오류·빈 데이터·조건 분기를 검증. 서버 측 분기(SSR fetch, 미들웨어의 국가·언어 판정 등)는 route로 못 바꾸므로, 코드가 읽는 요청 헤더(geo 헤더, `Accept-Language` 등)를 찾아 `curl -H`로 재현하고, 안 되면 "미실행(서버 측 모킹 불가)".

### 멈추고 묻는 경우

- 테스트 계정을 찾을 수 없음
- 되돌릴 수 없는 부작용(실제 결제, 외부 메일·SMS 발송, 공유/운영 DB 삭제): API가 localhost/mock/테스트 환경으로 향하는지 확인하고, 아니면 건너뛰어 "미실행(부작용)"으로 남기거나 묻는다. 로컬 DB의 생성·수정·삭제는 진행.

## 4. 시나리오 파일 (plan.md)

실제 수행한 시나리오를 `$RUN_DIR/plan.md`에 기록한다. 같은 기준으로 재실행(수정 후 재검증, 다른 앱에 적용)하고 baseline에서 같은 절차를 밟기 위해서다 — 매번 새로 짜면 범위와 판정이 달라진다.

- 대상은 실행마다 바뀌는 ref(e12 등)가 아니라 역할·라벨·텍스트로 적는다.
- 태그: `[변경]` diff와 직접 관련, `[핵심]` 인증·주요 CRUD·결제/제출, 나머지는 없음. 환경 매트릭스가 이 태그로 범위를 고른다.

```markdown
# plan · <앱 이름> · <범위/모드>
## /cart
- [S1][변경] 수량 증가: "+" 버튼(CartItem 첫 행) 클릭 → 기대: 수량 2, 합계 갱신
- [S2] 빈 장바구니: 모든 항목 "삭제" → 기대: "장바구니가 비었습니다" 표시
## HTTP
- [H1] GET /old-path → 기대: 308, Location: /new-path
```

`--plan <파일>`이면 그 시나리오를 **추가·삭제 없이** 수행한다. 화면 구조가 바뀌어 대상을 못 찾으면 실패가 아니라 "시나리오 불일치". 리포트에 plan.md 경로를 적는다(임시 폴더라 OS가 지울 수 있으니 보관은 사용자 몫).

## 5. 정리

`playwright-cli close-all`, 직접 띄운 서버 종료, baseline worktree 제거. `$RUN_DIR`은 증거로 남긴다. `git status`로 프로젝트에 생긴 파일이 없는지 확인.

## 6. --baseline

이 옵션이 있을 때만 `references/baseline.md`를 읽고 따른다.

## 7. --browsers / --devices

둘 중 하나라도 있을 때만 `references/matrix.md`를 읽고 따른다.

## 8. 리포트

대화에 아래 형식으로 출력. `--baseline`이 없으면 baseline 관찰값과 "의도된 변경" 절을 빼고, 환경 매트릭스를 돌렸으면 `references/matrix.md`의 매트릭스 요약을 통과 표 아래에 붙인다:

```markdown
# e2e 회귀 진단 결과

범위: <diff 범위 또는 all> · 모드: <dev | prod> · baseline: <ref 또는 없음> · 환경: <기준 환경만 | 목록>
화면 N개 · 동작 M개
결과: ✅ 통과 a · ❌ 실패 b · ⚠️ 확인 필요 c · ⏭️ 미실행 d
증거 폴더: <RUN_DIR 절대경로> · 시나리오: <plan.md 절대경로>

## 🧱 빌드·정적 검사
- build: ✅ / ❌ <에러 요약>
- typecheck ✅ · lint ⚠️ 경고 3 · peer 의존성 ❌ <패키지> · Node 버전 ✅

## ❌ 실패
### 1. <화면> — <동작>
- 재현: 1) … 2) … 3) …
- 기대: … (baseline: <baseline 관찰값>)
- 실제: …
- 증거: <스크린샷 경로>, 콘솔 `…`, `POST /api/… 500`
- 원인 추정: `src/…/file.tsx:42` — <근거>

## ⚠️ 확인 필요
- <화면> — <내용> (의도된 변경인지 확인)

## 🔄 의도된 변경 (baseline과 다름, diff로 확인)
- <화면> — <변화> ← `file:line`

## ⏭️ 미실행
- <화면> — <동작>: <이유>

## ✅ 통과
| 화면 | 검증한 동작 |
|---|---|
| /cart | 수량 증감, 삭제, 빈 장바구니 표시, 결제 이동 |
```

실패를 먼저, 통과는 표로 압축. 검증하지 **않은** 것을 숨기지 않는다 — 통과 목록만 보면 커버리지를 과신해 회귀를 놓친다.

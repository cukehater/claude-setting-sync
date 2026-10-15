---
name: git-commit
description: Stage all changes and write a commit message in the current repo's actual convention (type(scope): subject, single line, no body — verified against `git log` each time). Use whenever the user asks to commit, "커밋해줘", "커밋 메시지 작성해줘", "변경사항 커밋", or wants staged/unstaged changes turned into a commit — don't invent a generic Conventional Commits message, derive it from this repo's history per the rules below.
---

# git-commit

## 커밋 전 확인

1. `git status`로 스테이징 안 된 파일, untracked 파일 확인.
2. `git diff` / `git diff --staged`로 실제 변경 내용 파악 (타입·스코프 판단 근거).
3. 의심스러운 파일(.env, credentials, key 등) 있으면 스테이징 전에 내용 확인하고 사용자에게 경고.
4. 전부 의도된 변경이면 `git add -A` (아니면 관련 파일만 개별 add).

## 메시지 규칙

**먼저 `git log --oneline -20`으로 현재 레포의 실제 관례를 직접 확인한다.** 아래는 기본값이고, 레포 히스토리가 다르면 히스토리를 따른다.

포맷: `type(scope): 설명` 또는 스코프 없으면 `type: 설명`

- **type**: `feat` `fix` `chore` `refactor` 중 하나. 새 기능=feat, 버그 수정=fix, 포맷팅/설정/제거 등 코드 동작과 무관=chore, 동작 유지한 채 구조 변경=refactor. 레포가 다른 type(docs, test, style 등)을 쓰고 있으면 그걸 따른다.
- **scope**: 히스토리에 실제로 나타나는 분류를 쓴다 — 그 레포가 디렉터리명을 쓰는지, 패키지명을 쓰는지, 모듈·기능명을 쓰는지 로그를 보고 판단한다. 변경이 그 한 곳에만 국한될 때만 스코프를 단다. 여러 곳에 걸치거나 레포 전역 변경(gitignore, 포매터 설정 등)이면 스코프 생략. 히스토리에 스코프가 아예 없는 레포면 쓰지 않는다.
- **설명**: 히스토리의 지배 언어를 따른다(한국어 레포는 한국어, 영어 레포는 영어). 한국어면 명사형 종결("~추가", "~처리", "~수정"), 마침표 없이 한 줄.
- **body/footer**: 히스토리에 본문이 없으면 추가하지 마라. 한 줄로 끝낸다.
- **히스토리가 없는 새 레포**: 커밋이 없거나 너무 적어 관례를 읽을 수 없으면 `type: 설명` 형태의 영어 Conventional Commits를 기본값으로 쓰고, 어떤 관례로 갈지 사용자에게 한 번 확인한다.

형태별 예시 — 특정 레포의 로그가 아니라 패턴 샘플이다. 어느 쪽을 쓸지는 항상 그 레포 히스토리가 정한다:
```
스코프 있는 한국어 레포:   feat(auth): 소셜 로그인 연동 추가
스코프 없는 한국어 레포:   fix: 목록 페이지 무한 스크롤 중복 호출 수정
스코프 있는 영어 레포:     refactor(api): extract pagination helper
스코프 없는 영어 레포:     chore: bump eslint to v9
```

## 실행

1. 위 규칙으로 메시지 작성.
2. `git commit -m "type(scope): 설명"` — heredoc이나 footer 없이 한 줄 메시지 그대로.
3. `git status`로 커밋 성공 확인.
4. hook 실패 시 원인 고치고 새로 커밋 (amend 금지, 레포 정책과 무관하게 항상 지킬 것).

여러 논리적 변경이 섞여 있으면(예: 기능 추가 + 무관한 설정 변경) 사용자에게 분리 커밋할지 먼저 확인 — 커밋 하나 = 변경 하나 원칙.

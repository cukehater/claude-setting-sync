#!/usr/bin/env bash
# 합치기 결과가 원본과 완전히 같은지 기계적으로 검증한다. 하나라도 어긋나면 0이 아닌 코드로 죽는다.
#
# 사용법: verify-squash.sh <ORIG> <BACKUP> [<새커밋>:<그룹의LAST> ...]
#
#   ORIG    합치기 직전의 HEAD
#   BACKUP  실행 전 만든 백업 브랜치 이름
#   쌍      새로 만든 커밋과, 그 커밋이 대체한 원본 그룹의 마지막 커밋
#
# 비교는 `git diff`가 아니라 **트리 해시**로 한다. 트리 SHA는 모든 경로·파일 모드·
# blob 내용에 대한 Merkle 해시라, 같으면 바이트 단위로 같다는 뜻이다. diff와 달리
# 사용자의 diff 관련 git 설정에 영향받지 않고, 무엇보다 종료 코드로 판정할 수 있다.
# (`git diff`는 차이가 있어도 기본 종료 코드가 0이라 자동 판정에 못 쓴다.)
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <ORIG> <BACKUP> [<new>:<last> ...]" >&2
  exit 2
fi

ORIG="$1"; shift
BACKUP="$1"; shift

fail=0
ok()   { printf 'OK   %s\n' "$1"; }
bad()  { printf 'FAIL %s\n' "$1" >&2; fail=1; }

tree_of() { git rev-parse --verify --quiet "$1^{tree}"; }

# 1) 백업이 실제로 살아 있는가.
#    복구 명령이 `git reset --hard $BACKUP`인데 백업이 없으면 안전장치가 없는 것과 같다.
if git rev-parse --verify --quiet "${BACKUP}^{commit}" >/dev/null; then
  ok "백업 브랜치 생존: $BACKUP -> $(git rev-parse --short "$BACKUP")"
else
  bad "백업 브랜치 '$BACKUP'을 찾을 수 없다. 복구 지점이 없는 상태다."
fi

# 2) 백업이 정말 ORIG를 가리키는가. 엉뚱한 커밋을 백업해 뒀으면 복구가 원본으로 안 돌아간다.
if [ "$(git rev-parse --verify --quiet "${BACKUP}^{commit}")" = "$(git rev-parse --verify --quiet "${ORIG}^{commit}")" ]; then
  ok "백업이 ORIG를 가리킨다"
else
  bad "백업이 ORIG와 다른 커밋을 가리킨다 (backup=$(git rev-parse --short "$BACKUP" 2>/dev/null), orig=$(git rev-parse --short "$ORIG"))"
fi

# 3) 최종 스냅샷이 원본과 동일한가. 이게 "코드가 한 글자도 안 변했다"의 본체다.
t_orig=$(tree_of "$ORIG"); t_head=$(tree_of HEAD)
if [ -n "$t_orig" ] && [ "$t_orig" = "$t_head" ]; then
  ok "최종 트리 동일: $t_head"
else
  bad "최종 트리가 다르다 (orig=$t_orig head=$t_head)"
fi

# 4) 그룹 경계마다 스냅샷이 원본과 동일한가.
#    최종만 같고 중간이 어긋나면 히스토리의 각 시점이 거짓말을 하게 된다.
for pair in "$@"; do
  new="${pair%%:*}"; last="${pair##*:}"
  t_new=$(tree_of "$new"); t_last=$(tree_of "$last")
  label="경계 $(git rev-parse --short "$new" 2>/dev/null) == 원본 $(git rev-parse --short "$last" 2>/dev/null)"
  if [ -n "$t_new" ] && [ "$t_new" = "$t_last" ]; then
    ok "$label"
  else
    bad "$label (new=$t_new last=$t_last)"
  fi
done

# 5) 워킹트리가 깨끗한가. 합치기 도중 뭔가 흘렸으면 여기서 드러난다.
if [ -z "$(git status --porcelain)" ]; then
  ok "워킹트리 clean"
else
  bad "워킹트리에 커밋되지 않은 변경이 남아 있다"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "검증 통과: 커밋 개수만 바뀌었고 내용은 원본과 완전히 같다."
  exit 0
fi

cat >&2 <<EOF

검증 실패. 추측해서 고치지 말고 즉시 되돌려라:

  git reset --hard $BACKUP

백업까지 없다고 나왔다면 reflog에서 원본을 찾아 브랜치로 고정해라:

  git reflog
  git branch squash-backup-recovered $ORIG
EOF
exit 1

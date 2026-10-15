#!/usr/bin/env bash
# 지정한 범위의 커밋을 "파일이 겹치는 인접 커밋"끼리 묶어 그룹을 출력한다.
#
# 사용법: group-commits.sh <base>..<head>   또는   group-commits.sh <base> <head>
#
# 그룹은 인접한 커밋만 묶는다(순서 재배치 없음). 오래된 것부터 훑으면서,
# 다음 커밋이 건드린 파일이 지금 그룹이 모아 온 파일 집합과 하나라도 겹치면 같은 그룹,
# 하나도 안 겹치면 거기서 그룹을 끊는다. 겹침은 전이적이다:
# c1(A) c2(A,B) c3(B)는 c1과 c3이 직접 안 겹쳐도 한 그룹이 된다.
#
# 출력 형식(그룹당 한 블록, 탭 구분):
#   GROUP<번호>
#   COMMIT<TAB><짧은SHA><TAB><제목>
#   ...
#   LAST<TAB><그룹 마지막 커밋의 전체SHA>
#   FILES<TAB><그룹이 건드린 파일 목록(공백 구분)>
set -euo pipefail

if [ $# -eq 1 ]; then
  RANGE="$1"
elif [ $# -eq 2 ]; then
  RANGE="$1..$2"
else
  echo "usage: $0 <base>..<head> | <base> <head>" >&2
  exit 2
fi

# 머지 커밋이 끼면 ladder 방식이 병합 구조를 조용히 평탄화한다. 미리 막는다.
MERGES=$(git rev-list --merges "$RANGE")
if [ -n "$MERGES" ]; then
  echo "ERROR: 범위에 머지 커밋이 있어 안전하게 합칠 수 없다:" >&2
  echo "$MERGES" >&2
  exit 3
fi

COMMITS=$(git rev-list --reverse "$RANGE")
if [ -z "$COMMITS" ]; then
  echo "ERROR: 범위 '$RANGE'에 커밋이 없다." >&2
  exit 4
fi

group_idx=0
group_files=""
group_lines=""
group_last=""

flush() {
  [ -z "$group_last" ] && return 0
  echo "GROUP${group_idx}"
  printf '%s' "$group_lines"
  printf 'LAST\t%s\n' "$group_last"
  printf 'FILES\t%s\n' "$(printf '%s' "$group_files" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
  echo
}

for sha in $COMMITS; do
  files=$(git show --pretty=format: --name-only "$sha" | grep -v '^$' | sort -u)
  subject=$(git log -1 --format='%s' "$sha")
  short=$(git rev-parse --short "$sha")

  overlap=0
  if [ -n "$group_files" ]; then
    flat=" $(printf '%s' "$group_files" | tr '\n' ' ') "
    for f in $files; do
      case "$flat" in *" $f "*) overlap=1; break;; esac
    done
  fi

  if [ -z "$group_last" ]; then
    group_idx=1
  elif [ "$overlap" -eq 0 ]; then
    flush
    group_idx=$((group_idx + 1))
    group_files=""
    group_lines=""
  fi

  group_files=$(printf '%s\n%s' "$group_files" "$files" | grep -v '^$' | sort -u)
  group_lines="${group_lines}$(printf 'COMMIT\t%s\t%s' "$short" "$subject")
"
  group_last="$sha"
done

flush

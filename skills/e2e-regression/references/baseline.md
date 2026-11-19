# --baseline 대조

이전 ref와 현재를 같은 시나리오로 돌려 "이전과 똑같이 동작하나"를 확정한다.

1. `git worktree add "$RUN_DIR/baseline" <ref>` (프로젝트 밖). gitignore된 `.env*`를 worktree로 복사한다(없으면 다른 설정으로 떠서 대조가 무의미). worktree에서 의존성 install.
2. baseline 서버를 **다른 포트**로 띄운다. `--prod`면 baseline도 같은 방식으로 빌드·실행(모드가 다르면 비교 불가). 로그인 상태는 baseline에서 따로 만든다.
3. 세션을 나눈다: `playwright-cli -s=head ...`, `playwright-cli -s=base ...`. 같은 plan.md를 양쪽에서 같은 순서로 수행하고 관찰값(텍스트, URL, 요소 상태, 콘솔, 요청 상태 코드, HTTP 헤더)을 나란히 기록.
4. 판정:
   - 동일 → 통과. 이상해 보여도 이전부터 그랬으면 회귀가 아니다("기존 동작"으로 언급만).
   - 다름 + diff에서 의도 확인 → 의도된 변경
   - 다름 + 의도 근거 없음 → **회귀(실패)**
   - baseline에서도 실패 → 기존 결함(회귀 아님)
5. `--browsers`/`--devices`와 함께면 baseline 대조는 **기준 환경에서만**(곱으로 늘어나는 실행량 방지, 환경별 차이는 matrix 대조가 잡는다).
6. 끝나면 baseline 서버 종료 후 `git worktree remove --force "$RUN_DIR/baseline"`.

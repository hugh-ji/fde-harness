# fde-harness — AI 협업 작업 체계 템플릿

실무자 문제를 AI 코딩 에이전트(Codex 등)와 함께 해결할 때 쓰는 **절차 템플릿**입니다. 과제별 코드는 포함하지 않으며, 문제 정의 → 합의 → 계획 → 구현 → 검증 → 인수인계의 흐름과 품질 규칙만 담습니다.

## 구성
```
AGENTS.md                      에이전트 작업 규칙(자동 로드)
PROMPTS.md                     단계별 프롬프트 36개(P 번호)
setup.sh                       세팅 스크립트(복사·git init·커밋)
templates/AGREEMENT.md         실무자 합의문 양식
templates/PLAN.md              마일스톤 계획 양식
templates/DECISIONS.md         결정 로그 양식
templates/HANDOFF.md           인수인계 양식
templates/CHECKLIST.md         180분 타임라인·판단 기준
.agents/skills/fde-interview   실무자 인터뷰 스킬
.agents/skills/verify-before-done  완료 전 검증 스킬
.agents/skills/handoff         인수인계 문서 스킬
```

## 사용
작업 폴더에서 한 줄. Codex에게 "이 저장소를 clone하고 setup.sh를 실행해"라고 시켜도 된다.
```bash
git clone https://github.com/hugh-ji/fde-harness.git && sh fde-harness/setup.sh
```
setup.sh가 하는 일: AGENTS.md·PROMPTS.md·templates/*.md·.agents/를 작업 폴더로 복사 → clone 폴더 삭제 → .gitignore → git init → '세팅' 커밋. 작업 폴더의 README.md, docs/, data/는 건드리지 않는다.
그 다음 **Codex를 다시 실행**한다. AGENTS.md는 Codex가 시작할 때 읽는다.

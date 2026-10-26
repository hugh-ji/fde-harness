# fde-harness — AI 협업 작업 체계 템플릿

실무자 문제를 AI 코딩 에이전트(Codex 등)와 함께 해결할 때 쓰는 **절차 템플릿**입니다. 과제별 코드는 포함하지 않으며, 문제 정의 → 합의 → 계획 → 구현 → 검증 → 인수인계의 흐름과 품질 규칙만 담습니다.

## 구성
```
AGENTS.md                      에이전트 작업 규칙(자동 로드)
templates/AGREEMENT.md         실무자 합의문 양식
templates/PLAN.md              마일스톤 계획 양식
templates/DECISIONS.md         결정 로그 양식
templates/HANDOFF.md           인수인계 양식
templates/CHECKLIST.md         단계별 체크리스트
.agents/skills/fde-interview   실무자 인터뷰 스킬
.agents/skills/verify-before-done  완료 전 검증 스킬
.agents/skills/handoff         인수인계 문서 스킬
```

## 사용
```bash
git clone https://github.com/hugh-ji/fde-harness.git kit
cp kit/AGENTS.md . && cp -r kit/.agents . && cp kit/templates/*.md .
rm -rf kit
```

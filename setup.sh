#!/bin/sh
# 하네스 세팅 스크립트. 작업 폴더에서 다음 한 줄로 실행한다 (Codex에게 시켜도 된다):
#   git clone https://github.com/hugh-ji/fde-harness.git && sh fde-harness/setup.sh
# 하는 일: 이 저장소의 하네스 파일을 작업 폴더(상위 폴더)로 복사 → clone 폴더 삭제 → git init(상위에 git이 있으면 재사용) → '작업환경 설정' 커밋.
# 작업 폴더의 README.md, docs/, data/는 건드리지 않는다. 이 저장소의 README.md도 복사하지 않는다.
set -e
KIT="$(cd "$(dirname "$0")" && pwd)"
WS="$(dirname "$KIT")"
cd "$WS"

if [ ! -f README.md ] && [ -f ../README.md ]; then
  echo "참고: 과제 README.md는 한 단계 위($(cd .. && pwd))에 있고 제출 폴더는 여기($WS)다. 에이전트에게 ../README.md, ../data 경로를 알려준다."
elif [ ! -f README.md ]; then
  echo "주의: 이 폴더($WS)에도 한 단계 위에도 README.md가 없다. 과제 폴더가 맞는지 확인한다."
fi

cp "$KIT/AGENTS.md" "$KIT/PROMPTS.md" .
cp "$KIT"/templates/*.md .
[ -d "$KIT/.agents" ] && cp -R "$KIT/.agents" .
rm -rf "$KIT"

if [ ! -f .gitignore ]; then
  printf '__pycache__/\n.pytest_cache/\n*.pyc\n.DS_Store\n' > .gitignore
fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || git init -q
git add -A
git -c user.name=fde -c user.email=fde@example.com commit -q -m "작업환경 설정" || true

echo "세팅 완료. 작업 폴더에 들어온 파일:"
echo "  AGENTS.md PROMPTS.md CHECKLIST.md AGREEMENT.md PLAN.md DECISIONS.md HANDOFF.md SCREEN_CHECK.md .agents/ .gitignore"
echo "다음: Codex를 종료하고 다시 실행한다. AGENTS.md는 Codex가 시작할 때 읽는다."

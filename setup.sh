#!/bin/sh
# 하네스 세팅 스크립트. 작업 폴더에서 다음 한 줄로 실행한다 (Codex에게 시켜도 된다):
#   git clone https://github.com/hugh-ji/fde-harness.git && sh fde-harness/setup.sh
# 하는 일: 이 저장소의 하네스 파일을 작업 폴더(상위 폴더)로 복사 → clone 폴더 삭제 → git init → '세팅' 커밋.
# 작업 폴더의 README.md, docs/, data/는 건드리지 않는다. 이 저장소의 README.md도 복사하지 않는다.
set -e
KIT="$(cd "$(dirname "$0")" && pwd)"
WS="$(dirname "$KIT")"
cd "$WS"

cp "$KIT/AGENTS.md" "$KIT/PROMPTS.md" .
cp "$KIT"/templates/*.md .
[ -d "$KIT/.agents" ] && cp -R "$KIT/.agents" .
rm -rf "$KIT"

if [ ! -f .gitignore ]; then
  printf '__pycache__/\n.pytest_cache/\n*.pyc\n.DS_Store\n' > .gitignore
fi
[ -d .git ] || git init -q
git add -A
git -c user.name=fde -c user.email=fde@example.com commit -q -m "세팅" || true

echo "세팅 완료. 작업 폴더에 들어온 파일:"
echo "  AGENTS.md PROMPTS.md CHECKLIST.md AGREEMENT.md PLAN.md DECISIONS.md HANDOFF.md .agents/ .gitignore"
echo "다음: Codex를 종료하고 다시 실행한다. AGENTS.md는 Codex가 시작할 때 읽는다."

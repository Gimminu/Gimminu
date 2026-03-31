# Repo Publish Workflow

이 문서는 새 프로젝트를 만들 때 로컬 폴더와 GitHub 저장소를 바로 연결하는 기본 흐름이다.

## 목표

새 프로젝트를 시작할 때마다 아래를 자동으로 맞춘다.

- `.gitignore`
- `README.md`
- `.env.example`
- Git 초기화
- 첫 커밋
- GitHub 저장소 생성과 push

## 준비

### 1. GitHub CLI 인증

현재처럼 `gh auth status` 가 실패하면 먼저 인증을 복구해야 한다.

```bash
gh auth login -h github.com
```

## 기본 사용법

프로필 repo 안의 스크립트를 실행한다.

```bash
cd /Users/giminu0930/Desktop/Gimminu-profile
./scripts/bootstrap_repo.sh \
  --path /Users/giminu0930/Desktop/mail-mcp-agent \
  --stack node \
  --description "Local IMAP mail agent with MCP tools" \
  --create-github
```

Python 프로젝트 예시:

```bash
cd /Users/giminu0930/Desktop/Gimminu-profile
./scripts/bootstrap_repo.sh \
  --path /Users/giminu0930/Desktop/01_Projects/openai-realtime-transcribe \
  --stack python \
  --description "macOS-first realtime transcription workflow"
```

## 권장 스택 값

- `python`
- `node`
- `hybrid`
- `android`
- `generic`

## 이 흐름이 하는 일

1. 대상 폴더가 없으면 생성
2. `.gitignore` 가 없으면 생성
3. `README.md` 가 없으면 기본 템플릿 생성
4. `.env` 가 있고 `.env.example` 가 없으면 키 이름만 추출해서 예시 파일 생성
5. Git 저장소가 없으면 `main` 브랜치로 초기화
6. 변경사항을 스테이징하고 첫 커밋 생성
7. `--create-github` 옵션이 있고 `gh` 인증이 살아 있으면 GitHub 저장소 생성 + push

## 추천 운영 방식

### 로컬에서 새 프로젝트를 만들 때

- 먼저 프로젝트 폴더를 만든다
- 핵심 파일 몇 개를 넣는다
- 바로 `bootstrap_repo.sh` 를 실행한다

### 공개 가치가 있는 프로젝트일 때

- `--create-github` 를 같이 붙인다
- 이후 GitHub에서 pin 후보인지 판단한다

### 프로필에 반영할 때

새 공개 repo가 아래 기준을 만족하면 pin 또는 README 업데이트 후보로 본다.

- README가 명확하다
- 문제 정의가 보인다
- 설치/실행 방법이 있다
- `.env.example` 과 `.gitignore` 가 있다

## 현재 추천 pin 순서

1. `groq-local-project-onboarding-agent`
2. `capstone-design`
3. `AmazoCart`
4. `mail-mcp-agent` 공개 후 교체
5. `openai-realtime-transcribe` 공개 후 교체

## 운영 팁

- `.env` 는 절대 push 하지 않는다
- README 첫 문단은 "무엇을 해결하는지" 한 줄로 쓴다
- 공개할 repo는 용량 큰 산출물과 캐시를 먼저 걷어낸다
- README와 이력서의 프로젝트 설명은 같은 메시지를 유지한다

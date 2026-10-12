# 로컬 환경 설정 체크리스트

> 이 연결은 사용자 PC에서 해요. 아래 항목 중 `(확인 필요)`는 공식 문서와 맞춰 봐야 해요.

## 1. 설치
- [ ] Unity Hub + 에디터 설치 (버전은 AI Assistant 패키지 문서 기준, 확인 필요)
- [ ] 3D 프로젝트 생성: `fishing-game-unity`
- [ ] Blender 5.1 이상 설치
- [ ] 클로드 코드 (PC) 설치

## 2. 저장소 가져오기
- [ ] 브랜치 `claude/quirky-franklin-azysrm`의 `fishing-game/` 폴더를 PC로 가져오기
- [ ] 클로드 코드를 `fishing-game/` 폴더에서 실행 (CLAUDE.md가 자동으로 읽혀요)

## 3. MCP 연결
- [ ] 유니티: AI Assistant 패키지 설치 → `Project Settings > AI > Unity MCP`에서 켜기 → 클로드 코드 연결 승인 1회 (확인 필요)
- [ ] 블렌더: Blender Lab 공식 MCP 서버 연결 (확인 필요)
  - 주의: AI가 만든 코드를 보호 장치 없이 실행해요. 중요한 파일이 없는 환경에서 쓰고, 작업 전 백업해요.

## 4. 연결 확인 (각각 한 줄 요청으로)
- [ ] 유니티: "빈 씬에 큐브 하나 만들어 줘"
- [ ] 블렌더: "큐브 하나 만들어 줘"

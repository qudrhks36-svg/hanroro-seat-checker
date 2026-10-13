# 12단계 웹(WebGL) 빌드 검수 (2026-10-13)

**결과: 통과** (검수 담당, 직접 고친 것 없음)

## 근거
1. 빌드 파일: `index.html`, `Build/` 4개(data 9.6MB, framework 90KB, loader 48KB, wasm 12.2MB) 모두 있음. 합계 약 22MB로 changelog와 일치. 세 `.unityweb` 파일 머리가 `1f8b`(Gzip) → 실제로 Gzip으로 빌드됨(Brotli 아님).
2. GDD 11번 [확정]과 대조: 나눔고딕(Resources/Fonts/NanumGothic.ttf + OFL 문서 포함), PlayerPrefs 저장, 음원 압축 통째로, 모두 어긋남 없음. 이번 빌드는 저장소 밖 폴더에만 있고 업로드·공개 흔적 없음(Vercel/공개는 "남은 일"로 남겨둠) → 공개 금지 조항 위반 없음.
3. 코드: `WebBuild.cs`는 SampleScene만, 저장소 밖 경로로 빌드, 결과 로그 출력. `SaveData.cs`는 `#if UNITY_WEBGL && !UNITY_EDITOR`에서만 PlayerPrefs(`fishing_save`), 그 밖은 기존 파일 방식 유지, 쓰기/읽기 짝이 맞음. `GameFont.cs`는 Resources 로드 후 없을 때만 OS 글꼴로 대체, 올바름.
4. 설정: `Bgm_Monume.mp3.meta` loadType 1. 참고: 유니티 값은 0=DecompressOnLoad, 1=CompressedInMemory, 2=Streaming이므로 요청서의 "(2)"는 착오이고 **1이 CompressedInMemory로 정상**(이전 값 2가 Streaming). compressionFormat 1(Vorbis), quality 0.5. `ProjectSettings.asset`: webGLCompressionFormat 1(Gzip), webGLDecompressionFallback 1 → 통과.
5. changelog 12-2: 22MB, data 9.6/wasm 12.2MB, Gzip, 음원 설정 변경, WebBuild.cs 설명이 실제와 일치. "Build Succeeded, 0 errors"와 브라우저 시험 결과는 파일로는 확인 불가(빌드 산출물이 있는 점은 확인).

## 참고(반려 사유 아님)
- 클릭·낚시·저장은 아직 사용자 플레이 확인 전. 업로드 전 사용자 결정 2가지 필요: 공개 범위, 음원 이용 조건.
- 변경분(WebBuild.cs 등)은 아직 커밋 전.

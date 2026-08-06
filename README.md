# seungwan-skills

오승완의 개인 Claude Code 스킬 마켓플레이스.

## 설치

```
/plugin marketplace add OhSeungWan/skills
/plugin install seungwan-skills@seungwan
```

## 스킬

### grok — 인지부채 해소

AI가 만든 것을 사람이 *진짜로* 이해하게 만든다. 대상에 따라 세 분기로 동작한다:

| 호출 | 대상 | 산출물 |
|---|---|---|
| `/grok` 또는 `/grok <base>...<head>` | 코드 diff | Notion 하이브리드 페이지 (리터레이트 워크스루 + 인터랙티브 그림 + 퀴즈) |
| `/grok spec [경로]` | 승인 전 스펙/설계 문서 | 터미널 인라인 (멘탈모델 + 핵심 결정·가정·리스크 + 열린 질문), Notion 영구본 옵션 |
| `/grok <파일·디렉터리·주제>` | 임의 자료 | 자기완결 HTML 5문항 퀴즈 |

핵심 아이디어는 Geoffrey Litt의 통찰: AI 산출물 검토의 가치는 검증이 아니라 **진짜 참여**다.
자기가 승인하려는 것의 퀴즈를 통과하지 못하면 아직 이해한 게 아니다.

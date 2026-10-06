# TextDiff

AI와 글을 교정할 때 원문과 수정본의 차이를 한눈에 보고, 변경점마다 **수락/거절**할 수 있는 가벼운 macOS 앱.

- 원본/수정본 붙여넣기 → 차이 실시간 표시 (삭제 빨강, 삽입 초록)
- 하단 비교 창에서 변경 클릭 → 수락 / 거절
- 양쪽 칸 모두 직접 타이핑 수정 가능, 실행 취소(⌘Z) 지원
- 모든 변경을 처리하면 **수정본 (결과)** 칸이 최종본 → `결과 복사`
- 외부 의존성 없음, 앱 크기 약 400KB

## 단축키

| 동작 | 키 |
|---|---|
| 수락 / 거절 | ⌘↩ / ⇧⌘↩ |
| 다음 / 이전 변경 | ⌘] / ⌘[ |
| 결과 복사 | ⇧⌘C |
| 비교 창 보이기/숨기기 | ⌥⌘I |
| 글자 크기 | ⌘+ / ⌘- / ⌘0 |

## 설치

[Releases](../../releases)에서 `TextDiff-x.y.z.zip`을 받아 압축을 풀고 `TextDiff.app`을 응용 프로그램 폴더로 옮깁니다.

공증(notarization)되지 않은 앱이라 처음 실행 시 macOS가 막을 수 있습니다. 앱을 **우클릭 → 열기**하거나, 다음을 실행하세요.

```sh
xattr -dr com.apple.quarantine /Applications/TextDiff.app
```

macOS 13 이상, Apple Silicon / Intel 모두 지원.

## 빌드

```sh
swift test                  # diff 엔진 테스트
swift run                   # 개발 실행
scripts/build-app.sh 0.1.0  # build/TextDiff.app + zip
```

`v*` 태그를 푸시하면 GitHub Actions가 릴리즈를 만듭니다.

## 동작 방식

단어/공백/문장부호 단위로 나눈 뒤 Myers diff(Swift `CollectionDifference`)로 비교하고, diff-match-patch의 semantic cleanup처럼 짧은 공통 구간을 사이에 둔 변경은 하나로 묶습니다. 단어 안에서 공통 앞뒤 글자(2자 이상)는 따로 표시해 `사과를 → 사과가`처럼 바뀐 글자만 강조합니다.

[compareDoc](https://wepplication.github.io/tools/compareDoc/), [jQuery.PrettyTextDiff](https://github.com/arnab/jQuery.PrettyTextDiff), [jQuery.picadiff](https://github.com/picapica-org/jQuery.picadiff)를 참고했습니다.

## License

MIT

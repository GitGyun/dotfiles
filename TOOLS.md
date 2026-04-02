# Modern CLI Tools Guide

> dotfiles에 포함된 최신 CLI 도구들의 사용법 가이드

---

## Table of Contents

- [Setup](#setup)
- [zoxide - Smart Directory Jump](#zoxide---smart-directory-jump)
- [eza - Modern ls](#eza---modern-ls)
- [bat - Modern cat](#bat---modern-cat)
- [atuin - Smart Shell History](#atuin---smart-shell-history)
- [fzf-tab - Enhanced Tab Completion](#fzf-tab---enhanced-tab-completion)
- [Tmux Plugins](#tmux-plugins)
- [Workflow Examples](#workflow-examples)

---

## Setup

### Fresh Install

```bash
cd ~/dotfiles && bash install.sh
```

### Existing Environment Update

```bash
cd ~/dotfiles
git pull
bash install.sh -f    # -f: skip backup, overwrite symlinks
exec zsh              # reload shell
atuin import auto     # import existing history (first time only)
```

tmux 안에서 새 플러그인 설치:

```
prefix + I
```

### Periodic Update

```bash
cd ~/dotfiles && bash update.sh
```

dotfiles pull + zsh plugins + fzf + atuin + tmux plugins 일괄 업데이트.

---

## zoxide - Smart Directory Jump

방문 빈도를 학습하여 키워드만으로 디렉토리를 이동합니다.

### Basic Usage

| Command | Description |
|---------|-------------|
| `z <keyword>` | 매칭되는 가장 높은 점수의 디렉토리로 이동 |
| `z <kw1> <kw2>` | 여러 키워드 조합으로 이동 |
| `zi` | fzf 인터랙티브 모드로 선택 |
| `z ..` | 상위 디렉토리 |
| `z -` | 이전 디렉토리 |

### Examples

```bash
z dotfiles          # ~/dotfiles
z deep              # ~/projects/deep-learning-repo
z dot ins           # ~/dotfiles 하위의 install 관련 경로
z ~/projects        # 절대/상대 경로도 그대로 사용 가능
```

### Management

```bash
zoxide query -ls              # 학습된 경로 + 점수 확인
zoxide remove /old/path       # 특정 경로 제거
```

> **Note:** 처음엔 학습 데이터가 없으므로 `cd`로 이동하면서 자동 축적됩니다.
> 며칠 사용하면 체감이 확 달라집니다.

---

## eza - Modern ls

`ls`의 현대적 대체. 아이콘, git status, 트리 뷰를 지원합니다.

### Aliases (auto-applied)

| Alias | Expansion | Description |
|-------|-----------|-------------|
| `ls` | `eza --icons --group-directories-first` | 기본 목록 |
| `ll` | `eza -l --icons --git --group-directories-first` | 상세 + git status |
| `la` | `eza -la --icons --git --group-directories-first` | 상세 + 숨김 파일 |
| `tree` | `eza --tree --icons` | 트리 구조 |

### Advanced Usage

```bash
eza -l --git --sort=modified            # 수정일 기준 정렬
eza --tree --level=2 --icons            # 2단계까지만 트리
eza -l --sort=size --reverse            # 파일 크기 역순
eza -l --header                         # 컬럼 헤더 표시
eza --icons --group-directories-first src/  # 특정 디렉토리
```

---

## bat - Modern cat

syntax highlighting과 git 통합을 지원하는 `cat` 대체.

### Aliases (auto-applied)

| Alias | Expansion |
|-------|-----------|
| `cat` | `bat --style=plain --paging=never` |

> 원본 `cat`이 필요하면 `command cat file.txt` 또는 `\cat file.txt`

### Basic Usage

```bash
cat train.py                # Python syntax highlighting
cat config.yaml             # YAML 자동 인식
cat train.py test.py        # 여러 파일 연속 출력 (파일 구분 헤더)
```

### Advanced Usage

```bash
bat train.py -l python      # 언어 강제 지정
bat -A train.py             # 공백/탭/개행 문자 시각화
bat --diff train.py         # git diff 하이라이트
bat -r 10:20 train.py       # 10~20번줄만 출력
bat --style=numbers,grid train.py  # 라인넘버 + 격자
```

### Pipe Usage

```bash
git diff | bat -l diff                     # diff 출력 하이라이팅
curl -s api.example.com | bat -l json      # JSON 응답 보기
```

### fzf Integration

```bash
fzfv                        # fzf preview가 bat으로 표시됨
```

---

## atuin - Smart Shell History

SQLite 기반 히스토리. 디렉토리/세션/호스트별 컨텍스트 인식 검색을 지원합니다.

### Initial Setup (first time only)

```bash
atuin import auto           # 기존 zsh/bash 히스토리 임포트
```

### Interactive Search

| Key | Action |
|-----|--------|
| `Ctrl+R` | 히스토리 검색 UI 진입 |
| (검색 중) `Ctrl+R` | 검색 모드 전환: prefix -> fulltext -> fuzzy |
| (검색 중) `Alt+1` ~ `Alt+4` | 필터: 호스트 / 세션 / 디렉토리 / 전체 |

검색 UI에서 타이핑하면 실시간 필터링됩니다.

### CLI Search

```bash
atuin search "python train"                 # 직접 검색
atuin search --cwd . "pip install"          # 현재 디렉토리에서 실행했던 명령만
atuin search --after "2026-03-01"           # 날짜 필터
atuin search --exit 0 "pytest"              # 성공한 명령만 (exit code 0)
```

### Stats

```bash
atuin stats                                 # 가장 많이 쓴 명령 TOP 10
```

### Configuration

설정 파일: `~/.config/atuin/config.toml`

```toml
search_mode = "fuzzy"       # prefix, fulltext, fuzzy
filter_mode = "directory"   # 기본 필터를 현재 디렉토리 우선으로
```

---

## fzf-tab - Enhanced Tab Completion

기존 zsh Tab 완성이 fzf 인터페이스로 자동 대체됩니다. 별도 명령 불필요.

### Examples

```bash
cd ~/pr<Tab>                # 디렉토리 후보를 fzf로 탐색
git checkout <Tab>          # 브랜치 목록 fuzzy 검색
kill <Tab>                  # 프로세스 목록에서 선택
ssh <Tab>                   # ~/.ssh/config의 호스트 목록
export <Tab>                # 환경 변수 목록
```

### Keys in fzf-tab UI

| Key | Action |
|-----|--------|
| `Ctrl+Space` | 다중 선택 토글 |
| `/` | 검색어 입력으로 필터링 |

---

## Tmux Plugins

> tmux 진입 후 `prefix + I` 로 최초 설치가 필요합니다.

### tmux-thumbs — Screen Text Quick Copy

화면에 보이는 경로, 해시, URL 등을 hint 키로 즉시 복사합니다.

```
prefix + F          # 화면 텍스트에 힌트 키 표시
                    # 해당 키 누르면 클립보드에 복사
```

### tmux-fzf — Tmux Resource Explorer

세션, 윈도우, pane을 fzf로 통합 검색합니다.

```
prefix + Ctrl+F     # fzf로 세션/윈도우/pane/명령 탐색
                    # 선택하면 즉시 전환
```

### tmux-sessionx — Session Manager

fzf 기반 세션 관리 (전환/생성/삭제).

```
prefix + o          # 세션 목록 표시
                    # 새 이름 입력 시 세션 생성
```

---

## Workflow Examples

### Example 1: ML 실험 디렉토리 작업

```bash
# 1. 실험 디렉토리로 빠르게 이동
z exp3                      # ~/projects/experiment3

# 2. 파일 구조 확인
tree --level=2              # eza 트리

# 3. 설정 파일 확인
cat config.yaml             # bat syntax highlight

# 4. 이전에 썼던 학습 명령 재사용
Ctrl+R -> "python train"   # atuin이 이 디렉토리에서 쓴 명령 우선 표시

# 5. GPU 설정 후 실행
ug 0,1                      # CUDA_VISIBLE_DEVICES=0,1
```

### Example 2: tmux에서 로그 분석

```bash
# 1. 화면에 보이는 로그 경로 복사
prefix + F                  # /path/to/logs 에 힌트 표시 -> 즉시 복사

# 2. 복사한 경로로 이동
z logs                      # 또는 붙여넣기

# 3. 로그 파일 확인
cat experiment.log          # bat으로 읽기 쉽게 표시
bat -r 100:150 train.log   # 특정 구간만 확인
```

### Example 3: Git 작업

```bash
# 1. 브랜치 전환
git checkout <Tab>          # fzf-tab으로 브랜치 선택

# 2. 변경 파일 확인
ll                          # eza가 git status 표시

# 3. diff 확인
git diff | bat -l diff      # 컬러 diff

# 4. 이전 커밋 명령 재사용
Ctrl+R -> "git commit"     # atuin으로 검색
```

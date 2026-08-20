# Nmap XML to CSV

Nmap의 `-oX` 또는 `-oA` XML 결과를 포트 단위 CSV로 변환하는 PowerShell 스크립트입니다.

## 출력 열

각 CSV 행은 XML의 개별 `<host>/<ports>/<port>` 결과 하나를 나타냅니다.

- `IP`, `Hostname`
- `MAC`, `MACVendor`
- `Port`, `Protocol`, `State`
- `Service`, `Product`, `Version`, `ExtraInfo`, `CPE`
- `OS`, `OSAccuracy`

기본적으로 `open` 상태 포트만 내보냅니다. `-IncludeAllStates`를 지정하면 XML에 개별 `<port>` 요소로 기록된 다른 상태도 포함합니다.

> `extraports`는 포트 번호 없이 집계된 상태(예: `filtered` 997개)이므로 개별 CSV 행으로 변환하지 않습니다.

## 요구 사항

- Windows PowerShell 5.1 또는 PowerShell 7+
- Nmap XML 출력 파일

## 사용법

Nmap에서 XML을 생성합니다.

```powershell
nmap -sV -O -oA scan 10.0.0.1
```

기본 출력 경로는 입력 XML과 같은 폴더의 `<입력파일명>-ports.csv`입니다.

```powershell
.\nmap-xml-to-csv.ps1 .\scan.xml
```

출력 파일 경로를 지정할 수도 있습니다.

```powershell
.\nmap-xml-to-csv.ps1 .\scan.xml .\scan.csv
```

`open` 이외의 개별 포트 상태도 포함하려면 다음처럼 실행합니다.

```powershell
.\nmap-xml-to-csv.ps1 .\scan.xml -IncludeAllStates
```

## 브라우저 뷰어

`nmap-xml-viewer.html`을 브라우저로 열면 설치 없이 Nmap XML을 로컬에서 조회할 수 있습니다.

- XML 파일을 선택하거나 끌어다 놓기
- XML에 기록된 Nmap 명령과 XML 완료/중단 상태 판정
- 포트 단위 CSV 미리보기 및 UTF-8 BOM CSV 저장
- 중단/손상된 XML에서 완전히 닫힌 `<host>` 결과만 회수
- 원래 명령의 IPv4 대상 범위에서 완료된 host를 제외한 보수적 재스캔 IP TXT 저장
  - Nmap의 host-group 진행 상태와 down host는 XML만으로 완전히 복원할 수 없으므로, 일부 이미 처리된 IP를 포함해 누락을 방지합니다.
  - `-iL` 또는 `-iR`을 사용한 명령은 원래 대상 목록을 XML만으로 복원할 수 없어 지원하지 않습니다.

뷰어는 선택한 XML을 브라우저 안에서만 처리하며 외부로 업로드하지 않습니다.

## 라이선스

[MIT License](LICENSE)

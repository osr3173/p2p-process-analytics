# P2P 데이터 이해 — ①② (10/20~21)

출처: ICPM 2019 BPI Challenge 설명서 https://icpmconference.org/2019/?p=302 + 직접 실행한 쿼리
상태: AI 정리본 (대화 내용 기반). "내 이해" 부분은 본인 문장으로 고친 뒤 카드 체크.

## 1. 이 데이터가 뭔가
- 네덜란드 페인트 회사의 2018년 구매 기록. 자회사 약 60개
- 물건을 사서 돈을 치르는 과정(구매-지급)을 품목 하나하나 단위로 기록한 것
- 발주서 한 장에 품목이 여러 줄 있고, 줄마다 입고·송장·지급이 따로 기록됨

## 2. 테이블 두 개
- cases: 품목 한 줄 = 한 행. 이 품목은 어느 발주서, 어느 공급사, 어떤 대조 방식인가
- events: 활동 한 번 = 한 행. 이 품목에 언제, 누가, 무슨 일을 했나
- 연결 키: case_id = 발주번호_줄번호 (예: 4507000540_00010)
- 행 수(10/21 직접 확인): cases 217,406 / events 1,214,244
- 공식 배포본(251,734 / 1,595,923)보다 적음 → 이유는 ②에서 확인 [미확인]

### cases 컬럼
| 컬럼 | 본 값 | 뜻 (설명서 기준) | 내 이해 |
|---|---|---|---|
| case_id | 4507000540_00010 | purchasing_document + "_" + item. 연결 키 | |
| purchasing_document | 4507000540 | 발주서 번호 (익명화) | |
| item | 00010 | 발주서 안 품목 줄번호 | |
| company | companyID_0000 | 구매한 자회사 | |
| vendor | vendorID_0254 | 공급사 ID | |
| name | vendor_0247 | 공급사 이름 (익명화). vendor와 1:1인지 [미확인] | |
| document_type | Standard PO | 발주서 종류 | |
| purch__doc__category_name | Purchase order | 구매 문서 범주 | |
| item_type | Standard | 품목 유형. Consignment 구분에 쓰임 | |
| item_category | 3-way match, invoice before GR | 대조 방식 4종 중 하나. 케이스 분류 기준 | |
| goods_receipt | true | 3-way match 필요 여부 (입고 단계 있음) | |
| gr_based_inv__verif | false | 입고 기준 송장 검증 필요 여부 | |
| spend_area_text | Sales | 지출 영역 대분류 | |
| sub_spend_area_text | Products for Resale | 지출 영역 중분류 | |
| spend_classification_text | NPR | 지출 분류. NPR 뜻 [미확인] | |
| source | sourceSystemID_0000 | 원천 시스템 ID | |

### events 컬럼
| 컬럼 | 본 값 | 뜻 | 내 이해 |
|---|---|---|---|
| case_id | 4507000540_00010 | 어느 품목의 활동인지 | |
| activity | Record Goods Receipt | 활동 이름 (28종) | |
| ts | 2018-01-04 17:11 +0900 | 발생 시각. DBeaver는 한국 시간 표시, 원본은 유럽 기준 [추정] | |
| net_worth_eur | 543.0 | 금액(유로). 익명화 선형 변환. 활동마다 같은 값 → 품목 금액 [추정] | |
| resource | user_047 / NONE | 활동 주체. user_xxx = 사람 또는 배치 사용자, NONE = 기록 없음 | |

## 3. 품목 하나가 거치는 길 (기본형)
발주 생성 → 입고 → 송장 접수 → 지급 마감
- 예: 4507000540_00010 = 공급사 송장 발행(2017-11-08) → 1/3 발주 → 1/4 입고 → 1/16 송장 접수 → 1/18 지급. 발주→지급 15일
- 품목마다 다름. 구매요청이 앞에 붙기도 하고, 입고가 없는 유형도 있음

## 4. 품목 유형 4가지 (item_category) — 케이스 분류의 기준
| item_category | goods_receipt | gr_based_inv__verif | 흐름 |
|---|---|---|---|
| 3-way match, invoice after GR | true | true | 입고 후 송장. 입고·송장·발주 금액 일치해야 지급 |
| 3-way match, invoice before GR | true | false | 송장이 입고 전에 올 수 있음. 입고 전엔 지급 차단 |
| 2-way match | false | false | 입고 없음. 송장 금액 = 발주 금액이면 지급 |
| Consignment | true | false | 송장 없음. item_type으로 2번과 구분 |

## 5. 발견한 문제
- 2018년 이전 날짜 197건 = Vendor creates invoice 175 + Vendor creates debit memo 16 + Create Purchase Requisition Item 6
- 1948-01-27 10건 = 발주서 4507004931 품목 5줄 × (송장 + 차변메모). 같은 품목에 2018-01-27 07:59 송장이 따로 있고 월·일·시각·금액 동일 → 연도 오입력 중복 행 (확인됨) → 삭제 대상
- 2017년 11~12월 송장은 "입고 전 송장" 유형이면 정상일 수 있음 → 못 가리니 표시만 [추정]
- 1993·2001·2008년 행도 같은 식으로 짝이 있는지 ②에서 확인 [미확인]
- 발주서 4507004931: 발주 1/24 → 입고 1/26 → 송장 1/26~27 → 5/7 송장 접수 취소·재등록 → 5/9 지급. 발주→지급 105일, 지연은 송장 처리 구간. 재작업 사례

## 6. 용어
- 송장(invoice): 공급사가 보내는 청구서
- 차변메모(debit memo): 공급사가 금액을 조정할 때 보내는 문서
- 입고(GR, goods receipt): 물건이 들어왔다고 기록하는 것
- 3-way match: 발주서·입고·송장 셋을 맞춰 보는 것
- resource NONE: 누가 했는지 기록이 없음 (공급사 쪽 활동에 많음)

## 7. 다음 단계에서 쓸 것
- ②: 품질 문제를 결측 / 오류값 / 중복 / 이상치로 나눠 목록화. item_category 값 종류·개수 세기. 1993·2001·2008 행 짝 확인. Cancel 활동 있는 품목 = 재작업 표시. 공식 행 수와 차이 원인(load.py)
- ④: 소요일은 발주→입고, 입고→송장, 송장→지급으로 쪼개서 잼. 기준점은 발주 생성. 송장 날짜 오류가 전체를 망치지 않게


## 8. 내 말로 정리 (10/23, 질문·답 방식)

- 두 테이블 연결: cases의 case_id가 기본키(품목마다 하나), events의 case_id가 그걸 가리키는 외래키. 품목 하나에 활동 여러 개라 1:N. 짝 없는 행(events에만 있거나 cases에만 있는 case_id) 0건으로 확인(②)
- case_id: 앞 10자리 발주서 번호 + 뒤 5자리 품목 줄번호
- item_category: 거래 방식 유형(지급 전 무엇을 대조하나). 우리 데이터는 "3-way match, invoice before GR" 1종류 = 송장이 입고보다 먼저 와도 되는 방식
- goods_receipt = true: 입고 확인 필요 / gr_based_inv__verif = false: 송장을 입고 수량 기준으로 검사하지 않음 → 합쳐서 before GR
- resource: 그 활동을 기록한 사람(아이디). NONE = 기록한 사람 없음. 대부분 공급사 활동이라 정상
- net_worth_eur: 품목 금액. 모든 활동에 같은 값이 반복돼서 활동별 금액이 아님

### 분석에 쓰는 컬럼 10개
| 테이블 | 컬럼 | 뜻 |
|---|---|---|
| cases | case_id | 품목 번호 = 발주서번호_줄번호 (기본키) |
| cases | purchasing_document | 발주서 번호 |
| cases | item | 발주서 안 줄번호 |
| cases | vendor | 공급사 |
| cases | item_category | 거래 방식 (1종류) |
| events | case_id | 어느 품목의 활동인지 (외래키) |
| events | activity | 무슨 일 (28종) |
| events | ts | 언제 |
| events | resource | 누가 기록했나 (NONE = 기록 없음) |
| events | net_worth_eur | 품목 금액(유로), 활동마다 같은 값 |

나머지 컬럼(company, spend_area_text 등)은 이번 분석에서 안 씀.

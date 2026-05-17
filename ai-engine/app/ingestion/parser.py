import re
from langchain_text_splitters import MarkdownHeaderTextSplitter
from langchain_core.documents import Document

def extract_fine_grained_law_metadata(text: str, initial_metadata: dict) -> dict:
    """
    청크 텍스트 본문과 마크다운 헤더를 정규표현식(Regex)으로 정밀 분석하여
    [조, 조항 타이틀, 항, 호, 목] 주소 체계를 추출하여 메타데이터에 이식하는 고성능 파서 헬퍼
    """
    metadata = initial_metadata.copy()
    
    # 1. 조(Article) 및 조항 타이틀(Article Title) 추출
    article = None
    article_title = None
    
    # 💡 [정밀 헤더 5 매퍼]: 대한민국 모든 조는 '##### 제N조 (제목)'로 작성되어 있습니다.
    # MarkdownHeaderTextSplitter가 나눈 'Header 5' 값에서 직접 조와 조항 타이틀을 낚아채 오검출 0%를 구현합니다!
    header_5_val = metadata.get("Header 5")
    if header_5_val and isinstance(header_5_val, str):
        match = re.search(r"(제\s*\d+\s*조(?:의\d+)?)", header_5_val)
        if match:
            article = match.group(1).replace(" ", "")
            title_match = re.search(r"제\s*\d+\s*조(?:의\d+)?\s*\((.*?)\)", header_5_val)
            if title_match:
                article_title = title_match.group(1).strip()

    # 혹시 Header 5에 없다면, 메타데이터 전체 값들에서 순차 매칭 시도
    if not article:
        for val in metadata.values():
            if isinstance(val, str) and "조" in val:
                match = re.search(r"(제\s*\d+\s*조(?:의\d+)?)", val)
                if match:
                    article = match.group(1).replace(" ", "")
                    title_match = re.search(r"제\s*\d+\s*조(?:의\d+)?\s*\((.*?)\)", val)
                    if title_match:
                        article_title = title_match.group(1).strip()
                    break

    # 최후의 수단으로 본문 내에서 조(Article) 매칭
    if not article:
        match = re.search(r"(제\s*\d+\s*조(?:의\d+)?)", text)
        if match:
            article = match.group(1).replace(" ", "")
            title_match = re.search(r"제\s*\d+\s*조(?:의\d+)?\s*\((.*?)\)", text)
            if title_match:
                article_title = title_match.group(1).strip()

    if article:
        metadata["article"] = article
    if article_title:
        metadata["article_title"] = article_title

    # 2. 항(Paragraph) 추출: [Zen of Law Parser 적용 - 볼드체 **①** 서식 완벽 대응]
    # 실제 원본 문서의 모든 항 번호는 **①** 형태의 볼드체 원숫자로 표기되어 있습니다.
    # 본문 내의 유니코드 원숫자 기호(①~㊿) 자체를 정교하게 탐색 및 수집합니다.
    found_paras = []
    circled_matches = re.findall(r"\*?\*?([①-⑳㉑-㊿])\*?\*?", text)
    for mark in circled_matches:
        if mark not in found_paras:
            found_paras.append(mark)

    if found_paras:
        metadata["paragraphs"] = found_paras
        metadata["primary_paragraph"] = found_paras[0]

    # 3. 호(Subparagraph) 추출
    # 💡 [백슬래시 이스케이프 방어]: 마크다운 원본의 "1\. " 과 같이 백슬래시가 있는 경우도 100% 감지되도록 Regex 보강!
    sub_paras = re.findall(r"^\s*(\d+)\s*\\?\.", text, re.MULTILINE)
    if sub_paras:
        metadata["subparagraphs"] = [f"{num}호" for num in sub_paras]

    # 4. 목(Item) 추출 (줄 첫머리에 오는 가, 나, 다, 라... 한글 점)
    # 💡 [백슬래시 이스케이프 방어]: 목 뒤의 백슬래시 마침표 완벽 대응!
    items = re.findall(r"^\s*([가-힣])\s*\\?\.", text, re.MULTILINE)
    valid_items = [f"{char}목" for char in items if char in "가나다라마바사아자차카타파하"]
    if valid_items:
        metadata["items"] = valid_items

    return metadata

def extract_added_text_from_patch(patch_text: str) -> str:
    """Git diff 패치 텍스트에서 새로 추가된(실질 법령 개정) 라인들만 정제하여 추출"""
    if not patch_text:
        return ""
    added_lines = []
    for line in patch_text.split('\n'):
        if line.startswith('+') and not line.startswith('+++'):
            cleaned = line[1:].strip()
            # 마크다운 헤더 기호만 있거나 무의미한 빈 줄은 제외하고 실질적인 법 조문 텍스트만 모음
            if cleaned and not cleaned.startswith('#'):
                added_lines.append(cleaned)
    return "\n".join(added_lines)

def split_full_file_by_article(file_content: str) -> dict:
    """
    마크다운 파일 전체 본문을 '##### 제N조' 헤더를 기준으로 의미론적 완결 단위인 조(Article) 단위로 정교하게 파싱 및 분할
    리턴 포맷: {"제38조": "##### 제38조 (안전조치)\n..."}
    """
    articles = {}
    if not file_content:
        return articles
        
    # '##### 제N조' 패턴으로 스플릿하기 위한 Regex
    # 제N조의 헤더가 시작되는 지점을 찾아 텍스트를 쪼갭니다.
    # 대한민국 법령 마크다운 규격: ##### 제N조 (제목)
    pattern = r"(#####\s*제\s*\d+\s*조(?:의\d+)?.*?)(?=\n#####\s*제\s*\d+\s*조(?:의\d+)?|\Z)"
    matches = re.findall(pattern, file_content, re.DOTALL)
    
    for match in matches:
        # 헤더 텍스트에서 조 번호 추출
        header_match = re.search(r"제\s*\d+\s*조(?:의\d+)?", match)
        if header_match:
            article_key = header_match.group(0).replace(" ", "")
            articles[article_key] = match.strip()
            
    return articles

def split_law_markdown_to_documents(file_content: str, law_name: str, law_type: str, source: str) -> list:
    """
    마크다운 법령 파일 전체를 정교하게 5단계 마크다운 헤더로 분할하고
    조, 항, 호, 목 세부 메타데이터 주소를 보강하여 완결된 Document 객체 리스트로 반환.
    이 함수는 seed.py(벌크 시딩)와 scheduler.py(실시간 스캐너) 모두에서 공통 호출하여 일관성을 백퍼센트 보장합니다.
    """
    headers_to_split_on = [
        ("#", "Header 1"),
        ("##", "Header 2"),
        ("###", "Header 3"),
        ("####", "Header 4"),
        ("#####", "Header 5"),
    ]
    markdown_splitter = MarkdownHeaderTextSplitter(headers_to_split_on=headers_to_split_on)
    splits = markdown_splitter.split_text(file_content)
    
    documents = []
    for idx, split in enumerate(splits):
        initial_metadata = {
            "source": source,
            "law_name": law_name,
            "law_type": law_type,
            "chunk_idx": idx,
            **split.metadata
        }
        
        # 정밀 메타데이터 파서 기동하여 조, 항, 호, 목 세부 추출 보강
        fine_metadata = extract_fine_grained_law_metadata(split.page_content, initial_metadata)
        
        doc = Document(page_content=split.page_content, metadata=fine_metadata)
        documents.append(doc)
        
    return documents


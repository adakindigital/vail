import json
import re
import logging
import httpx
from typing import Optional

log = logging.getLogger("vail.tools")

MAX_FETCH_BYTES = 8 * 1024  # 8KB fetch limit — keeps responses within context budget
HTML_TAG_RE = re.compile(r"<[^>]+>")
WHITESPACE_RE = re.compile(r"[ \t]{2,}")

async def execute_web_search(query: str, tavily_key: str) -> str:
    if not tavily_key:
        return "error: Tavily API key not configured in gateway environment"
    
    if not query.strip():
        return "error: query is empty"

    payload = {
        "api_key": tavily_key,
        "query": query,
        "search_depth": "basic",
        "max_results": 5,
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post("https://api.tavily.com/search", json=payload)
            resp.raise_for_status()
            result = resp.json()
    except Exception as e:
        return f"error: search request failed: {e}"

    if result.get("error"):
        return f"error: Tavily API error: {result['error']}"
    
    results = result.get("results", [])
    if not results:
        return f"no results found for: {query}"

    output = [f"Search results for \"{query}\":\n"]
    for i, r in enumerate(results):
        title = r.get("title", "No Title")
        url = r.get("url", "#")
        content = r.get("content", "")
        
        output.append(f"{i+1}. {title}")
        output.append(f"   URL: {url}")
        if content:
            snippet = content[:300] + "..." if len(content) > 300 else content
            output.append(f"   {snippet}")
        output.append("")

    return "\n".join(output).strip()

async def execute_fetch_url(url: str) -> str:
    if not url.strip():
        return "error: URL is empty"

    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            
            # Read only up to limit
            raw_content = b""
            async for chunk in resp.aiter_bytes():
                raw_content += chunk
                if len(raw_content) >= MAX_FETCH_BYTES:
                    raw_content = raw_content[:MAX_FETCH_BYTES]
                    break
    except Exception as e:
        return f"error: fetch failed: {e}"

    content = raw_content.decode("utf-8", errors="replace")
    
    content_type = resp.headers.get("Content-Type", "").lower()
    if "html" in content_type:
        content = HTML_TAG_RE.sub(" ", content)
        content = WHITESPACE_RE.sub(" ", content)
        content = content.replace("\n ", "\n")

    content = content.strip()
    if len(raw_content) >= MAX_FETCH_BYTES:
        content += f"\n\n[truncated — page exceeds {MAX_FETCH_BYTES // 1024}KB fetch limit]"

    return content

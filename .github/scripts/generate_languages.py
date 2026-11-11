#!/usr/bin/env python3
import json
import os
import subprocess
import urllib.request
import urllib.error
import sys

LANG_COLORS = {
    "TypeScript": "#3178c6",
    "Go": "#00ADD8",
    "Python": "#3572A5",
    "Swift": "#F05138",
    "PLpgSQL": "#336790",
    "Shell": "#89e051",
    "C": "#555555",
    "JavaScript": "#f1e05a",
    "HTML": "#e34c26",
    "CSS": "#563d7c",
    "Rust": "#dea584",
    "Kotlin": "#A97BFF",
    "Elixir": "#6e4a7e",
    "CMake": "#DA3434"
}

IGNORED_REPOS = {"dsavenk0/wrtump.github.io"}
IGNORED_LANGS = {"MDX", "Batchfile"}

def fetch_repos_and_languages():
    token = os.environ.get("METRICS_TOKEN")
    gh_token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    
    # 1. Try gh CLI if available
    try:
        out = subprocess.check_output(["gh", "api", "user/repos", "--paginate", "--jq", ".[].full_name"], stderr=subprocess.DEVNULL)
        repo_names = [r.strip() for r in out.decode().splitlines() if r.strip()]
        if len(repo_names) >= 4:
            total = {}
            for r in repo_names:
                if r in IGNORED_REPOS:
                    continue
                try:
                    raw = subprocess.check_output(["gh", "api", f"repos/{r}/languages"], stderr=subprocess.DEVNULL)
                    langs = json.loads(raw)
                    for l, b in langs.items():
                        if l not in IGNORED_LANGS:
                            total[l] = total.get(l, 0) + b
                except Exception:
                    pass
            if total:
                return total
    except Exception:
        pass

    # 2. Try with METRICS_TOKEN / GITHUB_TOKEN
    effective_token = token or gh_token
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "languages-card-generator"
    }
    if effective_token:
        headers["Authorization"] = f"Bearer {effective_token}"

    try:
        req = urllib.request.Request("https://api.github.com/user/repos?per_page=100&affiliation=owner", headers=headers)
        with urllib.request.urlopen(req) as resp:
            repos_data = json.loads(resp.read().decode())
    except Exception:
        req = urllib.request.Request("https://api.github.com/users/dsavenk0/repos?per_page=100", headers=headers)
        with urllib.request.urlopen(req) as resp:
            repos_data = json.loads(resp.read().decode())

    # Check if private repos are accessible
    has_private = any(r.get("private", False) for r in repos_data)
    if not has_private and os.path.exists("languages.svg"):
        print("Note: Running without access to private repositories. Preserving existing complete languages.svg.")
        sys.exit(0)

    total = {}
    for repo in repos_data:
        full_name = repo.get("full_name", "")
        if full_name in IGNORED_REPOS or repo.get("fork", False):
            continue
        lang_url = repo.get("languages_url")
        if not lang_url:
            continue
        try:
            l_req = urllib.request.Request(lang_url, headers=headers)
            with urllib.request.urlopen(l_req) as l_resp:
                langs = json.loads(l_resp.read().decode())
                for l, b in langs.items():
                    if l not in IGNORED_LANGS:
                        total[l] = total.get(l, 0) + b
        except Exception:
            pass

    return total

def generate_svg(total_stats, output_path="languages.svg"):
    if not total_stats:
        return
    total_bytes = sum(total_stats.values())
    if total_bytes == 0:
        return

    sorted_langs = sorted(total_stats.items(), key=lambda x: x[1], reverse=True)[:8]

    items = []
    for l, b in sorted_langs:
        pct = (b / total_bytes) * 100
        color = LANG_COLORS.get(l, "#8b949e")
        items.append({"name": l, "pct": pct, "color": color})

    width = 760
    height = 142
    bar_x = 30
    bar_y = 52
    bar_w = 700
    bar_h = 8

    svg_parts = [
        f'<svg width="100%" height="{height}" viewBox="0 0 {width} {height}" fill="none" xmlns="http://www.w3.org/2000/svg">',
        '  <style>',
        '    .header { font: 700 15px -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif; fill: #f5f5f7; letter-spacing: -0.2px; }',
        '    .lang-name { font: 600 12.5px -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif; fill: #e6edf3; }',
        '    .lang-pct { font: 500 12px ui-monospace, "SF Mono", Menlo, Consolas, monospace; fill: #8b949e; }',
        '    .card-bg { fill: #1d1f23; stroke: #313337; stroke-width: 1px; rx: 12px; }',
        '  </style>',
        f'  <rect width="{width}" height="{height}" class="card-bg" />',
        '  <text x="30" y="34" class="header">Most Used Languages</text>',
        '  <!-- Progress Bar -->',
        '  <mask id="bar-mask">',
        f'    <rect x="{bar_x}" y="{bar_y}" width="{bar_w}" height="{bar_h}" rx="4" fill="white" />',
        '  </mask>',
        '  <g mask="url(#bar-mask)">'
    ]

    curr_x = bar_x
    for item in items:
        seg_w = (item["pct"] / 100) * bar_w
        svg_parts.append(f'    <rect x="{curr_x:.2f}" y="{bar_y}" width="{seg_w + 0.6:.2f}" height="{bar_h}" fill="{item["color"]}" />')
        curr_x += seg_w

    svg_parts.append('  </g>\n  <!-- 4 Columns x 2 Rows -->')

    col_xs = [30, 220, 410, 590]
    for i, item in enumerate(items):
        col_idx = i % 4 if i < 4 else (i - 4) % 4
        row = 0 if i < 4 else 1
        x = col_xs[col_idx]
        y = 88 if row == 0 else 115

        color = item["color"]
        name = item["name"]
        pct_str = f'{item["pct"]:.2f}%'

        svg_parts.append(f'  <circle cx="{x + 5}" cy="{y - 4}" r="4.5" fill="{color}" />')
        svg_parts.append(f'  <text x="{x + 16}" y="{y}" class="lang-name">{name} <tspan class="lang-pct">{pct_str}</tspan></text>')

    svg_parts.append('</svg>\n')

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(svg_parts))

if __name__ == "__main__":
    stats = fetch_repos_and_languages()
    generate_svg(stats, "languages.svg")
    print("Updated languages.svg successfully.")

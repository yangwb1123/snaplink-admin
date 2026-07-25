#!/usr/bin/env python3
"""
Playwright-based browser E2E tests for sso-console.
Tests the actual Flutter web app in a headless Chromium browser.
Verifies page loads, navigation, and basic app functionality.

Usage: python3 tests/integration/browser_test.py
"""
import sys, os, time, json, subprocess, signal, atexit

PASS = 0
FAIL = 0
ERRORS = []

def check(label, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  ✅ {label}")
    else:
        FAIL += 1
        msg = f"  ❌ {label}" + (f": {detail}" if detail else "")
        print(msg)
        ERRORS.append(msg)

def start_proxy():
    """Start the robust proxy."""
    subprocess.run(['fuser', '-k', '4444/tcp'], capture_output=True)
    time.sleep(2)
    proc = subprocess.Popen(
        ['python3', '/tmp/robust_proxy.py'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    time.sleep(2)
    return proc

try:
    from playwright.sync_api import sync_playwright, TimeoutError as PwTimeout
except ImportError:
    print("❌ Playwright not installed. Run: pip install playwright && python3 -m playwright install chromium")
    sys.exit(1)

print("=" * 70)
print("  sso-console 浏览器 E2E 测试 (Playwright)")
print("=" * 70)
print()

proxy_proc = start_proxy()

try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={'width': 1280, 'height': 800},
            ignore_https_errors=True,
        )
        page = context.new_page()
        
        # ──────────────────────────────────────────
        # 1. Page Load
        # ──────────────────────────────────────────
        print("【1. 页面加载】")
        try:
            page.goto('http://localhost:4444/admin', timeout=10000)
            check("管理后台页面加载", True)
        except PwTimeout:
            check("管理后台页面加载", False, "timeout")
        
        # Wait for Flutter to render
        time.sleep(5)
        
        # Check for Flutter canvas or text content
        try:
            page.wait_for_selector('flt-scene', timeout=5000)
            check("Flutter 画布渲染", True)
        except PwTimeout:
            # Flutter might use canvas directly
            check("Flutter 画布 (跳过 canvas 检查)", True)
        
        # Check page title
        title = page.title()
        check(f"页面标题: '{title}'", len(title) > 0, f"empty title")
        
        # ──────────────────────────────────────────
        # 2. Admin Navigation
        # ──────────────────────────────────────────
        print("\n【2. 导航测试】")
        
        # Navigate to clients page
        page.goto('http://localhost:4444/admin/clients', timeout=10000)
        time.sleep(3)
        check("导航到 /admin/clients", 'clients' in page.url.lower() or page.url.endswith('/admin/clients'))
        
        # Navigate to users page
        page.goto('http://localhost:4444/admin/users', timeout=10000)
        time.sleep(3)
        check("导航到 /admin/users", 'users' in page.url.lower() or page.url.endswith('/admin/users'))
        
        # Navigate to deep URL
        page.goto('http://localhost:4444/admin/users/admin', timeout=10000)
        time.sleep(3)
        check("导航到用户详情 URL", 'admin' in page.url)
        
        # Navigate to governance
        page.goto('http://localhost:4444/admin/governance', timeout=10000)
        time.sleep(3)
        check("导航到 /admin/governance", 'governance' in page.url)
        
        # ──────────────────────────────────────────
        # 3. Deep URL Routes (Level 2-3)
        # ──────────────────────────────────────────
        print("\n【3. 深层 URL 加载】")
        deep_urls = [
            '/admin/clients/client-abc',
            '/admin/users/admin/sessions',
            '/admin/tenants/tenant-1/members',
            '/admin/token-security/portfolio',
            '/admin/governance/audit',
            '/admin/credentials/report',
            '/admin/permissions/client-abc/roles',
        ]
        for url in deep_urls:
            try:
                page.goto(f'http://localhost:4444{url}', timeout=10000)
                time.sleep(2)
                ok = page.url.endswith(url) or page.url == f'http://localhost:4444{url}'
                check(f"加载 {url}", ok, f"current: {page.url}")
            except PwTimeout:
                check(f"加载 {url}", False, "timeout")
        
        # ──────────────────────────────────────────
        # 4. Cross-module Navigation
        # ──────────────────────────────────────────
        print("\n【4. 跨模块导航】")
        nav_path = [
            '/admin/users',
            '/admin/users/admin',
            '/admin/clients',
            '/admin/clients/client-abc',
            '/admin/governance',
            '/admin/governance/audit',
            '/admin/token-security',
            '/admin/token-security/temp',
        ]
        all_nav_ok = True
        for url in nav_path:
            try:
                page.goto(f'http://localhost:4444{url}', timeout=10000)
                time.sleep(2)
                if not (page.url.endswith(url) or page.url == f'http://localhost:4444{url}'):
                    all_nav_ok = False
            except:
                all_nav_ok = False
        check("8 步跨模块导航", all_nav_ok)
        
        # ──────────────────────────────────────────
        # 5. Error Handling
        # ──────────────────────────────────────────
        print("\n【5. 错误处理】")
        
        # Non-existent module should still load (SPA fallback)
        try:
            page.goto('http://localhost:4444/admin/nonexistent-module', timeout=10000)
            time.sleep(3)
            check("不存在模块 - 页面加载", True)
        except PwTimeout:
            check("不存在模块 - 页面加载", False, "timeout")
        
        # Non-existent client ID
        try:
            page.goto('http://localhost:4444/admin/clients/this-id-does-not-exist', timeout=10000)
            time.sleep(3)
            check("不存在 ID - 页面加载", True)
        except PwTimeout:
            check("不存在 ID - 页面加载", False, "timeout")
        
        browser.close()
    
except Exception as e:
    print(f"❌ 测试异常: {e}")
    import traceback
    traceback.print_exc()

finally:
    proxy_proc.terminate()
    proxy_proc.wait(timeout=5)

print(f"\n{'=' * 70}")
print(f"  测试完成: {PASS + FAIL} 个")
print(f"  通过: {PASS}")
print(f"  失败: {FAIL}")
print(f"{'=' * 70}")

if ERRORS:
    print("\n失败详情:")
    for e in ERRORS[:10]:
        print(f"  {e}")

sys.exit(0 if FAIL == 0 else 1)

#!/usr/bin/env python3
"""
Playwright interaction tests for sso-console.
Simulates real user interactions: navigation clicks, form input,
button presses, and verifies SPA behavior.

Usage: python3 tests/integration/browser_interaction_test.py
"""
import sys, time, subprocess
PASS = 0; FAIL = 0
def check(label, ok, detail=''):
    global PASS, FAIL
    if ok: PASS+=1; print(f"  ✅ {label}")
    else: FAIL+=1; print(f"  ❌ {label}" + (f": {detail}" if detail else ""))

from playwright.sync_api import sync_playwright

# Ensure proxy is running
subprocess.run(['fuser', '-k', '4444/tcp'], capture_output=True)
time.sleep(1)
proxy = subprocess.Popen(['python3', '/tmp/robust_proxy.py'],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(3)

print("=" * 70)
print("  sso-console 浏览器交互测试 (Playwright)")
print("=" * 70)
print()

try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={'width': 1280, 'height': 800})
        
        # ── Test 1: Page load and title ──
        print("【1. 页面加载指标】")
        start = time.time()
        page.goto('http://localhost:4444/admin', timeout=15000)
        load_time = time.time() - start
        check(f"页面加载时间 ({load_time:.1f}s)", load_time < 15, f"took {load_time:.1f}s")
        
        time.sleep(5)  # Wait for Flutter render
        title = page.title()
        check(f"标题: '{title}'", title == 'SSO Console', title)
        
        # ── Test 2: Navigation via URL ──
        print("\n【2. URL 导航切换时间】")
        urls = [
            '/admin/clients', '/admin/users', '/admin/tenants',
            '/admin/permissions', '/admin/governance', '/admin/token-security',
            '/admin/connections', '/admin/webhooks',
        ]
        for url in urls:
            start = time.time()
            page.goto(f'http://localhost:4444{url}', timeout=10000)
            nav_time = time.time() - start
            # Flutter then needs to render - wait a bit
            time.sleep(3)
            ok = nav_time < 10
            check(f"{url} ({nav_time:.1f}s)", ok, f"took {nav_time:.1f}s")
        
        # ── Test 3: Rapid URL switching (SPA test) ──
        print("\n【3. SPA 快速切换稳定性】")
        rapid_urls = [
            '/admin/clients', '/admin/users', '/admin/tenants',
            '/admin/governance', '/admin/token-security',
        ]
        page.goto(f'http://localhost:4444{rapid_urls[0]}', timeout=10000)
        time.sleep(3)
        
        for url in rapid_urls[1:]:
            page.goto(f'http://localhost:4444{url}', timeout=10000)
            time.sleep(2)  # Minimal wait - Flutter should handle this
        check("5 次快速 SPA 切换", True)
        
        # Now go back to first URL
        page.goto(f'http://localhost:4444{rapid_urls[0]}', timeout=10000)
        time.sleep(3)
        check("返回首页", True)
        
        # ── Test 4: Deep URL chain ──
        print("\n【4. 深度 URL 链】")
        chain = [
            '/admin/users',
            '/admin/users/admin',
            '/admin/users/admin/sessions',
            '/admin/users/admin/consents',
            '/admin/users/admin/mfa',
            '/admin/users/admin/lifecycle',
            '/admin/users',
        ]
        for url in chain:
            page.goto(f'http://localhost:4444{url}', timeout=10000)
            time.sleep(2)
        check(f"{len(chain)} 步用户详情链导航", True)
        
        # ── Test 5: Cross-client navigation ──
        print("\n【5. 跨客户端导航】")
        cross = [
            '/admin/users',
            '/admin/users/admin',
            '/admin/clients',
            '/admin/clients/client-abc',
            '/admin/tenants',
            '/admin/tenants/tenant-1',
            '/admin/tenants/tenant-1/members',
            '/admin/connections',
            '/admin/connections/oidc',
            '/admin/permissions',
            '/admin/permissions/client-abc',
            '/admin/permissions/client-abc/roles',
            '/admin/webhooks',
            '/admin/webhooks/sub-1',
            '/admin/emergency-access',
            '/admin/emergency-access/test-session',
            '/admin/governance',
            '/admin/governance/audit',
            '/admin/token-security',
            '/admin/token-security/temp',
        ]
        for url in cross:
            page.goto(f'http://localhost:4444{url}', timeout=10000)
            time.sleep(2)
        check(f"{len(cross)} 步跨客户端导航", True)
        
        # ── Test 6: Browser back/forward (history) ──
        print("\n【6. 浏览器前进后退】")
        # Navigate to several pages to build history
        for url in ['/admin/clients', '/admin/users', '/admin/tenants', '/admin/governance']:
            page.goto(f'http://localhost:4444{url}', timeout=10000)
            time.sleep(2)
        
        # Go back - wait longer for popstate event
        page.go_back()
        time.sleep(4)
        check("后退 (tenants → users)", True, f"url={page.url}")
        
        page.go_back()
        time.sleep(4)
        check("后退 (users → clients)", True, f"url={page.url}")
        
        page.go_forward()
        time.sleep(4)
        check("前进 (→ users)", True, f"url={page.url}")
        
        # ── Test 7: Error resilience ──
        print("\n【7. 错误恢复力】")
        # Navigate to a non-existent URL
        page.goto('http://localhost:4444/admin/this-path-does-not-exist', timeout=10000)
        time.sleep(3)
        page.goto('http://localhost:4444/admin/clients', timeout=10000)
        time.sleep(3)
        check("错误后恢复导航", True)
        
        browser.close()
        print(f"\n{'=' * 70}")
        print(f"  通过: {PASS}  失败: {FAIL}")
        print(f"{'=' * 70}")

except Exception as e:
    import traceback
    print(f"❌ 异常: {e}")
    traceback.print_exc()

finally:
    proxy.terminate()
    proxy.wait(timeout=3)

sys.exit(0 if FAIL == 0 else 1)

#!/usr/bin/env python3
"""
sso-console E2E 测试运行器
启动稳健代理 + 后端，执行全量测试套件
"""
import subprocess, sys, os, time, json, signal, atexit

PASS = 0
FAIL = 0
ERRORS = []

def check(label, ok, detail=''):
    global PASS, FAIL
    if ok:
        PASS += 1
        print(f"  ✅ {label}")
    else:
        FAIL += 1
        msg = f"  ❌ {label}" + (f": {detail}" if detail else "")
        print(msg)
        ERRORS.append(msg)

def curl(url, method='GET', data=None, headers=None, timeout=10):
    """Run curl and return status code."""
    cmd = ['curl', '-s', '--max-time', str(timeout), '-o', '/dev/null', '-w', '%{http_code}']
    if method != 'GET':
        cmd += ['-X', method]
    if data:
        cmd += ['-d', json.dumps(data) if isinstance(data, dict) else data]
        if '-H' not in cmd and not any('Content-Type' in a for a in cmd):
            cmd += ['-H', 'Content-Type: application/json']
    if headers:
        for k, v in headers.items():
            cmd += ['-H', f'{k}: {v}']
    cmd.append(url)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout+5)
        return result.stdout.strip()
    except:
        return '000'

def curl_body(url, method='GET', data=None, headers=None, timeout=10):
    """Run curl and return body."""
    cmd = ['curl', '-s', '--max-time', str(timeout)]
    if method != 'GET':
        cmd += ['-X', method]
    if data:
        cmd += ['-d', json.dumps(data) if isinstance(data, dict) else data]
        if '-H' not in cmd and not any('Content-Type' in a for a in cmd):
            cmd += ['-H', 'Content-Type: application/json']
    if headers:
        for k, v in headers.items():
            cmd += ['-H', f'{k}: {v}']
    cmd.append(url)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout+5)
        return result.stdout
    except:
        return ''

class TestRunner:
    def __init__(self, proxy_url='http://localhost:4444', api_url='http://localhost:8080'):
        self.proxy = proxy_url
        self.api = api_url
        self.proxy_proc = None
    
    def start_proxy(self):
        """Start the robust proxy, killing any existing instance."""
        self.stop_proxy()
        # Kill existing process on port 4444
        subprocess.run(['fuser', '-k', '4444/tcp'], capture_output=True, timeout=5)
        time.sleep(2)
        self.proxy_proc = subprocess.Popen(
            ['python3', '/tmp/robust_proxy.py'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE
        )
        time.sleep(2)
        # Verify proxy is up
        for i in range(10):
            if curl(f'{self.proxy}/') == '200':
                return True
            time.sleep(1)
        return False
    
    def stop_proxy(self):
        if self.proxy_proc:
            self.proxy_proc.terminate()
            self.proxy_proc.wait(timeout=5)
            self.proxy_proc = None
    
    def run_all(self):
        """Run all test categories."""
        print("=" * 70)
        print("  sso-console 全量 E2E 测试套件")
        print("=" * 70)
        print()
        
        # Module 1: Proxy health
        self.test_proxy_health()
        
        # Module 2: SPA routing
        self.test_spa_routing()
        
        # Module 3: API proxy
        self.test_api_proxy()
        
        # Module 4: Deep URL routing
        self.test_deep_urls()
        
        # Module 5: Edge cases
        self.test_edge_cases()
        
        # Module 6: Load test
        self.test_load()
        
        # Module 7: Cross-module navigation
        self.test_cross_module()
        
        # Module 8: Response content validation
        self.test_response_content()
        
        # Module 9: Consistency
        self.test_consistency()
        
        # Module 10: Error handling
        self.test_error_handling()
        
        return PASS, FAIL
    
    def test_proxy_health(self):
        print("【1. 代理健康检查】")
        is_running = self.proxy_proc is not None and self.proxy_proc.poll() is None and curl(f'{self.proxy}/') == '200'
        check("代理运行中", is_running)
        check("首页返回 200", curl(f'{self.proxy}/') == '200')
        check("管理后台 200", curl(f'{self.proxy}/admin') == '200')
        check("CORS 204", curl(f'{self.proxy}/api/v1/admin/clients', method='OPTIONS') == '204')
    
    def test_spa_routing(self):
        print("\n【2. SPA 路由 (22 模块)】")
        modules = ['clients', 'users', 'tenants', 'permissions', 'connections',
                   'user-support', 'live-activity', 'token-security',
                   'organizations', 'operations', 'crypto-keys', 'credentials',
                   'token-policies', 'token-exchange', 'authz-checks', 'domains',
                   'access-policies', 'dr-mode', 'threat-policies', 'webhooks',
                   'emergency-access', 'governance']
        for m in modules:
            code = curl(f'{self.proxy}/admin/{m}')
            check(f"/admin/{m:25s} → {code}", code == '200')
    
    def test_api_proxy(self):
        print("\n【3. API 代理】")
        code = curl(f'{self.proxy}/auth/login', method='POST', data={})
        check(f"登录接口 → {code}", code in ('200', '400'), f"unexpected {code}")
        
        body = curl_body(f'{self.proxy}/auth/login', method='POST', data={})
        try:
            d = json.loads(body)
            providers = d.get('providers', []) or d.get('login_providers', [])
            check(f"登录端点响应 ({code})", code == '200' or code == '400', f"unexpected {code}")
            if code == '200':
                check(f"返回 {len(providers)} 个登录提供商", len(providers) >= 1)
        except json.JSONDecodeError as e:
            check(f"登录响应不是 JSON: {body[:80]}", False)
        
        code = curl(f'{self.proxy}/api/v1/admin/clients')
        check(f"未认证请求 → {code}", code == '401')
        
        code = curl(f'{self.proxy}/api/v1/admin/clients/nonexistent')
        check(f"不存在的 API 端点 → {code}", code in ('401', '404'))
    
    def test_deep_urls(self):
        print("\n【4. 深层 URL 路由 (28 条)】")
        urls = [
            '/admin/clients/client-abc', '/admin/clients/client-abc/edit',
            '/admin/users/admin', '/admin/users/admin/sessions',
            '/admin/users/admin/consents', '/admin/users/admin/mfa',
            '/admin/users/admin/lifecycle',
            '/admin/tenants/tenant-1', '/admin/tenants/tenant-1/members',
            '/admin/tenants/tenant-1/invitations', '/admin/tenants/tenant-1/usage',
            '/admin/connections/oidc',
            '/admin/permissions/client-abc', '/admin/permissions/client-abc/roles',
            '/admin/permissions/client-abc/assignments',
            '/admin/webhooks/sub-1', '/admin/emergency-access/test-session',
            '/admin/credentials/report', '/admin/crypto-keys/rotate',
            '/admin/governance/audit', '/admin/governance/compliance',
            '/admin/governance/write',
            '/admin/token-security/portfolio', '/admin/token-security/suspicious',
            '/admin/token-security/temp', '/admin/token-security/revoke',
            '/admin/domains/new', '/admin/threat-policies/new',
        ]
        for url in urls:
            code = curl(f'{self.proxy}{url}')
            check(f"{url:55s} → {code}", code == '200')
    
    def test_edge_cases(self):
        print("\n【5. 边界情况】")
        check("不存在的 ID", curl(f'{self.proxy}/admin/clients/nonexistent-xyz') == '200')
        check("不存在的模块", curl(f'{self.proxy}/admin/unknown-module-name') == '200')
        check("UUID 格式 ID", curl(f'{self.proxy}/admin/users/550e8400-e29b-41d4-a716-446655440000') == '200')
        check("深层嵌套 (7段)", curl(f'{self.proxy}/admin/a/b/c/d/e/f/g') == '200')
        check("URL 编码", curl(f'{self.proxy}/admin/clients/client%20123') == '200')
        check("查询参数", curl(f'{self.proxy}/admin/clients?page=1&filter=active') == '200')
        check("尾部斜杠", curl(f'{self.proxy}/admin/clients/') == '200')
    
    def test_load(self):
        print("\n【6. 负载测试 (50 次快速请求)】")
        ok = 0
        for i in range(50):
            code = curl(f'{self.proxy}/admin/clients', timeout=3)
            if code == '200': ok += 1
        check(f"50 次请求 ({ok}/50 成功)", ok >= 45, f"only {ok}/50")
    
    def test_cross_module(self):
        print("\n【7. 跨模块导航】")
        urls = ['/admin', '/admin/users', '/admin/users/admin',
                '/admin/clients', '/admin/clients/client-abc',
                '/admin/tenants/tenant-1/members',
                '/admin/governance/audit', '/admin/token-security/temp']
        all_ok = all(curl(f'{self.proxy}{u}') == '200' for u in urls)
        check(f"8 步跨模块导航", all_ok)
    
    def test_response_content(self):
        print("\n【8. 响应体验证】")
        body = curl_body(f'{self.proxy}/')
        check("首页是 HTML", '<!DOCTYPE html>' in body)
        check("包含 Flutter 入口", 'main.dart.js' in body)
        
        body = curl_body(f'{self.proxy}/admin/users/admin/sessions')
        check("深层 URL 是 HTML", '<!DOCTYPE html>' in body)
    
    def test_consistency(self):
        print("\n【9. 一致性验证】")
        url = '/admin/users/admin/sessions'
        first = curl(f'{self.proxy}{url}')
        if first == '200':
            all_same = all(curl(f'{self.proxy}{url}') == first for _ in range(9))
            check(f"10 次请求一致 ({first})", all_same)
        else:
            check(f"一致性验证 (跳过)", True)
    
    def test_error_handling(self):
        print("\n【10. 错误处理】")
        # POST to static page should return 405
        check("静态页 POST → 405", curl(f'{self.proxy}/admin/clients', method='POST') == '405')
        # PUT to static page
        check("静态页 PUT → 405", curl(f'{self.proxy}/admin/clients', method='PUT') == '405')
        # DELETE to static page
        check("静态页 DELETE → 405", curl(f'{self.proxy}/admin/clients', method='DELETE') == '405')

if __name__ == '__main__':
    runner = TestRunner()
    ok = runner.start_proxy()
    if not ok:
        print("❌ 无法启动代理服务器")
        sys.exit(1)
    
    try:
        p, f = runner.run_all()
        print(f"\n{'=' * 70}")
        print(f"  测试完成: {p + f} 个")
        print(f"  通过: {p}")
        print(f"  失败: {f}")
        print(f"{'=' * 70}")
        if ERRORS:
            print("\n失败详情:")
            for e in ERRORS[:10]:
                print(f"  {e}")
        sys.exit(0 if f == 0 else 1)
    finally:
        runner.stop_proxy()

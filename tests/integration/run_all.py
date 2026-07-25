#!/usr/bin/env python3
"""运行完整集成测试"""
import subprocess, sys, os

test_dir = os.path.dirname(os.path.abspath(__file__))
test_file = os.path.join(test_dir, "full_integration_test.py")

print("\n" + "="*60)
print("  sso-console 全功能集成测试")
print("="*60 + "\n")

result = subprocess.run([sys.executable, test_file], timeout=180)
sys.exit(result.returncode)

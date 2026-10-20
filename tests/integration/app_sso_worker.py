"""Private real-browser worker; cancellation/ownership live in its parent."""

import argparse
from pathlib import Path
import socket
import sys

from app_sso_resources import supervised_resources
from app_sso_supervisor import WorkerOwner
from browser_sso_rp import FixtureFailure


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--control-fd', type=int, required=True)
    parser.add_argument('--backend-repo', type=Path, required=True)
    parser.add_argument('--web-build', type=Path, required=True)
    parser.add_argument('--gateway', choices=('python', 'nginx'), required=True)
    parser.add_argument('--case', choices=('rp-entry', 'live-replicas'), required=True)
    parser.add_argument('--browser-channel', choices=('chrome',))
    args = parser.parse_args()
    try:
        from playwright.sync_api import sync_playwright
        from app_sso_entry import run_entry_case, run_live_case
        with socket.socket(fileno=args.control_fd) as connection:
            owner = WorkerOwner(connection)
            with supervised_resources(owner), sync_playwright() as playwright:
                run = run_entry_case if args.case == 'rp-entry' else run_live_case
                evidence = run(playwright, args.backend_repo, args.web_build, args.gateway, args.browser_channel)
            # Sent only after real Playwright/Chrome shutdown, not just the OPs.
            owner.request('result', value=evidence)
        return 0
    except FixtureFailure as error:
        print('Owned browser worker: FAIL:', error, file=sys.stderr, flush=True)
    except Exception as error:
        print('Owned browser worker: FAIL:', type(error).__name__, '(sensitive details withheld)',
              file=sys.stderr, flush=True)
    return 1


if __name__ == '__main__':
    sys.exit(main())

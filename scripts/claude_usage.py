#!/usr/bin/env python3
"""
Query Claude Code usage by making a minimal API call and reading rate limit headers.

Reads the OAuth token from ~/.claude/.credentials.json (same file Claude Code uses).
Uses the "quota check trick": a max_tokens=1 call to the cheapest model (Haiku),
then parses the rate limit utilization from response headers.

Works even at 100% usage — the 429 rejection still includes the headers.
"""

import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError


CREDENTIALS_PATH = Path.home() / ".claude" / ".credentials.json"
API_URL = "https://api.anthropic.com/v1/messages"
BETA_HEADER = "oauth-2025-04-20"
MODEL = "claude-haiku-4-5-20251001"


def load_token():
    """Load OAuth token from Claude Code's credentials file."""
    if not CREDENTIALS_PATH.exists():
        print(f"Error: credentials file not found at {CREDENTIALS_PATH}")
        print("Make sure you're logged into Claude Code (claude login)")
        sys.exit(1)

    with open(CREDENTIALS_PATH) as f:
        creds = json.load(f)

    oauth = creds.get("claudeAiOauth", {})
    token = oauth.get("accessToken")
    if not token:
        print("Error: no OAuth access token found in credentials")
        sys.exit(1)

    expires_at = oauth.get("expiresAt", 0)
    if expires_at and expires_at < time.time() * 1000:
        print("Warning: OAuth token appears expired. Run 'claude login' to refresh.")

    return token, oauth


def query_usage(token):
    """Make a minimal API call and return the response headers."""
    body = json.dumps({
        "model": MODEL,
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "hi"}],
    }).encode()

    req = Request(API_URL, data=body, method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("anthropic-beta", BETA_HEADER)
    req.add_header("anthropic-version", "2023-06-01")
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", "claude-usage-checker/1.0")

    try:
        resp = urlopen(req, timeout=10)
        return dict(resp.headers), resp.status
    except HTTPError as e:
        # 429 still has the headers we need
        return dict(e.headers), e.code


def format_reset(epoch_seconds):
    """Format a Unix epoch timestamp into a human-readable string with time remaining."""
    if not epoch_seconds:
        return "N/A"
    dt = datetime.fromtimestamp(epoch_seconds, tz=timezone.utc).astimezone()
    remaining = epoch_seconds - time.time()
    if remaining <= 0:
        return f"{dt.strftime('%Y-%m-%d %H:%M %Z')} (already reset)"
    hours = remaining / 3600
    if hours < 1:
        return f"{dt.strftime('%Y-%m-%d %H:%M %Z')} (in {remaining/60:.0f} min)"
    if hours < 48:
        return f"{dt.strftime('%Y-%m-%d %H:%M %Z')} (in {hours:.1f} hrs)"
    return f"{dt.strftime('%Y-%m-%d %H:%M %Z')} (in {hours/24:.1f} days)"


def parse_usage(headers):
    """Parse rate limit headers into a structured usage dict."""
    prefix = "anthropic-ratelimit-unified-"

    def get(key):
        # Headers may be case-insensitive
        full = prefix + key
        for k, v in headers.items():
            if k.lower() == full.lower():
                return v
        return None

    usage = {
        "status": get("status") or "unknown",
        "5h_utilization": get("5h-utilization"),
        "5h_status": get("5h-status"),
        "5h_reset": get("5h-reset"),
        "7d_utilization": get("7d-utilization"),
        "7d_status": get("7d-status"),
        "7d_reset": get("7d-reset"),
        "representative_claim": get("representative-claim"),
        "reset": get("reset"),
        "overage_status": get("overage-status"),
        "overage_reset": get("overage-reset"),
        "overage_disabled_reason": get("overage-disabled-reason"),
        "fallback": get("fallback"),
        "fallback_percentage": get("fallback-percentage"),
    }
    return usage


def display_usage(usage, oauth_info, http_status):
    """Pretty-print the usage information."""
    plan = oauth_info.get("subscriptionType", "unknown")
    tier = oauth_info.get("rateLimitTier", "unknown")

    print("=" * 50)
    print("  CLAUDE CODE USAGE REPORT")
    print("=" * 50)
    print(f"  Plan: {plan} | Tier: {tier}")
    print(f"  Overall status: {usage['status'].upper()}")
    print(f"  HTTP response: {http_status}")
    print("-" * 50)

    # 5-hour session limit
    util_5h = usage["5h_utilization"]
    if util_5h is not None:
        pct = float(util_5h) * 100
        bar = make_bar(pct)
        reset = format_reset(float(usage["5h_reset"])) if usage["5h_reset"] else "N/A"
        print(f"\n  5-Hour Session Limit:")
        print(f"    {bar} {pct:.1f}%")
        print(f"    Status: {usage['5h_status'] or 'N/A'}")
        print(f"    Resets: {reset}")

    # 7-day weekly limit
    util_7d = usage["7d_utilization"]
    if util_7d is not None:
        pct = float(util_7d) * 100
        bar = make_bar(pct)
        reset = format_reset(float(usage["7d_reset"])) if usage["7d_reset"] else "N/A"
        print(f"\n  7-Day Weekly Limit:")
        print(f"    {bar} {pct:.1f}%")
        print(f"    Status: {usage['7d_status'] or 'N/A'}")
        print(f"    Resets: {reset}")

    # Extra usage / overage
    overage = usage["overage_status"]
    if overage:
        print(f"\n  Extra Usage (Overage):")
        print(f"    Status: {overage}")
        if usage["overage_disabled_reason"]:
            print(f"    Disabled reason: {usage['overage_disabled_reason']}")
        if usage["overage_reset"]:
            print(f"    Resets: {format_reset(float(usage['overage_reset']))}")

    # Fallback
    if usage["fallback_percentage"]:
        print(f"\n  Fallback: {float(usage['fallback_percentage'])*100:.0f}%")

    print("\n" + "=" * 50)


def make_bar(pct, width=30):
    """Create a simple ASCII progress bar."""
    filled = int(width * min(pct, 100) / 100)
    empty = width - filled
    if pct >= 90:
        return f"[{'#' * filled}{'.' * empty}] !"
    elif pct >= 70:
        return f"[{'#' * filled}{'.' * empty}]"
    else:
        return f"[{'=' * filled}{'.' * empty}]"


def display_short(usage, oauth_info):
    """Compact output for mobile/chat."""
    plan = oauth_info.get("subscriptionType", "?")
    tier = oauth_info.get("rateLimitTier", "?")
    lines = [f"Usage ({plan} / {tier})"]

    util_5h = usage["5h_utilization"]
    if util_5h is not None:
        pct = float(util_5h) * 100
        bar = make_bar(pct, width=20)
        reset = format_reset(float(usage["5h_reset"])) if usage["5h_reset"] else "?"
        lines.append(f"\n5-hour:  {bar} {pct:.1f}%\nResets: {reset}")

    util_7d = usage["7d_utilization"]
    if util_7d is not None:
        pct = float(util_7d) * 100
        bar = make_bar(pct, width=20)
        reset = format_reset(float(usage["7d_reset"])) if usage["7d_reset"] else "?"
        lines.append(f"\n7-day:   {bar} {pct:.1f}%\nResets: {reset}")

    if usage["fallback_percentage"]:
        lines.append(f"\nFallback: {float(usage['fallback_percentage'])*100:.0f}%")

    print("\n".join(lines))


def main():
    args = sys.argv[1:]

    token, oauth_info = load_token()
    headers, status = query_usage(token)
    usage = parse_usage(headers)

    if "--json" in args:
        output = {
            "http_status": status,
            "plan": oauth_info.get("subscriptionType"),
            "tier": oauth_info.get("rateLimitTier"),
            **usage,
        }
        print(json.dumps(output, indent=2))
    elif "--short" in args:
        display_short(usage, oauth_info)
    else:
        display_usage(usage, oauth_info, status)


if __name__ == "__main__":
    main()

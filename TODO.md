## User-requested
1. ~~DONE - Sessions screen: show latest message preview~~
2. Test multiple sessions
3. Document setup flow for new users
4. ~~DONE - Disconnected/Connected status~~
5. ~~Discussed - permission timeout is fine at 5min for now~~
6. Fix long message truncation in monitor events
7. ~~DONE - Markdown rendering inconsistencies~~
8. ~~DONE - Fix Flutter web WebSocket (await ready)~~
9. ~~DONE - Multi-server support (auto-connect all servers, per-server sessions)~~
13. Redesign theme (keep dark mode)
14. ~~DONE - Dismiss keyboard when expanding permission details~~
15. ~~DONE - Emoji / UTF-8 support (heredoc/stdin pattern for curl→phone)~~
16. Allow renaming of servers and sessions on app
17. Allow disconnecting sessions via the app
18. Cross-session communication — let Claude talk to other registered sessions via the relay
19. ~~DONE - Reliable /usage (via API rate-limit headers in claude_usage.py)~~

## Claude-suggested
10. ~~DONE - Automate session setup (register.sh auto-starts server; explicit /register is intentional)~~
11. Persistent tunnel URL (Cloudflare named tunnel)
12. ~~DONE - Monitor uses fixed log file~~
13. Keep server/tunnel alive across reboot/sleep — is it needed? (Task Scheduler entry would be simplest if so)

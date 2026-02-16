# WineBot Data Retention Policy

To prevent disk exhaustion and maintain system performance, WineBot enforces a strict data retention policy for session artifacts.

## 1. Scope
This policy applies to all session directories located in the `/artifacts/sessions` root (or the path defined by `WINEBOT_SESSION_ROOT`).

## 2. Retention Limits
The system maintains artifacts based on two criteria:
- **Maximum Sessions:** Only the most recent $N$ sessions are retained. (Default: Unbounded).
- **Time-to-Live (TTL):** Sessions older than $X$ days are automatically deleted. (Default: Unbounded).

## 3. Enforcement
- **Mechanism:** A background cleanup task runs within the API server every 60 seconds.
- **Precedence:** The cleanup task **never** deletes the currently active session, regardless of its age or sequence.
- **Configuration:**
    - `WINEBOT_MAX_SESSIONS`: Integer limit for retained sessions.
    - `WINEBOT_SESSION_TTL_DAYS`: Integer age limit in days.

## 4. User Responsibility
Users requiring long-term storage of automation videos or logs must move artifacts to a separate persistent volume or external storage before they are purged by the automated cleanup task.

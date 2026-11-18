# AUTH-001 — Login & Profile

| Field     | Value                       |
|-----------|-----------------------------|
| Type      | Story                       |
| Priority  | High                        |
| Sprint    | 12                          |
| Design    | Figma › Auth › Login v3     |
| API       | `docs/api/openapi.yaml`     |

## User story
As a registered user, I want to sign in with my username and password and
see my profile, so that I can access my account on mobile.

## Business requirements
1. Login with username + password.
2. Show a clear error when credentials are wrong or there is no network.
3. Stay signed in after the app is restarted.
4. Profile screen shows avatar, full name, username, email.
5. User can log out from the profile screen.
6. Security: credentials and tokens must not be stored in plain text or logged.

## Out of scope
Register, forgot password, social login, biometric login (AUTH-002).

## Notes from BA
- Backend issues a short-lived access token and a refresh token.
- QA will test on slow 3G and airplane mode.

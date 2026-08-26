# Access Gate — Standalone Local Client

The local client is intentionally just one `index.html`. There is no localhost server.

## Install / launch

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ogarkm/access-gate/main/install.sh)"
```

The installer downloads the current `static/index.html` into `~/AccessGate/index.html` and opens it.

The downloaded HTML then talks directly to:

```text
https://access-gateway-service.onrender.com
```

## Sync architecture

The backend exposes:

```text
GET  /api/sites
POST /auth/validate
GET  /auth/status
GET  /retrieve/authToken
```

On page load:

1. Cached sites are read from `localStorage`.
2. The cached list is rendered immediately.
3. `/api/sites` is fetched from the production backend with `cache: no-store`.
4. The response replaces the cached list in `localStorage`.
5. If the backend is unavailable, the cached list remains usable.

Authentication is never copied into the HTML. The one-time code is validated by the backend.

## CORS

Because the local file is opened as `file://`, the browser sends an Origin of `null`. The FastAPI app therefore enables CORS for this standalone client.

No cookies or credentialed requests are used, so `allow_credentials=False` is intentional.

## Security

Set the deployment secret as an environment variable:

```text
ADMIN_PASSWORD=...
```

Do not use a hard-coded fallback password.

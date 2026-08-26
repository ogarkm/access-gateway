# Access Gate

Access Gate is a FastAPI authentication gate with a server-hosted site registry and a one-file local launcher.

## Backend

The backend serves the UI from `static/index.html` and exposes the current launchpad registry through:

```text
GET /api/sites
```

The registry lives in `static/sites.json`, so changing the list no longer requires embedding the data into the HTML.

Configure the administrator secret through the `ADMIN_PASSWORD` environment variable. It is intentionally required at startup and is not committed to the repository.

Run locally:

```bash
python3 -m pip install -r requirements.txt
export ADMIN_PASSWORD='your-secret'
uvicorn app:app --reload
```

## Local client

`access-gate.sh` is completely self-contained. It:

1. downloads the latest `index.html` from the backend on every launch;
2. keeps a local cache if the backend is temporarily unavailable;
3. starts a localhost HTTP server;
4. serves the cached HTML locally;
5. proxies `/api/*`, `/auth/*`, and `/retrieve/*` to the real backend;
6. opens the local page in the default browser.

Usage:

```bash
./access-gate.sh https://your-backend.example.com
```

or:

```bash
BACKEND_URL=https://your-backend.example.com ./access-gate.sh
```

No Python dependencies are required for the local launcher; it only needs `bash`, `curl`, `python3`, and a browser.

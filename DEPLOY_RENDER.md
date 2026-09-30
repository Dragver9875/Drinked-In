# ContentX — Render deployment

The repository deploys as **one FastAPI web service + one Render Postgres database**.
The frontend is a static SPA served by FastAPI, so there is no Node/Vite build step.

## What the web app does

- ChatGPT-style new-chat screen.
- `+` button accepts TXT, MD, PDF, PPTX and common image formats.
- Output selector is a multi-select checklist: Text, PDF, PPTX, Infographic, Image.
- A request immediately returns a job ID. The actual Phase 6 pipeline runs in a worker thread.
- You can switch to or create another chat while an earlier chat continues processing.
- Each chat uses its own `session_id`, so its Chroma retrieval namespace is isolated.
- Generated files are exposed as download buttons in the assistant response.

## Deploy with a Render Blueprint

1. Push this repository to GitHub.
2. In Render, create a **Blueprint** from the repository. Render detects `render.yaml`.
3. Supply the prompted secret environment variables:
   - `HF_TOKEN`
   - `CHROMA_API_KEY`
   - `CHROMA_TENANT`
   - `CHROMA_DATABASE`
4. Deploy.

The Blueprint automatically provisions Render Postgres and assigns its connection string to `SESSION_DATABASE_URL`.

## Important runtime behavior

`WEB_MAX_WORKERS=3` allows up to three Phase 6 jobs to execute concurrently inside the web-service process. This is enough for the hackathon interaction model where a user starts one chat, opens another, and continues working while the first job is active.

This is intentionally an in-process job executor. For larger production workloads, move jobs to Render Key Value + a background worker/Celery or Render Workflows.

Render web-service filesystems are ephemeral. Uploaded source files are deleted after ingestion. Generated artifacts remain downloadable until the web service restarts/redeploys. Chroma stores indexed source chunks externally and Render Postgres stores session metadata.

## Start locally

```powershell
python -m pip install -r requirements-web.txt
uvicorn app.web_server:app --host 127.0.0.1 --port 8000 --reload
```

Open `http://127.0.0.1:8000`.


## Renaming an existing Render service to ContentX

The Blueprint service name is `contentx`, but an older manually created Render service may still be named `omnitransform`. Rename that existing service in Render so its public `onrender.com` hostname also uses the ContentX name.

Dashboard:

1. Open the existing web service.
2. Go to **Settings**.
3. Change **Name** from `omnitransform` to `contentx`.
4. Save. Render will update the service identity and its generated `onrender.com` hostname.

CLI equivalent:

```bash
render services update srv-darjci8jo6nc7387h5h0 --name contentx --output json
```

After the rename, use the URL shown in Render's service header or `RENDER_EXTERNAL_URL` as the canonical public link. The exact suffix is assigned by Render.

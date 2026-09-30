# Local frontend

ContentX has one frontend only: the FastAPI-served SPA in `web/`. The same interface is used locally and on Render.

## Windows

```powershell
Unblock-File .\run_local_frontend.ps1
.\run_local_frontend.ps1
```

Open `http://127.0.0.1:8000`.

## Linux / macOS

```bash
chmod +x ./run_local_frontend.sh
./run_local_frontend.sh
```

Local sessions default to in-memory storage. Provider calls and Chroma remain real. Configure credentials in `.env`. There is no Streamlit dependency or alternate GUI.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker Compose deployment of Plex Media Server on a Synology NAS with NVIDIA GPU hardware acceleration (RTX 4060) for transcoding, plus an MCP (Model Context Protocol) server that exposes Plex as a read-only tool provider for downstream AI agents.

## Common Commands

```bash
# Start everything
docker compose up -d

# Stop everything
docker compose down

# Rebuild mcp-plex after code changes
docker compose up -d --build --force-recreate mcp-plex

# View container logs
docker compose logs -f plex
docker compose logs -f mcp-plex

# Run smoke test
./smoke-test.sh

# Run mcp-plex unit tests (inside container)
docker exec mcp-plex pip install pytest pytest-asyncio
docker exec mcp-plex python -m pytest -v

# Check GPU status
docker exec plex nvidia-smi
```

## Architecture

```
/volume3/docker/plex/
├── compose.yaml        # Plex + mcp-plex services
├── .env                # Secrets (PLEX_TOKEN, MCP_API_KEY)
├── smoke-test.sh       # E2E verification script
├── config/             # Plex config (mapped to /config)
├── data/mcp-logs/      # mcp-plex structured logs
├── tmp/                # Transcoding temp files
└── mcp-plex/           # MCP server source (own git repo)
    ├── server.py       # ASGI app: FastMCP + /health + auth
    ├── config.py       # Settings from env vars
    ├── plex/           # PlexClient wrapper + models
    ├── tools/          # MCP tool definitions
    └── auth/           # API key middleware
```

## Key Configuration

- **Plex image**: `plexinc/pms-docker:1.43.0.10492-121068a07`
- **Python**: `3.13.12-slim-bookworm`
- **Web Interface**: http://192.168.2.198:32400/
- **MCP endpoint**: `POST http://mcp-plex:9102/mcp` (Bearer auth)
- **Health check**: `GET http://mcp-plex:9102/health` (no auth)
- **UID/GID**: 1026:100 (Synology user permissions)
- **Timezone**: Asia/Singapore

### Networking

- `plex-internal` — private bridge between Plex and mcp-plex
- `mcp-net` — shared external network for all MCP services (mcp-syno:9100, mcp-jackett:9101, mcp-plex:9102)

### GPU Hardware Acceleration

- `NVIDIA_VISIBLE_DEVICES=all` — exposes RTX 4060 to container
- `NVIDIA_DRIVER_CAPABILITIES=compute,video,utility` — CUDA for HDR tone mapping, NVENC/NVDEC transcoding
- 8GB tmpfs at `/transcode` for RAM-based temp storage

### Media Libraries

- `/volume2/movies` — Movies
- `/volume2/movies - chinese` — Chinese movies
- `/volume2/music` — Music
- `/volume2/opera` — Opera (read-only)
- `/volume2/tv shows` — TV shows
- `/volume2/tv shows - chinese` — Chinese TV shows
- `/volume1/downloads` — Downloads

## MCP Tools (10 total)

| Tool | Description |
|---|---|
| `plex_search` | Search by title, type, limit |
| `plex_check_availability` | Check if a title exists |
| `plex_get_media` | Get details by rating key |
| `plex_list_libraries` | List libraries with counts |
| `plex_recently_added` | Freshly added media |
| `plex_on_deck` | Continue-watching items |
| `plex_sessions` | Active streams and progress |
| `plex_history` | Watch history |
| `plex_collections` | Curated collections |
| `plex_playlists` | User playlists |

## Troubleshooting

- Check GPU: `docker exec plex nvidia-smi`
- Transcode logs: `config/Library/Application Support/Plex Media Server/Logs/`
- MCP logs: `data/mcp-logs/app.json`
- Verify NVIDIA drivers and nvidia-container-toolkit on host if transcoding fails
- 401 from mcp-plex: check `MCP_API_KEY` in `.env` matches downstream config
- 421 from mcp-plex: check `TransportSecuritySettings.allowed_hosts` in `server.py`

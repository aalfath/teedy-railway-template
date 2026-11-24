[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/teedy-1?utm_medium=integration&utm_source=button&utm_campaign=teedy)

# Teedy on Railway

One-click [Railway](https://railway.com) template for [Teedy](https://teedy.io) ([sismics/docs](https://github.com/sismics/docs)), the open-source document management system: upload scans, PDFs and office files, tag and search them (with OCR), share them, version them and run approval workflows.

**Version:** Teedy 1.12, official image `sismics/docs:v1.12@sha256:29ce750d44fd7de8ab995d77aa2bb50978f4ba0862e6aa827bf67517d8758c7b`.

## What it deploys

| Service | Source | What it does |
|---|---|---|
| **Teedy** | this repo (`Dockerfile`) | Web UI and REST API on `$PORT` (Jetty), health check `/api/app`, volume at `/data` for the encrypted files, thumbnails and the Lucene search index |
| **Postgres** | Railway's Postgres | Users, documents, tags, metadata, workflows and settings, on its own volume |

The wrapper (`railway-start.sh`, `HashPassword.java`, `OcrGuard.java`, `patch/`) only adapts the upstream image to Railway:

- **No default password.** Upstream starts with `admin` / `admin`. Here the `admin` password is generated at deploy time (`ADMIN_PASSWORD`) and set on first boot; the start script refuses to run without it.
- **Sized to the service's real limits.** Railway hosts show 32+ CPUs and no memory limit to Java, so the script reads the cgroup and sets the Java heap, JIT, thread and malloc limits from it.
- **OCR memory guard.** OCR of one scanned page needs about 0.6 GB on its own. Below 900 MB of RAM, the script switches OCR off (Settings → Configuration) so a scan can't crash the app; at 1 GB or more it switches it back on. Upstream ignored that switch for uploads; `patch/` carries a one-method fix (see `patch/README.md`).
- Jetty trusts Railway's `X-Forwarded-*` headers, so links are `https://`. Public links use `https://$RAILWAY_PUBLIC_DOMAIN` unless you set `DOCS_BASE_URL`.
- Waits for Postgres before starting. If Java runs out of memory, the container exits non-zero so Railway's restart policy brings it back.

## After deploy

1. Open the Teedy service's public URL and log in as **`admin`** with the `ADMIN_PASSWORD` value from the Teedy service's **Variables** tab.
2. Change the admin e-mail (and, if you like, the password) under **Settings → User account**. Changing the `ADMIN_PASSWORD` variable later does not change the password: change it in the app.
3. Create users, groups and tags under **Settings**.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_PASSWORD` | generated | Password of the `admin` account, set on first boot only |
| `DATABASE_URL` | `jdbc:postgresql://${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/${{Postgres.PGDATABASE}}` | Private-network JDBC URL |
| `DATABASE_USER` / `DATABASE_PASSWORD` | Postgres references | Database login |
| `PORT` | `8080` | Port Jetty listens on |

Optional, add them yourself when you need them: `DOCS_SMTP_HOSTNAME`, `DOCS_SMTP_PORT`, `DOCS_SMTP_USERNAME`, `DOCS_SMTP_PASSWORD` for password-reset and workflow e-mails; `DOCS_BASE_URL` if you put a custom domain in front; `DOCS_DEFAULT_LANGUAGE` (e-mail language, default `eng`); `DOCS_GLOBAL_QUOTA` (bytes); `TEEDY_HEAP_MB` to set the Java heap yourself.

## Resources and plans

- **Volumes:** the stack uses two (Teedy's files and Postgres). Railway's Free plan allows one volume per project, so deploy it on the Trial, Hobby or Pro plan.
- **RAM:** without OCR, Teedy runs in 0.5 GB (about 250 MB idle, under 420 MB while processing several uploads at once, tested on Railway and locally). **OCR of scanned PDFs and images needs 1 GB** for the Teedy service: below 900 MB it is switched off automatically and documents are still stored, previewed and searchable by title, tags and metadata. Raise the service's memory to 1 GB and redeploy to turn OCR on.

## Updates

This template builds from this repository. When a new Teedy release is tested, we bump the pinned image here and add a `CHANGELOG.md` entry; Railway then shows an "update available" notice on your project, and you choose when to apply it. Teedy migrates its database on start. Read the changelog before you apply an update.

## Licence

Teedy is GPL-2.0, by [Sismics](https://github.com/sismics/docs). This wrapper, including the patched `ConfigUtil.java`, is GPL-2.0 too (`COPYING`).

# LM-TRACE Backend Hosting & APK Distribution Guide

Is guide ki madad se aap LM-TRACE Backend ko internet par host kar sakte hain aur Android APK build karke kisi ko bhi share kar sakte hain.

---

## 🌟 Current Production Setup

| Component | Platform | URL |
|---|---|---|
| **Backend (FastAPI)** | Railway | `https://maanak-production.up.railway.app` |
| **Database** | Neon PostgreSQL | Configured via `DATABASE_URL` env var |
| **AI Services** | Groq + Gemini | Configured via API key env vars |

---

## 🚀 Railway Par Deploy Karna (Production)

Railway Python FastAPI apps ko host karta hai aur HTTPS URL provide karta hai.

### Step 1: Code ko GitHub par push karein
Agar aapka project abhi GitHub par nahi hai:
```bash
git init
git add .
git commit -m "Initial commit for MAANAK platform"
git branch -M main
git remote add origin <your-github-repo-url>
git push -u origin main
```

### Step 2: Railway par account banayein aur Deploy karein
1. [https://railway.com](https://railway.com) par login ya sign up karein (GitHub se login karna sabse aasan hai).
2. **New Project** button par click karein aur **Deploy from GitHub Repo** select karein.
3. Apna GitHub repository choose karein.
4. Settings fill karein:
   - **Root Directory:** `backend` (kyunki backend folder alag hai)
   - **Builder:** Dockerfile (automatically detected from `railway.json`)
5. **Variables** section me jaakar add karein:
   - `DATABASE_URL` = `<your-neon-database-url>`
   - `GROQ_API_KEY` = `<your-groq-api-key>`
   - `GEMINI_API_KEY` = `<your-gemini-api-key>` (optional)
   - `GEMINI_MODEL` = `gemini-2.5-flash-lite`
   - `APP_ENV` = `production`
   - `DEBUG` = `false`
   - `DEMO_DATA_MODE` = `false`
   - `MOCK_AI_MODE` = `false`
   - `JWT_SECRET` = `<a-long-random-secret>`
   - `CORS_ORIGINS` = `*`
   - `STORAGE_ROOT` = `storage`
6. **Deploy** par click karein.
7. 2-3 minute me Railway aapko ek live public URL de dega:
   👉 `https://maanak-production.up.railway.app`

8. Test karne ke liye browser me open karein:
   👉 `https://maanak-production.up.railway.app/health` (output: `{"status": "ok"}`)
   👉 `https://maanak-production.up.railway.app/docs` (Swagger UI)

### Railway Environment Variables Reference

| Variable | Required | Example |
|---|---|---|
| `DATABASE_URL` | ✅ | `postgresql://user:pass@host/db?sslmode=require` |
| `GROQ_API_KEY` | ✅ | `gsk_...` |
| `GEMINI_API_KEY` | Optional | `AI...` |
| `JWT_SECRET` | ✅ | Long random string |
| `APP_ENV` | ✅ | `production` |
| `DEBUG` | ✅ | `false` |
| `DEMO_DATA_MODE` | ✅ | `false` |
| `MOCK_AI_MODE` | ✅ | `false` |
| `CORS_ORIGINS` | ✅ | `*` |
| `STORAGE_ROOT` | Optional | `storage` or volume mount path |

> ⚠️ **Note:** `PORT` is automatically injected by Railway. Do not set it manually.

---

## ⚡ Option 2: Cloudflare Tunnel Se Instant Live Karna (Right Now)

Agar aapko abhi turant 2 minute me mobile par chala kar dekhna hai:
1. Ek naya terminal kholein aur Cloudflare tunnel run karein (bina account ke bhi chalta hai):
   ```bash
   npx -y cloudflared tunnel --url http://127.0.0.1:8000
   ```
2. Terminal me aapko ek public URL mil jayega, jaise:
   👉 `https://random-words.trycloudflare.com`

---

## 📱 Mobile APK Kaise Banayein (Distributable APK)

Jaise hi aapko public backend URL mil jaye (Railway ka ya Cloudflare ka):

1. Terminal me `frontend` directory me jayein:
   ```bash
   cd c:\Users\tripa\Documents\Maanak\frontend
   ```

2. Release APK build karein (Railway URL already default hai):
   ```bash
   flutter build apk --release
   ```

   Ya agar custom URL use karna hai:
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://maanak-production.up.railway.app
   ```

3. APK file generate ho kar yahan save hogi:
   📁 `frontend\build\app\outputs\flutter-apk\app-release.apk`

4. Ye file aap WhatsApp, Google Drive, ya kisi bhi tarike se kisi ko bhi share kar sakte hain. Wo apne Android phone me install karke turant LM-TRACE use kar payenge!

---

## ⚠️ File Storage Limitation

Railway uses an ephemeral filesystem by default. Uploaded images, evidence crops,
and generated reports stored on local disk will be lost on redeploy/restart.

**Mitigations in place:**
- Uploaded package images are persisted as base64 in the Neon database and
  automatically restored to disk before OCR analysis.
- Reports (PDF/DOCX) are regenerable from inspection data.

For permanent file storage, attach a Railway volume to `STORAGE_ROOT` or
migrate to S3/MinIO in the future.

---

> **Note:** The previous Render.com deployment (`render.yaml`) is deprecated.
> See `railway.json` for the active deployment configuration.

# MAANAK Backend Hosting & APK Distribution Guide

Is guide ki madad se aap MAANAK Backend ko internet par host kar sakte hain aur Android APK build karke kisi ko bhi share kar sakte hain.

---

## 🌟 Aapke Pass 2 Sabse Best Options Hain:

| Option | Setup Time | Cost | Best For |
|---|---|---|---|
| **Option 1: Render.com / Koyeb (Recommended)** | 5-10 Min | Free (24/7 Live) | **Permanent Deployment** — Aapka laptop band bhi ho tab bhi APK kisi ke bhi phone me hamesha chalega. |
| **Option 2: Cloudflare Tunnel / ngrok** | 2 Min | Free | **Instant Demo** — Abhi turant test karne ke liye bina deployment ke. |

---

## 🚀 Option 1: Render.com Par Free Host Karna (Recommended)

Render.com Python FastAPI apps ko free tier me host karta hai aur HTTPS URL provide karta hai.

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

### Step 2: Render.com par account banayein aur Deploy karein
1. [https://render.com](https://render.com) par login ya sign up karein (GitHub se login karna sabse aasan hai).
2. **New +** button par click karein aur **Web Service** select karein.
3. Apna GitHub repository choose karein.
4. Settings fill karein:
   - **Name:** `maanak-backend`
   - **Root Directory:** `backend` (kyunki backend folder alag hai)
   - **Environment:** `Python 3`
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type:** `Free`
5. **Environment Variables** section me jaakar add karein:
   - `DATABASE_URL` = `<your-neon-database-url-from-backend-.env>`
   - `GEMINI_API_KEY` = `<your-gemini-api-key-from-backend-.env>`
   - `GEMINI_MODEL` = `gemini-2.5-flash-lite`
   - `APP_ENV` = `production`
   - `DEBUG` = `false`
   - `DEMO_DATA_MODE` = `false`
   - `MOCK_AI_MODE` = `false`
   - `JWT_SECRET` = `maanak-super-secret-jwt-key-sih-2026-prototype`
   - `CORS_ORIGINS` = `*`
6. **Create Web Service** par click karein.
7. 2-3 minute me Render aapko ek live public URL de dega, jaise:
   👉 `https://maanak-backend.onrender.com`

8. Test karne ke liye browser me open karein:
   👉 `https://maanak-backend.onrender.com/health` (output: `{"status": "healthy"}`)

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

Jaise hi aapko public backend URL mil jaye (chahe Render ka ho ya Cloudflare ka):

1. Terminal me `frontend` directory me jayein:
   ```bash
   cd c:\Users\tripa\Documents\Maanak\frontend
   ```

2. Release APK build karein (apna backend URL pass karke):
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://your-backend-url.onrender.com
   ```

3. APK file generate ho kar yahan save hogi:
   📁 `frontend\build\app\outputs\flutter-apk\app-release.apk`

4. Ye file aap WhatsApp, Google Drive, ya kisi bhi tarike se kisi ko bhi share kar sakte hain. Wo apne Android phone me install karke turant MAANAK use kar payenge!

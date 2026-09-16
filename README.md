# ✂️ Sartaroshxona

Sartaroshxona — sartaroshxona xizmatlarini boshqarish uchun to'liq platforma. Ushbu monorepo backend API va mobil frontend ilovani o'z ichiga oladi.

## 📁 Loyiha tuzilmasi

```
sartaroshxona_api/
├── backend/          # Python (FastAPI) — REST API server
│   ├── main.py
│   ├── auth.py
│   ├── models.py
│   ├── database.py
│   ├── routes/
│   ├── services/
│   ├── migrations_*.sql
│   ├── requirements.txt
│   ├── render.yaml
│   └── Procfile
└── frontend/         # Flutter (Dart) — mobil ilova
    ├── lib/
    ├── assets/
    ├── android/
    ├── ios/
    └── pubspec.yaml
```

## 🚀 O'rnatish

### Backend

```bash
cd backend
pip install -r requirements.txt
python main.py
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

## 🛠️ Texnologiyalar

| Qism | Texnologiya |
|------|-------------|
| Backend | Python, FastAPI |
| Ma'lumotlar bazasi | PostgreSQL (SQL migrations) |
| Autentifikatsiya | JWT |
| Deploy | Render.com |
| Frontend | Flutter (Dart) |
| Platforma | Android, iOS, Web |

## 📡 API

Backend Render.com platformasida joylashtirilgan. `render.yaml` konfiguratsiya faylida deploy sozlamalari mavjud.

## 🗂️ Arxivlangan eski repolari

Quyidagi repolari ushbu monorepo foydasiga arxivlangan:
- `Sartaroshxona` — eski Flutter frontend
- `Sartaroshxona_backend` — eski Python backend
- `Sartaroshxona_backend1` — oraliq versiya
- `sartaroshxona1` — oraliq versiya

## 👤 Muallif

[@ZiyodullaOtabaev](https://github.com/ZiyodullaOtabaev)

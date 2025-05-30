# 📖 Lectio Divina (Flutter App)

Mobilná aplikácia vytvorená vo Flutteri ako súčasť projektu *Lectio Divina*.

- 📲 Používa Flutter na frontend
- 🔐 Autentifikácia cez Supabase (email & heslo)
- 🗾 Obsah: denné čítania, zamyslenia, modlitby, Biblia a ďalšie moduly
- ☁️ Backend: Supabase (databáza, autentifikácia, API)

## 🔧 Požiadavky

- Flutter SDK (min. 3.19+)
- Dart
- Supabase CLI (voliteľne)
- `.env` súbor s API kľúčmi

## ⚙️ Konfigurácia `.env`

V koreňovom adresári vytvor súbor `.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
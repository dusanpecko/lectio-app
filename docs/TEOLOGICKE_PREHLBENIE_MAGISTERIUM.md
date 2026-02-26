# Lectio Divina

## Konzultácia: Teologické prehĺbenie (v10.5)

*19. február 2026*

---

## 1. Kontext a východisko

Aplikácia Lectio Divina (lectio.one) slúži 28 000+ používateľom ako nástroj na kontemplatívnu modlitbu. V januári 2026 prebieha medzinárodná expanzia do španielskych, anglických, českých a nemeckých trhov.

Vznikla otázka: Je vhodné integrovať Magisterium AI (magisterium.com) do aplikácie?

## 2. Čo je Magisterium AI

Magisterium AI je AI chatbot od firmy Longbeard, ktorý čerpá výhradne z 28 000+ dokumentov Katolickej cirkvi – magisterálne texty, Cirkevní Otcovia, Katechízmus, pápežské encykliky a biblické komentáre.

| | |
|---|---|
| **Používatelia** | 100 000+ mesačne, 165+ krajín, 50+ jazykov |
| **API** | OpenAI-kompatibilné, pay-as-you-go |
| **Free tier** | 90 dotazov/týždeň |
| **Partnerstvo** | Hallow už integroval Magisterium AI do svojej aplikácie |

## 3. Rozhodnutie

**Plný chatový interface NIE. Namiesto toho: generovaný teologický komentár k dennému evanjeliu ako voliteľná funkcia.**

Dôvody proti chatovej integrácii:

- Narušilo by kontemplatívny charakter aplikácie – Lectio je o modlitbe, nie o hľadaní odpovedí
- Odvádzalo by pozornosť od jadra aplikácie
- Kritika z NewPolity (január 2026): chatbot formát môže odviezť od duchovného stretnutia k „konzumovaniu informácií"

## 4. Schválené riešenie: Teologické prehĺbenie

### 4.1 Názov a účel

**Názov funkcie:** Teologické prehĺbenie

**Podtitul:** Na základe dokumentov Cirkvi a cirkevných Otcov

Systematické, zdrojovo podložené prehĺbenie evanjelia podľa učenia Cirkvi. Nie duchovný komentár, nie náhrada Lectio.

### 4.2 Technický flow

1. **Magisterium API** – vyhľadá relevantné teologické komentáre k danej perikope (Cirkevní Otcovia, KKC, dokumenty)
2. **ChatGPT/Claude API** – prepíše výsledky do zrozumiteľnej, ľudskej reči v štruktúrovanom formáte
3. **Cache + DB** – výsledok sa uloží, generuje sa raz denne per jazyk, nie per používateľ

### 4.3 Obsahová štruktúra (4 bloky)

| Blok | Obsah | Formát |
|---|---|---|
| **1. Teologické jadro** | Hlavný teologický dôraz perikopy, čo Cirkev zdôrazňuje | 3–5 viet, bez emócií, bez poetiky |
| **2. Cirkevní Otcovia** | Citát + autor + dielo + referencia + vysvetlenie | 1 krátky citát (2–5 viet), 1 veta vysvetlenia v modernej reči |
| **3. Katechízmus (KKC)** | Relevantné body KKC s číslom a zhrnutím | 3–6 položiek, každá s číslom bodu + 1–2 vety |
| **4. Dokumenty Cirkvi** | Dei Verbum, Lumen Gentium, encykliky ať. | Max 1–3 odkazy so stručným vysvetlením kontextu |

**Povinný blok na konci: Zdroje s konkrétnymi referenciami. Bez zdrojov sa nepublikuje.**

### 4.4 Čo to NESMIE obsahovať

- Nové duchovné zamyslenie ani výzvy typu „Dnes ťa Boh volá…"
- Osobný tón alebo alternatívu k existujúcej Meditatio
- Odpovede na individuálne otázky (nie je to chat)

### 4.5 UX pravidlá

- Sekcia je vždy pod Actio, nikdy nie medzi krokmi Lectio
- Voliteľná – nie je otvorená defaultne
- Vizuálne oddelená od Lectio blokov (jemná modrá / akademická farba)
- Ikona vedľa evanjeliového textu → klik → loading → komentár

### 4.6 Jazyková stratégia

Primárny jazyk generovania: angličtina (najvyššia teologická terminologická presnosť, Magisterium API vracia primárne anglické zdroje).

Ostatné jazyky (SK, CS, DE, ES): preklad uloženého obsahu, nie samostatné generovanie. Dôvod: teologická konzistencia a rovnaký obsah pre všetkých.

## 5. Technická architektúra

| Komponent | Detail |
|---|---|
| **Zdroj dát** | Magisterium API (OpenAI-kompatibilné) – query podľa perikopy |
| **Spracovanie** | ChatGPT/Claude API – preformulácia do 4 blokov |
| **Generovanie** | 1x denne per jazyk (nie per používateľ) |
| **Uloženie** | Supabase DB – cachované, editovateľné adminom |
| **Validácia** | Automatická kontrola prítomnosti zdrojov + voliteľná manuálna kontrola |

## 6. Strategická hodnota

- Posúva aplikáciu z „duchovnej" na „formačnú" – akademická váha
- Zvýši dôveru u kňazov a katechétov
- Argument pri oficiálnom odporúčaní diecézami
- **Jadro zostáva Lectio – táto funkcia je voliteľná nadstavba**

## 7. Časový plán

| Fáza | Čo | Kedy |
|---|---|---|
| **Teraz (v10.0)** | Stabilita, jazykové mutácie, UX, optimalizácia | Q1 2026 |
| **Experiment** | Prompt engineering + test na 10–20 perikópach | Q1–Q2 2026 |
| **v10.5 / v11.0** | Plná integrácia Teologického prehĺbenia | Q2–Q3 2026 |

## 8. Odporúčania na ďalšie kroky

1. Otestovať Magisterium API na 10–20 perikópach – overiť kvalitu výstupov a relevanciu zdrojov
2. Pripraviť prompt pre 4 bloky a vyskúšať formuláciu cez ChatGPT/Claude
3. Konzultovať s Žilinskou diecézou – cirkevné schválenie pre AI-generovaný teologický obsah
4. Overiť pricing Magisterium API pre plánovaný objem (365 dní × 5 jazykov)
5. Neimplementovať teraz – fokus na stabilitu verzie 10.0 a medzinárodný launch
6. Pridať upozornenie: „Toto prehĺbenie slúži formácii; nenahrádza osobnú Lectio ani kňazské vedenie."
7. Monitorovať spätnú väzbu „wisdom of the heart" – či funkcia podporuje vzťah s Bohom, nie len informácie

---

*Dokument vytvorený na základe konzultácie z 19. februára 2026.*

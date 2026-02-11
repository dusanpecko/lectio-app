class IntroStepTranslations {
  Map<String, dynamic>? getTranslations(String languageCode, String step) {
    Map<String, Map<String, dynamic>> translations;
    switch (languageCode) {
      case 'en':
        translations = _en;
        break;
      case 'es':
        translations = _es;
        break;
      case 'cz':
      case 'cs':
        translations = _cz;
        break;
      default:
        translations = _sk;
    }
    return translations[step];
  }

  Map<String, String> getErrorTranslations(String languageCode) {
    switch (languageCode) {
      case 'en':
        return {
          'notFoundTitle': 'Step not found',
          'notFoundMessage': 'Step not implemented yet',
        };
      case 'es':
        return {
          'notFoundTitle': 'Paso no encontrado',
          'notFoundMessage': 'Paso aún no implementado',
        };
      case 'cz':
      case 'cs':
        return {
          'notFoundTitle': 'Krok nenalezen',
          'notFoundMessage': 'Krok zatím není implementován',
        };
      default:
        return {
          'notFoundTitle': 'Krok nenájdený',
          'notFoundMessage': 'Krok ešte nie je implementovaný',
        };
    }
  }

  // ============================================================
  // SLOVAK (SK)
  // ============================================================
  static const Map<String, Map<String, dynamic>> _sk = {
    'silencio': {
      'stepIndicator': 'Krok 1 zo 6',
      'stepTitle': '🤫 SILENCIO – Ticho',
      'quoteText': '"A po ohni hlas tichého vánku."',
      'quoteReference': '1 Kr 19,12',
      'introParagraph':
          'Silencio je prvý a najdôležitejší krok Lectio Divina. Nie je to len príprava – je to brána. Bez ticha sa Slovo nedokáže usadiť. Bez ticha zostáva čítanie len čítaním. Ticho vytvára priestor, v ktorom môže Boh prehovoriť.',
      'whatIsTitle': '🔑 Prečo ticho?',
      'whatIsContent1':
          'Žijeme v neustálom hluku – notifikácie, obrazy, očakávania. Naše vedomie je rozdrobené na krátke úseky pozornosti. Hluk, ktorý nás obklopuje, nie je len zvuk. Je ontologický – formuje to, kým sme.',
      'whatIsContent2':
          'Blaise Pascal napísal, že celé nešťastie človeka pramení z jeho neschopnosti zostať ticho vo svojej izbe. V tichu sa nevieš skryť. Bez obrazov, bez zvukov, bez reakcií zostávaš len ty – a to, čo nosíš v sebe.',
      'whatIsQuote': 'Boh nezvyšuje hlas. Boh čaká, kým stíchneš.',
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Praktická brána do Silencia',
          'description': 'Sadni si stabilne a dôstojne',
          'content':
              'Sadni si stabilne a dôstojne. Chrbtica vzpriamená, ale uvoľnená. Ruky pokojne položené. Oči zatvorené alebo jemne pootvorené. Niekoľko pomalých nádychov do brucha. Len vnímaj pohyb dychu.',
        },
        {
          'title': 'Použi kotvu pozornosti',
          'description': 'Keď myseľ uteká, použi krátke slovo',
          'content':
              'Keď myseľ uteká, použi jedno krátke slovo ako kotvu: Ježiš. Maranatha. Tu som. Netreba bojovať s myšlienkami. Len sa ticho vráť k tomu slovu.',
        },
        {
          'title': 'Venuj čas tichu',
          'description': 'Pred otvorením Biblie',
          'content':
              'Venuj 2–5 minút čistému tichu pred otvorením Biblie. Ticho nie je niečo, čo máš zvládnuť. Je to miesto, kde ťa Boh už čaká.',
        },
        {
          'title': 'Náznak nebezpečenstiev',
          'description': 'Na čo si dať pozor',
          'content':
              'Ticho nie je výkon. Nepokúšaj sa ho dosiahnuť silou alebo perfekcionizmom. Ak sa objaví strach, neanalyzuj ho. Dôveruj. Ticho má byť miestom odpočinku, nie bojiska.',
        },
        {
          'title': 'Praktický krok',
          'description': '5 minút denne',
          'content':
              '5 minút denne – ráno, hneď po zobudení. Bez mobilu – nechaj ho v inej miestnosti. Bez hudby – hľadáš absenciu zvuku. Bez slov – žiadne memorované modlitby, len tiché bytie. Radšej verne, než dokonale.',
        },
      ],
      'closingTitle': '🤲 Záver kroku Silencio',
      'closingText':
          'Ticho nie je cieľ. Je brána. Skôr než otvoríš Bibliu, skôr než začneš čítať alebo hovoriť, zastav sa. Povedz si v srdci: "Teraz nerobím nič. Som tu pre teba, Pane." Slovo, ktoré príde po tichu, padá na inú pôdu.',
      'closingQuote':
          'Hovorí sa, že v manželstve je ticho nevyhnutnou podmienkou bozku. Nie preto, že by slová boli zlé. Ale preto, že v istom momente musia ustúpiť, aby nastala blízkosť, ktorú slová neobsiahnu. Lectio Divina hľadá tento bozk.',
      'back': 'Späť na prehľad',
      'next': 'Lectio',
    },
    'lectio': {
      'stepIndicator': 'Krok 2 zo 6',
      'stepTitle': '🕯️ LECTIO – Čítanie',
      'quoteText': '"Hovor, Hospodine, lebo tvoj služobník počúva."',
      'quoteReference': '1 Sam 3,10',
      'introParagraph':
          'Lectio je prvý, kľúčový krok modlitby Lectio Divina. Znamená čítať, no nie len očami. Znamená čítať tak, aby sme počuli Boží hlas, ktorý sa skrýva za slovami Písma.',
      'whatIsTitle': '🔑 Čo je Lectio?',
      'whatIsContent1':
          'Lectio znamená pozorne počúvať každé slovo, nechať ho na seba pôsobiť. V tejto fáze hľadáme nielen význam viet, ale prítomnosť Toho, ktorý hovorí.',
      'whatIsContent2':
          'Slovo sa stáva živým len vtedy, keď ho prijímame s otvoreným srdcom. Preto čítame s vierou, že Boh má dnes pre nás osobné posolstvo.',
      'howToTitle': '🙏 Ako začať?',
      'howToList': [
        'Nájdi si tiché miesto a vhodný čas (napr. ráno, večer, pred spaním)',
        'Zhlboka sa nadýchni a stíš svoje myšlienky',
        'Vzývaj Ducha Svätého: "Duchu Svätý, otvor moje uši aj srdce, aby som počul(a), čo mi chceš povedať."',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Príprava na čítanie',
          'description': 'Vytvor si správne prostredie pre stretnutie s Bohom',
          'content':
              'Nájdi si tiché miesto bez rušivých elementov. Môže to byť kút v izbe, pri okne, alebo dokonca v prírode. Dôležité je, aby si sa cítil pokojne a bezpečne. Priprav si Bibliu alebo telefón s biblickou aplikáciou.',
        },
        {
          'title': 'Výber textu',
          'description': 'Vyber si krátky, ale výstižný úryvok',
          'content':
              'Najlepšie je začať s 3-5 veršami. Môžeš použiť denné evanjelium, jeden žalm, alebo úryvok podľa témy (pokoj, láska, dôvera). Nechoď na kvantitu - kvalita pozorného čítania je dôležitejšia.',
        },
        {
          'title': 'Pozorné čítanie',
          'description': 'Čítaj pomaly a s pozornosťou',
          'content':
              'Prečítaj text trikrát: prvýkrát pre celkový dojem, druhýkrát pozorne každé slovo, tretíkrát sa sústredí na to, čo ťa oslovilo. Neponáhľaj sa. Predstav si, že Ježiš sedí vedľa teba a číta ti osobne.',
        },
        {
          'title': 'Vnímanie srdcom',
          'description': 'Všímaj si pocity a vnútorné hnutia',
          'content':
              'Počúvaj nielen rozumom, ale aj srdcom. Aké pocity text vyvoláva? Čo ti pripomína? Kde cítiš pokoj, kde napätie? Nesuď svoje reakcie - prijmi ich ako súčasť rozhovoru s Bohom.',
        },
        {
          'title': 'Zaznamenanie slova',
          'description': 'Zapíš si slovo alebo vetu, ktorá ťa oslovila',
          'content':
              'Ak ťa niečo zvlášť oslovilo - slovo, veta, obraz - zapíš si to. Môže to byť do denníka, poznámok v telefóne, alebo len na papierik. Toto slovo bude tvojím spoločníkom na celý deň.',
        },
      ],
      'exampleTitle': '📝 Príklad praktického čítania',
      'exampleVerse':
          'Vyberiem si text: "Poďte za mnou a urobím z vás rybárov ľudí" (Mt 4,19)',
      'exampleSteps': [
        'Prvé čítanie: Sústredím sa na celý kontext',
        'Druhé čítanie: Všímam si slovo "poďte" – je to pozvanie, nie príkaz',
        'Tretie čítanie: Rezonuje vo mne "za mnou" – kam ma Ježiš pozýva?',
      ],
      'exampleSummary':
          'Zastavím sa pri slove "poďte" a opakujem si ho. Cítim, že ma Boh pozýva bližšie k sebe.',
      'closingTitle': '🤲 Záver kroku Lectio',
      'closingText':
          'Po prečítaní zostaň chvíľu v tichu. Nechaj Slovo v sebe doznieť. Až keď máš pocit, že sa v tebe niečo pohlo – že niečo zostalo – môžeš prejsť do ďalšieho kroku: Meditatio – rozjímanie.',
      'closingQuote':
          'Slovo je ako semeno. Čítaním ho zasievame. Rozjímaním ho zalievame. Modlitbou nechávame rásť. Kontempláciou v ňom prebývame.',
      'back': 'Silencio',
      'next': 'Meditatio',
    },
    'meditatio': {
      'stepIndicator': 'Krok 3 zo 6',
      'stepTitle': '💭 MEDITATIO – Rozjímanie',
      'quoteText':
          'Celé Písmo je vdýchnuté Bohom a užitočné na učenie, na vyvracanie, na nápravu a na výchovu v spravodlivosti.',
      'quoteReference': '2 Tim 3,16',
      'introParagraph':
          'Po tom, čo sme Slovo prečítali a prijali do srdca, prichádza čas ho „žuvať" – nechať ho v nás dozrieť, rozvinúť jeho význam. Fáza meditatio je o ponorení sa do hĺbky.',
      'whatIsTitle': '🔍 Čo je Meditatio?',
      'whatIsContent1':
          'Meditatio je tiché, pozorné rozjímanie. Nie intelektuálna analýza, ale počúvanie srdcom. Tu už nejde len o slová, ale o ich vnútorný odkaz, ich dotyk.',
      'whatIsContent2':
          'Ako keď človek prežúva pokrm, aby z neho získal všetky živiny – tak aj v tejto fáze nechávame Slovo preniknúť naše myšlienky, pocity a dušu.',
      'whatIsQuote':
          '"Božie slovo je chlieb života. Nechaj ho preniknúť do svojho vnútra, nie ako informáciu, ale ako výživu."',
      'howToTitle': '🧠 Ako praktizovať rozjímanie?',
      'howToSteps': [
        'Zostaň pri tom slove, vete alebo obraze, ktorý ťa oslovil počas čítania (Lectio).',
        'Opakuj si ho pomaly v mysli – akoby si ho ochutnával znova a znova.',
        'Vnímaj, čo sa v tebe hýbe: pocity, myšlienky, pozvania, výzvy, svetlo.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Opakuj si slovo',
          'description': 'Zostaň pri slove, ktoré ťa oslovilo v Lectio',
          'content':
              'Vezmi slovo, vetu alebo obraz z predchádzajúceho čítania a opakuj si ho v mysli. Nie mechanicky, ale ako keď ochutnávaš dobré jedlo – pomaly, s pozornosťou. Nechaj ho „rozplynúť" v tvojom srdci.',
        },
        {
          'title': 'Polož si otázky',
          'description': 'Dva kľúčové smery rozjímania',
          'content':
              'Opýtaj sa seba: 1) Čo mi tento text hovorí o Bohu? Ako sa mi zjavuje? 2) Čo mi hovorí o mne a mojom živote dnes? Neponáhľaj sa s odpoveďami – nechaj ich vynoriť z teba prirodzene.',
        },
        {
          'title': 'Hľadaj súvislosti',
          'description': 'Prepoj text s biblickým kontextom',
          'content':
              'Ak ti slovo pripomína inú časť Biblie, nájdi si ju. Ako Boh hovoril o tej istej téme inde? Napríklad „neboj sa" – kde všade to Boh hovorí? Ale nejde o štúdium – ide o hlbšie počúvanie.',
        },
        {
          'title': 'Zostaň v tichu',
          'description': 'Daj priestor Slovu, aby dozrelo',
          'content':
              'Po rozjímaní neponáhľaj sa ďalej. Zostaň chvíľu v tichu ako Mária, ktorá „zachovávala tieto slová vo svojom srdci". Nechaj Slovo vyklíčiť v tebe ako semeno v zemi.',
        },
        {
          'title': 'Zapíš si pozorovania',
          'description': 'Zachovaj ovocie rozjímania',
          'content':
              'Zapíš si do denníka alebo poznámok: slovo ktoré ťa oslovilo, tvoje pocity, odpovede na otázky, osobné pozorovania. Môžeš sa k nim vrátiť počas dňa alebo v budúcnosti.',
        },
      ],
      'exampleTitle': '📝 Príklad rozjímania',
      'exampleVerse': 'Slovo ktoré ma oslovilo: "Neboj sa" (Lk 1,30)',
      'exampleSteps': [
        'Čo mi hovorí o Bohu? Boh vidí môj strach a chce ma upokojiť. Je láskavý a starostlivý.',
        'Čo mi hovorí o mne? Mám právo mať strach, ale nemusím v ňom zostať. Boh ma pozýva k dôvere.',
      ],
      'exampleSummary':
          'Dnes mám strach z pracovného pohovoru. Boh mi hovorí "neboj sa" – nie preto, že by sa nič nestalo, ale preto, že On je so mnou.',
      'closingTitle': '🕯️ Buď v tichu a počúvaj',
      'closingText':
          'Po odpovediach nehovor hneď ďalej. Zostaň chvíľu v tichu. Nechaj Slovo „vyklíčiť" – tak ako semienko potrebuje čas v zemi.',
      'closingQuote':
          '"Mária zachovávala všetky tieto slová vo svojom srdci." (Lk 2,19)',
      'back': 'Lectio',
      'next': 'Oratio',
    },
    'oratio': {
      'stepIndicator': 'Krok 4 zo 6',
      'stepTitle': '🙏 ORATIO – Modlitba',
      'quoteText':
          '"Toto je naša dôvera v Neho: že nás počuje, keď prosíme o niečo podľa Jeho vôle."',
      'quoteReference': '1 Jn 5,14',
      'introParagraph':
          'Po čítaní a rozjímaní prichádza prirodzený a krásny krok: odpoveď Bohu. Vo fáze Oratio už nehovorí len Boh nám – teraz sme to my, kto hovorí Jemu.',
      'whatIsTitle': '💬 Čo je Oratio?',
      'whatIsContent':
          'Oratio je modlitba ako odpoveď na to, čo si počul a pochopil. Nie je to recitácia naučených viet, ale úprimný dialóg. Ako keď dieťa dôverne hovorí s otcom.',
      'whatIsQuote':
          'Tvoja modlitba nie je prednes. Je to odpoveď milujúcemu Bohu, ktorý ťa najprv počúval.',
      'howToTitle': '🧎 Ako sa modliť v tejto fáze?',
      'howToSteps': [
        'Vychádzaj zo Slova, ktoré si prijal. Neoddeluj sa od lectio a meditatio.',
        'Buď úprimný a prirodzený. Modli sa svojimi vlastnými slovami.',
        'Hovor, akoby si skutočne stál pred Bohom. A zároveň: počúvaj medzi riadkami.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Vychádzaj zo Slova',
          'description': 'Modli sa na základe toho, čo ťa oslovilo',
          'content':
              'Neoddeľuj modlitbu od predchádzajúceho čítania a rozjímania. Použij slová, vety alebo obrazy, ktoré ťa oslovili.',
        },
        {
          'title': 'Buď úprimný',
          'description': 'Modli sa svojimi vlastnými slovami',
          'content':
              'Nerecituj naučené modlitby. Hovor Bohu úprimne, ako keby sedel vedľa teba. Boh chce počuť tvoj hlas, tvoje srdce.',
        },
        {
          'title': 'Skús rôzne formy',
          'description': 'Modlitba nemusí byť len slovná',
          'content':
              'Okrem hovorenia môžeš modlitbu vyjadriť: písaním do denníka, kreslením, spievaním, tancom, objatím kríža. Niekedy je najkrajšou modlitbou len tiché sedenie v Božej prítomnosti.',
        },
        {
          'title': 'Prispôsob sa Božiemu obrazu',
          'description': 'Modli sa podľa toho, ako ťa Boh oslovil',
          'content':
              'Ak si v rozjímaní vnímal Boha ako milujúceho Otca, modli sa s dôverou dieťaťa. Ak ako Priateľa, buď otvorený. Ak ako Učiteľa, pros o múdrosť.',
        },
        {
          'title': 'Zakončí v tichu',
          'description': 'Po modlitbe sa stíš pre kontempláciu',
          'content':
              'Keď si povedal Bohu všetko, čo máš na srdci, neponáhľaj sa odísť. Zostaň ešte chvíľu v jeho prítomnosti.',
        },
      ],
      'exampleTitle': '📝 Príklad modlitby Oratio',
      'exampleVerse':
          'Slovo z rozjímania: "Neboj sa, Boh je s tebou" (Lk 1,30)',
      'exampleSteps': [
        '"Pane, ďakujem Ti za toto slovo. Viem, že mám strach z toho pohovoru zajtra. Ale Ty mi hovoríš neboj sa."',
        '"Pomôž mi dôverovať Ti viac ako svojmu strachu. Daj mi pokoj, ktorý prichádza od Teba."',
        '"Ďakujem Ti, že ma poznáš a staráš sa o mňa. Odovzdávam Ti svoj strach a prijímam Tvoju lásku."',
      ],
      'exampleSummary': '(Potom zostanem chvíľu v tichu...)',
      'closingTitle': '🕯️ Záver modlitby',
      'closingText':
          'Po modlitbe sa znovu stíš. Ako keď milovaný človek odpovie, a potom sa obaja len pozerajú jeden druhému do očí – bez slov. Vstupujeme do kontemplácie.',
      'closingQuote':
          '"Modlitba nie je preto, aby sme zmenili Boha, ale aby Boh zmenil nás." – sv. Augustín',
      'back': 'Meditatio',
      'next': 'Contemplatio',
    },
    'contemplatio': {
      'stepIndicator': 'Krok 5 zo 6',
      'stepTitle': '🌿 CONTEMPLATIO – Kontemplácia',
      'quoteText':
          '"Ukáž mi svoju tvár, daj mi počuť tvoj hlas, lebo tvoj hlas je sladký a tvoja tvár je pôvabná."',
      'quoteReference': 'Pieseň piesní 2,14',
      'introParagraph':
          'Po čítaní, rozjímaní a modlitbe prichádza ticho. Nie prázdnota, ale naplnené ticho – prítomnosťou Boha. V kroku Contemplatio už nesnažíme sa hovoriť ani analyzovať – iba sme.',
      'whatIsTitle': '🕊️ Čo je Contemplatio?',
      'whatIsContent1':
          'Contemplatio je spočinutie v Bohu. Nie je to úsilie, nie je to výkon – je to bytie v láske. Po tom, ako sme v lectio počúvali Slovo, v meditatio nad ním premýšľali a v oratio odpovedali, teraz zostávame v Jeho prítomnosti.',
      'whatIsContent2': 'Bez očakávaní. Bez slov. Len s túžbou byť s Ním.',
      'whatIsQuote':
          '"Ticho je jazyk Boha. Všetko ostatné je len zlá interpretácia." — Thomas Keating',
      'howToTitle': '🙌 Ako praktizovať kontempláciu?',
      'howToSteps': [
        'Sadni si alebo si kľakni do pohodlnej, ale bdelej polohy. Zatvor oči.',
        'Dýchaj pokojne. Zvoľni rytmus tela aj duše. Nechaj odísť všetky myšlienky.',
        'Niekedy zažiješ pokoj, jasnosť, útechu. Inokedy nič. Oboje je dobré.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Príprava na ticho',
          'description': 'Vytvor si prostredie pre kontempláciu',
          'content':
              'Nájdi si tiché miesto, kde ťa nič nebude rušiť. Sadni si pohodlne, ale zostanaj bdelý. Môžeš zapáliť sviečku alebo si položiť pred seba ikonu. Zatvor oči a zvoľni rytmus dychu.',
        },
        {
          'title': 'Nechaj odísť myšlienky',
          'description': 'Netlač ich preč, len ich nechaj odplávať',
          'content':
              'Keď prídu myšlienky na prácu, starosti alebo plány, netlač ich násilne preč. Jednoducho ich pozoruj ako oblaky na oblohe a nechaj ich odísť.',
        },
        {
          'title': 'Dýchaj s Bohom',
          'description': 'Použij dych ako cestu k prítomnosti',
          'content':
              'Dýchaj pokojne a prirodzene. Môžeš si pri vdychu povedať "Pane Ježišu" a pri výdychu "zmiluj sa". Nech ťa dych spája s Ním.',
        },
        {
          'title': 'Použij duchovnú kotvu',
          'description': 'Pomôcky na udržanie pozornosti',
          'content':
              'Ak sa ťažko sústredíš, pomôž si: opakuj Ježišovu modlitbu, pozoruj plameň sviečky, alebo si opakuj verš, ktorý ťa oslovil.',
        },
        {
          'title': 'Jednoducho buď',
          'description': 'Neočakávaj nič, len prijímaj prítomnosť',
          'content':
              'Stačí vedieť, že Boh je tu a ty si s Ním. Aj keď necítiš nič výnimočné, kontemplácia sa deje. Láska nemusí byť vždy cítená, ale je vždy prítomná.',
        },
      ],
      'exampleTitle': '📝 Príklad kontemplácie',
      'exampleVerse': '"Zotrvávajte vo mne a ja vo vás." (Jn 15,4)',
      'exampleSteps': [
        'Zatvorím oči a dýcham pokojne. Nechám odísť všetky myšlienky.',
        'Jednoducho som tu - s Bohom. Neočakávam nič zvláštne.',
        'Ak sa mi mysle zatúlajú, jemne si poviem: "Si tu, Pane" a vraciam sa k prítomnosti.',
        'Zostanem tak 5-10 minút v jednoduchom bytí s Ním.',
      ],
      'exampleSummary':
          'Možno necítim nič výnimočné. Ale viem, že On je tu. A to stačí.',
      'closingTitle': '🔜 Pripravený premeniť svoju modlitbu na skutok?',
      'closingText':
          'Z kontemplácie pramení posledný krok Lectio Divina – ACTIO, kde sa Slovo premieňa na život. Ale ešte chvíľu zostaň... v tichu. V Božej blízkosti. V láske.',
      'closingQuote': '"Zotrvávajte vo mne a ja vo vás." (Jn 15,4)',
      'back': 'Oratio',
      'next': 'Actio',
    },
    'actio': {
      'stepIndicator': 'Krok 6 zo 6',
      'stepTitle': '🕊️ ACTIO – Žiť Božie slovo',
      'quoteText':
          '"Buďte uskutočňovateľmi slova, a nie len poslucháčmi, ktorí klamú sami seba."',
      'quoteReference': 'Jak 1,22',
      'introParagraph':
          'Lectio Divina nekončí v tichu kontemplácie. Slovo, ktoré sme počuli, nad ktorým sme rozjímali, na ktoré sme odpovedali modlitbou a v ktorom sme spočinuli – teraz chce vstúpiť do nášho každodenného života.',
      'whatIsTitle': '🌱 Čo je Actio?',
      'whatIsContent':
          'Actio je krok, v ktorom sa Slovo stáva skutkom. Nie veľkým dramatickým gestom, ale tichým rozhodnutím žiť podľa toho, čo sme prijali od Boha.',
      'whatIsQuote':
          '"Actio je odpoveď na otázku: Ako budem dnes žiť to, čo mi Boh povedal?"',
      'howToTitle': '🌍 Actio v každodennom živote',
      'howToSteps': [
        'Vzťahy: Odpustiť, pochopiť, vypočuť. Nereagovať automaticky, ale s milosťou.',
        'Práca: Robiť veci poctivo. Slúžiť bez očakávania odmeny. Vidieť v práci službu.',
        'Ticho: Zachovať si vnútorný pokoj. Nevstupovať do zbytočných sporov.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Pomenuj jeden konkrétny krok',
          'description': 'Čo konkrétne dnes urobíš?',
          'content':
              'Po Lectio Divina si polož otázku: Čo konkrétne dnes môžem urobiť na základe toho, čo mi Boh povedal? Stačí jedno malé rozhodnutie.',
        },
        {
          'title': 'Zapíš si záväzok',
          'description': 'Písomný záväzok pomáha vytrvať',
          'content':
              'Zapíš si do denníka: „Dnes budem..." Napríklad: „Dnes sa nebudem sťažovať" alebo „Dnes poviem niekomu niečo pekné".',
        },
        {
          'title': 'Vráť sa k Slovu počas dňa',
          'description': 'Opakuj si slovo, ktoré ťa oslovilo',
          'content':
              'Počas dňa si niekoľkokrát pripomeň slovo z Lectio Divina. Môžeš si ho napísať na papierik alebo nastaviť si pripomienku.',
        },
        {
          'title': 'Zdieľaj s niekým',
          'description': 'Povedz blízkemu, čo ti Boh povedal',
          'content':
              'Povedz manželke, priateľovi alebo duchovnému sprievodcovi, čo ti Boh povedal. Zdieľanie pomáha prehĺbiť skúsenosť.',
        },
        {
          'title': 'Večerné spytovanie',
          'description': 'Večer zhodnoť, ako sa ti darilo',
          'content':
              'Pred spaním sa opýtaj: Podarilo sa mi žiť podľa Slova? Kde áno? Kde nie? Nesuď sa – len pozoruj. A začni zajtra znova.',
        },
      ],
      'exampleTitle': '📝 Príklad Actio',
      'exampleVerse': 'Po celej Lectio Divina so Slovom "Neboj sa"',
      'exampleSteps': [
        'Ráno: Zobudím sa a prvá myšlienka je: „Neboj sa." Zhlboka sa nadýchnem a odovzdám deň Bohu.',
        'V práci: Pred pohovorom si poviem: „Boh je so mnou." Namiesto paniky sa sústredím na prítomný okamih.',
        'Večer: Zapíšem si: „Dnes som sa nebál. Nie preto, že som bol odvážny, ale preto, že som dôveroval."',
        'Pred spaním: Ďakujem Bohu za dnešný deň. Opakujem si: „Neboj sa." A zaspávam v pokoji.',
      ],
      'exampleSummary':
          'Actio nie je o dokonalosti. Je to o vernosti. O malých krokoch. O živote, ktorý sa pomaly premieňa zvnútra von.',
      'closingTitle': '🌟 Záver Lectio Divina',
      'closingText':
          'Prešli ste všetkými krokmi Lectio Divina. Silencio – ticho, ktoré otvára srdce. Lectio – čítanie, ktoré počúva. Meditatio – rozjímanie, ktoré hĺbi. Oratio – modlitba, ktorá odpovedá. Contemplatio – kontemplácia, ktorá spočíva. A teraz Actio – život, ktorý premieňa.',
      'closingQuote':
          '"Nech je vaše svetlo tak pred ľuďmi, aby videli vaše dobré skutky a oslavovali vášho Otca, ktorý je na nebesiach." (Mt 5,16)',
      'back': 'Contemplatio',
      'backToOverview': 'Späť na prehľad',
    },
  };

  // ============================================================
  // CZECH (CZ)
  // ============================================================
  static const Map<String, Map<String, dynamic>> _cz = {
    'silencio': {
      'stepIndicator': 'Krok 1 ze 6',
      'stepTitle': '🤫 SILENCIO – Ticho',
      'quoteText': '"A po ohni hlas tichého vánku."',
      'quoteReference': '1 Kr 19,12',
      'introParagraph':
          'Silencio je první a nejdůležitější krok Lectio Divina. Není to jen příprava – je to brána. Bez ticha se Slovo nemůže usadit. Bez ticha zůstává čtení jen čtením.',
      'whatIsTitle': '🔑 Proč ticho?',
      'whatIsContent1':
          'Žijeme v neustálém hluku – notifikace, obrazy, očekávání. Naše vědomí je roztříštěné na krátké úseky pozornosti.',
      'whatIsContent2':
          'Blaise Pascal napsal, že celé neštěstí člověka pramení z jeho neschopnosti zůstat tiše ve svém pokoji. V tichu se nemůžeš skrýt.',
      'whatIsQuote': 'Bůh nezvyšuje hlas. Bůh čeká, až ztichneš.',
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Praktická brána do Silencia',
          'description': 'Posaď se stabilně a důstojně',
          'content':
              'Posaď se stabilně a důstojně. Páteř vzpřímená, ale uvolněná. Několik pomalých nádechů do břicha. Vnímej pohyb dechu.',
        },
        {
          'title': 'Použij kotvu pozornosti',
          'description': 'Když mysl utíká, použij krátké slovo',
          'content':
              'Když mysl utíká, použij jedno krátké slovo jako kotvu: Ježíš. Maranatha. Jsem tu. Nebojuj s myšlenkami. Jen se tiše vrať k tomu slovu.',
        },
        {
          'title': 'Věnuj čas tichu',
          'description': 'Před otevřením Bible',
          'content':
              'Věnuj 2–5 minut čistému tichu před otevřením Bible. Ticho není něco, co máš zvládnout. Je to místo, kde tě Bůh už čeká.',
        },
        {
          'title': 'Na co si dát pozor',
          'description': 'Ticho není výkon',
          'content':
              'Ticho není výkon. Nepokoušej se ho dosáhnout silou nebo perfekcionismem. Pokud se objeví strach, neanalyzuj ho. Důvěřuj.',
        },
        {
          'title': 'Praktický krok',
          'description': '5 minut denně',
          'content':
              '5 minut denně – ráno, hned po probuzení. Bez mobilu. Bez hudby. Bez slov – jen tiché bytí. Raději věrně, než dokonale.',
        },
      ],
      'closingTitle': '🤲 Závěr kroku Silencio',
      'closingText':
          'Ticho není cíl. Je brána. Dříve než otevřeš Bibli, dříve než začneš číst nebo mluvit, zastav se. Řekni si v srdci: "Teď nic nedělám. Jsem tu pro tebe, Pane."',
      'closingQuote':
          'Říká se, že v manželství je ticho nevyhnutnou podmínkou polibku. Ne proto, že by slova byla špatná. Ale proto, že v jistém okamžiku musí ustoupit.',
      'back': 'Zpět na přehled',
      'next': 'Lectio',
    },
    'lectio': {
      'stepIndicator': 'Krok 2 ze 6',
      'stepTitle': '🕯️ LECTIO – Čtení',
      'quoteText': 'Mluv, Hospodine, tvůj služebník slyší.',
      'quoteReference': '1 Sam 3,10',
      'introParagraph':
          'Lectio je první a klíčový krok modlitby Lectio Divina. Znamená číst – ale ne jen očima. Znamená číst tak, abychom slyšeli Boží hlas, který se skrývá za slovy Písma.',
      'whatIsTitle': '🔑 Co je Lectio?',
      'whatIsContent1':
          'Lectio znamená naslouchat každému slovu pozorně, nechat je na sebe působit. V této fázi nehledáme jen význam vět, ale přítomnost Toho, kdo mluví.',
      'whatIsContent2':
          'Slovo se stává živým, když ho přijímáme s vírou, že právě dnes má Bůh pro nás osobní poselství.',
      'howToTitle': '🙏 Jak začít?',
      'howToList': [
        'Najdi si tiché místo a vhodný čas (např. ráno, večer, před spaním)',
        'Zhluboka se nadechni a utiš své myšlenky',
        'Vzývej Ducha Svatého: "Duchu Svatý, otevři mé uši i srdce, ať slyším, co mi chceš říct."',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Příprava na čtení',
          'description': 'Vytvoř si prostředí pro setkání s Bohem',
          'content':
              'Najdi si tiché místo bez rušivých vlivů. Připrav si Bibli nebo aplikaci v mobilu.',
        },
        {
          'title': 'Výběr textu',
          'description': 'Vyber si krátký, ale výstižný úryvek',
          'content':
              'Začni s 3–5 verši. Můžeš použít denní evangelium, žalm nebo text podle tématu. Důležitější než množství je kvalita soustředěného čtení.',
        },
        {
          'title': 'Pozorné čtení',
          'description': 'Čti pomalu a s pozorností',
          'content':
              'Přečti text třikrát: poprvé pro celkový dojem, podruhé pozorně každé slovo, potřetí vnímej, co tě oslovuje. Představ si, že Ježíš sedí vedle tebe a čte ti osobně.',
        },
        {
          'title': 'Vnímání srdcem',
          'description': 'Všímej si vnitřních hnutí',
          'content':
              'Naslouchej nejen rozumem, ale i srdcem. Jaké pocity v tobě text vyvolává? Přijmi vše jako součást dialogu s Bohem.',
        },
        {
          'title': 'Zaznamenání slova',
          'description': 'Zapiš si slovo nebo větu, která tě oslovila',
          'content':
              'Pokud tě něco zvlášť osloví – slovo, věta, obraz – zapiš si to. Tato myšlenka tě může provázet celý den.',
        },
      ],
      'exampleTitle': '📝 Příklad praktického čtení',
      'exampleVerse':
          'Vyberu si text: "Pojďte za mnou a učiním z vás rybáře lidí" (Mt 4,19)',
      'exampleSteps': [
        'První čtení: vnímám celkový kontext',
        'Druhé čtení: vnímám slovo „pojďte" – je to pozvání, ne rozkaz',
        'Třetí čtení: rezonuje „za mnou" – kam mě Ježíš volá?',
      ],
      'exampleSummary':
          'Zastavím se u slova „pojďte" a opakuji si ho. Cítím, že mě Bůh zve blíž k sobě.',
      'closingTitle': '🤲 Závěr kroku Lectio',
      'closingText':
          'Po přečtení zůstaň chvíli v tichu. Nech Slovo v sobě doznít. Až ucítíš, že tě něco oslovilo, můžeš přejít k dalšímu kroku: Meditatio – rozjímání.',
      'closingQuote':
          '"Slovo je jako semínko. Čtením ho zaséváme. Rozjímáním zaléváme. Modlitbou ho necháváme růst. Kontemplací v něm přebýváme."',
      'back': 'Silencio',
      'next': 'Meditatio',
    },
    'meditatio': {
      'stepIndicator': 'Krok 3 ze 6',
      'stepTitle': '💭 MEDITATIO – Rozjímání',
      'quoteText':
          'Veškeré Písmo pochází od Boha a je užitečné k učení, k usvědčování, k napravování a k výchově ve spravedlnosti.',
      'quoteReference': '2 Tim 3,16',
      'introParagraph':
          'Poté, co jsme Boží slovo četli a přijali do srdce, přichází čas ho „přežvykovat" – nechat ho v nás uzrát, rozvinout jeho smysl.',
      'whatIsTitle': '🔍 Co je Meditatio?',
      'whatIsContent1':
          'Meditatio je tiché, soustředěné rozjímání. Není to intelektuální analýza, ale naslouchání srdcem.',
      'whatIsContent2':
          'Jako když člověk přežvykuje potravu, aby z ní získal všechnu výživu – tak i v této fázi necháváme Slovo proniknout naše myšlenky, pocity a duši.',
      'whatIsQuote':
          '"Boží slovo je chléb života. Nech ho proniknout do svého nitra – ne jako informaci, ale jako výživu."',
      'howToTitle': '🧠 Jak praktikovat rozjímání?',
      'howToSteps': [
        'Zůstaň u toho slova, věty nebo obrazu, který tě oslovil při čtení (Lectio).',
        'Opakuj si ho pomalu v mysli – jako bys ho znovu ochutnával.',
        'Vnímej, co se v tobě děje: pocity, myšlenky, pozvání, výzvy, světlo.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Opakuj si slovo',
          'description': 'Zůstaň u slova, které tě oslovilo v Lectio',
          'content':
              'Vezmi si slovo z předchozího čtení a opakuj si ho v mysli. Ne mechanicky, ale jako když vychutnáváš dobré jídlo.',
        },
        {
          'title': 'Polož si otázky',
          'description': 'Dva klíčové směry rozjímání',
          'content':
              'Zeptej se sám sebe: 1) Co mi tento text říká o Bohu? 2) Co mi říká o mně a mém životě dnes?',
        },
        {
          'title': 'Hledej souvislosti',
          'description': 'Propoj text s biblickým kontextem',
          'content':
              'Pokud ti slovo připomíná jinou část Bible, najdi si ji. Nejde o studium – ale o hlubší naslouchání.',
        },
        {
          'title': 'Zůstaň v tichu',
          'description': 'Dej Slovu prostor dozrát',
          'content':
              'Po rozjímání se hned neposouvej dál. Zůstaň chvíli v tichu jako Maria, která „uchovávala ta slova ve svém srdci".',
        },
        {
          'title': 'Zapiš si postřehy',
          'description': 'Zachyť ovoce rozjímání',
          'content':
              'Zapiš si do deníku: slovo, které tě oslovilo, své pocity, odpovědi na otázky, osobní postřehy.',
        },
      ],
      'exampleTitle': '📝 Příklad rozjímání',
      'exampleVerse': 'Slovo, které mě oslovilo: "Neboj se" (Lk 1,30)',
      'exampleSteps': [
        'Co mi říká o Bohu? Bůh vidí můj strach a chce mě utišit. Je laskavý a starostlivý.',
        'Co mi říká o mně? Mám právo mít strach, ale nemusím v něm zůstat. Bůh mě zve k důvěře.',
      ],
      'exampleSummary':
          'Dnes mám strach z pracovního pohovoru. Bůh mi říká "neboj se" – ne proto, že by se nic nestalo, ale protože On je se mnou.',
      'closingTitle': '🕯️ Buď v tichu a naslouchej',
      'closingText':
          'Po odpovědích hned nemluv dál. Zůstaň chvíli v tichu. Nech Slovo „klíčit" – jako semínko potřebuje čas v zemi.',
      'closingQuote':
          '"Maria uchovávala všechna ta slova ve svém srdci." (Lk 2,19)',
      'back': 'Lectio',
      'next': 'Oratio',
    },
    'oratio': {
      'stepIndicator': 'Krok 4 ze 6',
      'stepTitle': '🙏 ORATIO – Modlitba',
      'quoteText':
          '"Toto je naše důvěra v Něho: že nás slyší, když prosíme o něco podle Jeho vůle."',
      'quoteReference': '1 Jan 5,14',
      'introParagraph':
          'Po čtení a rozjímání přichází přirozený a krásný krok: odpověď Bohu. Ve fázi Oratio již nehovorí jen Bůh nám – nyní jsme to my, kdo hovorí Jemu.',
      'whatIsTitle': '💬 Co je Oratio?',
      'whatIsContent':
          'Oratio je modlitba jako odpověď na to, co jsi slyšel a pochopil. Není to recitace naučených vět, ale upřímný dialog.',
      'whatIsQuote':
          'Tvá modlitba není přednes. Je to odpověď milujícímu Bohu, který tě nejprve poslouchal.',
      'howToTitle': '🧎 Jak se modlit v této fázi?',
      'howToSteps': [
        'Vycházej ze Slova, které jsi přijal. Neodděluj se od lectio a meditatio.',
        'Buď upřímný a přirozený. Modli se svými vlastními slovy.',
        'Hovoř, jako bys skutečně stál před Bohem. A zároveň: poslouchej mezi řádky.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Vycházej ze Slova',
          'description': 'Modli se na základě toho, co tě oslovilo',
          'content':
              'Neodděluj modlitbu od předcházejícího čtení a rozjímání. Použij slova, věty nebo obrazy, které tě oslovily.',
        },
        {
          'title': 'Buď upřímný',
          'description': 'Modli se svými vlastními slovy',
          'content':
              'Nerecituj naučené modlitby. Hovoř Bohu upřímně, jako by seděl vedle tebe.',
        },
        {
          'title': 'Zkus různé formy',
          'description': 'Modlitba nemusí být jen slovní',
          'content':
              'Kromě mluvení můžeš modlitbu vyjádřit: psaním do deníku, kreslením, zpěvem. Někdy je nejkrásnější modlitbou jen tiché sedění v Boží přítomnosti.',
        },
        {
          'title': 'Přizpůsob se Božímu obrazu',
          'description': 'Modli se podle toho, jak tě Bůh oslovil',
          'content':
              'Pokud jsi v rozjímání vnímal Boha jako milujícího Otce, modli se s důvěrou dítěte.',
        },
        {
          'title': 'Ukonči v tichu',
          'description': 'Po modlitbě se ztich pro kontemplaci',
          'content':
              'Když jsi řekl Bohu vše, co máš na srdci, nespěchej odejít. Zůstaň ještě chvíli v jeho přítomnosti.',
        },
      ],
      'exampleTitle': '📝 Příklad modlitby Oratio',
      'exampleVerse': 'Slovo z rozjímání: "Neboj se, Bůh je s tebou" (Lk 1,30)',
      'exampleSteps': [
        '"Pane, děkuji Ti za toto slovo. Vím, že mám strach z toho pohovoru zítra."',
        '"Pomoz mi důvěřovat Ti více než svému strachu. Dej mi pokoj, který přichází od Tebe."',
        '"Děkuji Ti, že mě znáš a staráš se o mě. Odevzdávám Ti svůj strach a přijímám Tvou lásku."',
      ],
      'exampleSummary': '(Potom zůstanu chvíli v tichu...)',
      'closingTitle': '🕯️ Závěr modlitby',
      'closingText':
          'Po modlitbě se znovu ztich. Jako když milovaný člověk odpoví, a potom se oba jen dívají jeden druhému do očí – bez slov. Vstupujeme do kontemplace.',
      'closingQuote':
          '"Modlitba není proto, abychom změnili Boha, ale aby Bůh změnil nás." – sv. Augustin',
      'back': 'Meditatio',
      'next': 'Contemplatio',
    },
    'contemplatio': {
      'stepIndicator': 'Krok 5 ze 6',
      'stepTitle': '🌿 CONTEMPLATIO – Kontemplace',
      'quoteText':
          '"Ukaž mi svou tvář, dej mi slyšet tvůj hlas, neboť tvůj hlas je sladký a tvá tvář je půvabná."',
      'quoteReference': 'Píseň písní 2,14',
      'introParagraph':
          'Po čtení, rozjímání a modlitbě přichází ticho. Ne prázdnota, ale naplněné ticho – přítomností Boha.',
      'whatIsTitle': '🕊️ Co je Contemplatio?',
      'whatIsContent1':
          'Contemplatio je spočinutí v Bohu. Není to úsilí, není to výkon – je to bytí v lásce.',
      'whatIsContent2': 'Bez očekávání. Bez slov. Jen s touhou být s Ním.',
      'whatIsQuote':
          '"Ticho je jazyk Boha. Vše ostatní je jen špatná interpretace." — Thomas Keating',
      'howToTitle': '🙌 Jak praktikovat kontemplaci?',
      'howToSteps': [
        'Posaď se nebo poklekni do pohodlné, ale bdělé polohy. Zavři oči.',
        'Dýchej klidně. Zpomal rytmus těla i duše. Nech odejít všechny myšlenky.',
        'Někdy zažiješ pokoj, jasnost, útěchu. Jindy nic. Obojí je dobré.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Příprava na ticho',
          'description': 'Vytvoř si prostředí pro kontemplaci',
          'content':
              'Najdi si tiché místo. Posaď se pohodlně, ale zůstaň bdělý. Můžeš zapálit svíčku nebo si položit před sebe ikonu.',
        },
        {
          'title': 'Nech odejít myšlenky',
          'description': 'Netlač je pryč, jen je nech odplout',
          'content':
              'Když přijdou myšlenky, pozoruj je jako oblaka na obloze a nech je odejít. Jemně se vrať k přítomnosti Boha.',
        },
        {
          'title': 'Dýchej s Bohem',
          'description': 'Použij dech jako cestu k přítomnosti',
          'content':
              'Dýchej klidně a přirozeně. Při nádechu si řekni "Pane Ježíši" a při výdechu "smiluj se".',
        },
        {
          'title': 'Použij duchovní kotvu',
          'description': 'Pomůcky pro udržení pozornosti',
          'content':
              'Pokud se těžko soustředíš, opakuj Ježíšovu modlitbu, pozoruj plamen svíčky, opakuj si verš, který tě oslovil.',
        },
        {
          'title': 'Prostě buď',
          'description': 'Neočekávej nic, jen přijímej přítomnost',
          'content':
              'Stačí vědět, že Bůh je tu a ty jsi s Ním. I když necítíš nic výjimečného, kontemplace se děje.',
        },
      ],
      'exampleTitle': '📝 Příklad kontemplace',
      'exampleVerse': '"Zůstaňte ve mně a já ve vás." (Jan 15,4)',
      'exampleSteps': [
        'Zavřu oči a dýchám klidně. Nechám odejít všechny myšlenky.',
        'Prostě jsem tu – s Bohem. Neočekávám nic zvláštního.',
        'Pokud se mysl zatoulá, jemně si řeknu: "Jsi tu, Pane" a vracím se.',
        'Zůstanu tak 5–10 minut v jednoduchém bytí s Ním.',
      ],
      'exampleSummary':
          'Možná necítím nic výjimečného. Ale vím, že On je tu. A to stačí.',
      'closingTitle': '🔜 Připraven proměnit svou modlitbu ve skutek?',
      'closingText':
          'Z kontemplace pramení poslední krok Lectio Divina – ACTIO, kde se Slovo proměňuje v život.',
      'closingQuote': '"Zůstaňte ve mně a já ve vás." (Jan 15,4)',
      'back': 'Oratio',
      'next': 'Actio',
    },
    'actio': {
      'stepIndicator': 'Krok 6 ze 6',
      'stepTitle': '🕊️ ACTIO – Žít Boží slovo',
      'quoteText':
          '"Buďte těmi, kdo slovo uskutečňují, ne jen těmi, kdo ho slyší a klamou sami sebe."',
      'quoteReference': 'Jak 1,22',
      'introParagraph':
          'Lectio Divina nekončí v tichu kontemplace. Slovo, které jsme slyšeli, nad kterým jsme rozjímali, na které jsme odpověděli modlitbou – teraz chce vstoupit do našeho každodenního života.',
      'whatIsTitle': '🌱 Co je Actio?',
      'whatIsContent':
          'Actio je krok, ve kterém se Slovo stává skutkem. Ne velkým dramatickým gestem, ale tichým rozhodnutím žít podle toho, co jsme přijali od Boha.',
      'whatIsQuote':
          '"Actio je odpověď na otázku: Jak budu dnes žít to, co mi Bůh řekl?"',
      'howToTitle': '🌍 Actio v každodenním životě',
      'howToSteps': [
        'Vztahy: Odpustit, pochopit, vyslechnout. Nereagovat automaticky, ale s milostí.',
        'Práce: Dělat věci poctivě. Sloužit bez očekávání odměny.',
        'Ticho: Uchovat si vnitřní pokoj. Nevstupovat do zbytečných sporů.',
      ],
      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Pojmenuj jeden konkrétní krok',
          'description': 'Co konkrétně dnes uděláš?',
          'content':
              'Po Lectio Divina si polož otázku: Co konkrétně dnes mohu udělat na základě toho, co mi Bůh řekl?',
        },
        {
          'title': 'Zapiš si závazek',
          'description': 'Písemný závazek pomáhá vytrvat',
          'content':
              'Zapiš si do deníku: „Dnes budu..." Například: „Dnes si nebudu stěžovat" nebo „Dnes řeknu někomu něco hezkého".',
        },
        {
          'title': 'Vrať se ke Slovu během dne',
          'description': 'Opakuj si slovo, které tě oslovilo',
          'content':
              'Během dne si několikrát připomeň slovo z Lectio Divina. Můžeš si ho napsat na papírek nebo nastavit připomínku.',
        },
        {
          'title': 'Sdílej s někým',
          'description': 'Řekni blízkému, co ti Bůh řekl',
          'content':
              'Řekni manželce, příteli nebo duchovnímu průvodci, co ti Bůh řekl. Sdílení pomáhá prohloubit zkušenost.',
        },
        {
          'title': 'Večerní zpytování',
          'description': 'Večer zhodnoť, jak se ti dařilo',
          'content':
              'Před spaním se zeptej: Podařilo se mi žít podle Slova? Kde ano? Kde ne? Nesuď se – jen pozoruj. A začni zítra znovu.',
        },
      ],
      'exampleTitle': '📝 Příklad Actio',
      'exampleVerse': 'Po celé Lectio Divina se Slovem "Neboj se"',
      'exampleSteps': [
        'Ráno: Probudím se a první myšlenka je: „Neboj se." Nadechnu se a odevzdám den Bohu.',
        'V práci: Před pohovorem si řeknu: „Bůh je se mnou."',
        'Večer: Zapíšu si: „Dnes jsem se nebál. Ne proto, že jsem byl statečný, ale proto, že jsem důvěřoval."',
        'Před spaním: Děkuji Bohu za dnešní den. Opakuji si: „Neboj se." A usínám v klidu.',
      ],
      'exampleSummary':
          'Actio není o dokonalosti. Je to o věrnosti. O malých krocích.',
      'closingTitle': '🌟 Závěr Lectio Divina',
      'closingText':
          'Prošli jste všemi kroky Lectio Divina. Silencio – ticho, které otvírá srdce. Lectio – čtení, které naslouchá. Meditatio – rozjímání, které prohlubuje. Oratio – modlitba, která odpovídá. Contemplatio – kontemplace, která spočívá. A nyní Actio – život, který proměňuje.',
      'closingQuote':
          '"Ať tak svítí vaše světlo před lidmi, aby viděli vaše dobré skutky a oslavovali vašeho Otce v nebesích." (Mt 5,16)',
      'back': 'Contemplatio',
      'backToOverview': 'Zpět na přehled',
    },
  };

  // ============================================================
  // ENGLISH (EN)
  // ============================================================
  static const Map<String, Map<String, dynamic>> _en = {
    'silencio': {
      'stepIndicator': 'Step 1 of 6',
      'stepTitle': '🤫 SILENCIO – Silence',
      'quoteText': '"And after the fire, a still small voice."',
      'quoteReference': '1 Kings 19:12',
      'introParagraph':
          'Silencio is the first and most important step of Lectio Divina. It is not just preparation – it is the gateway. Without silence, the Word cannot settle. Without silence, reading remains just reading.',
      'whatIsTitle': '🔑 Why silence?',
      'whatIsContent1':
          'We live in constant noise – notifications, images, expectations. Our awareness is fragmented into short bursts of attention. The noise that surrounds us is not just sound. It is ontological – it shapes who we are.',
      'whatIsContent2':
          'Blaise Pascal wrote that all of humanity\'s misfortunes stem from one thing: the inability to sit quietly in a room. In silence, you cannot hide.',
      'whatIsQuote':
          'God does not raise His voice. God waits until you become silent.',
      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'A practical gateway to Silencio',
          'description': 'Sit stably and with dignity',
          'content':
              'Sit stably and with dignity. Spine upright but relaxed. Hands resting peacefully. Eyes closed or gently half-open. A few slow breaths into the belly.',
        },
        {
          'title': 'Use an anchor word',
          'description': 'When the mind wanders, use a short word',
          'content':
              'When the mind wanders, use one short word as an anchor: Jesus. Maranatha. I am here. Don\'t fight your thoughts. Just gently return to that word.',
        },
        {
          'title': 'Dedicate time to silence',
          'description': 'Before opening the Bible',
          'content':
              'Dedicate 2–5 minutes of pure silence before opening the Bible. Silence is not something you need to master. It is a place where God is already waiting for you.',
        },
        {
          'title': 'What to watch out for',
          'description': 'Silence is not a performance',
          'content':
              'Silence is not a performance. Don\'t try to achieve it through force or perfectionism. If fear arises, don\'t analyze it. Trust. Silence should be a place of rest, not a battlefield.',
        },
        {
          'title': 'A practical step',
          'description': '5 minutes daily',
          'content':
              '5 minutes daily – in the morning, right after waking up. Without your phone. Without music. Without words – just silent being. Faithfully rather than perfectly.',
        },
      ],
      'closingTitle': '🤲 Closing the Silencio step',
      'closingText':
          'Silence is not the goal. It is the gateway. Before you open the Bible, before you begin to read or speak, stop. Say in your heart: "Now I do nothing. I am here for You, Lord."',
      'closingQuote':
          'It is said that in marriage, silence is the essential condition for a kiss. Not because words are bad. But because at a certain moment they must step aside.',
      'back': 'Back to overview',
      'next': 'Lectio',
    },
    'lectio': {
      'stepIndicator': 'Step 2 of 6',
      'stepTitle': '🕯️ LECTIO – Reading',
      'quoteText': 'Speak, Lord, for your servant is listening.',
      'quoteReference': '1 Sam 3:10',
      'introParagraph':
          'Lectio is the first and foundational step of Lectio Divina. It means to read – but not just with the eyes. It means to read in a way that lets us hear the voice of God hidden behind the words of Scripture.',
      'whatIsTitle': '🔑 What is Lectio?',
      'whatIsContent1':
          'Lectio invites us to listen attentively to each word, allowing it to sink in. In this step, we don\'t just seek meaning – we seek the presence of the One who speaks.',
      'whatIsContent2':
          'The Word becomes alive when we receive it with an open heart, trusting that God has a personal message for us today.',
      'howToTitle': '🙏 How to begin?',
      'howToList': [
        'Find a quiet space and a good time (e.g. morning, evening, before bed)',
        'Take a deep breath and quiet your thoughts',
        'Invoke the Holy Spirit: "Holy Spirit, open my ears and heart to hear what You want to say."',
      ],
      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'Preparing to read',
          'description': 'Create space to meet with God',
          'content':
              'Find a quiet place free from distractions. What matters is that you feel calm and safe. Have a Bible or a Bible app ready.',
        },
        {
          'title': 'Choosing a passage',
          'description': 'Pick a short but meaningful text',
          'content':
              'Start with 3–5 verses. Use the daily Gospel, a Psalm, or a passage based on a theme. Quality of attention is more important than quantity.',
        },
        {
          'title': 'Attentive reading',
          'description': 'Read slowly and mindfully',
          'content':
              'Read the text three times: first to grasp the context, second to focus on each word, and third to notice what moves you. Imagine Jesus reading it to you personally.',
        },
        {
          'title': 'Listening with the heart',
          'description': 'Pay attention to your feelings and movements',
          'content':
              'Listen not only with your mind but also your heart. What feelings arise? Accept everything as part of your dialogue with God.',
        },
        {
          'title': 'Noting the word',
          'description': 'Write down a word or phrase that touched you',
          'content':
              'If something stood out – a word, phrase, or image – write it down. Let that word accompany you throughout the day.',
        },
      ],
      'exampleTitle': '📝 A practical example',
      'exampleVerse':
          'I choose the text: "Come, follow me, and I will make you fishers of people." (Mt 4:19)',
      'exampleSteps': [
        'First reading: I focus on the context as a whole',
        'Second reading: The word "come" speaks to me – it\'s an invitation, not a command',
        'Third reading: "Follow me" stirs my heart – where is Jesus calling me?',
      ],
      'exampleSummary':
          'I pause at the word "come" and repeat it. I feel God is inviting me closer.',
      'closingTitle': '🤲 Closing the Lectio step',
      'closingText':
          'After reading, remain in silence for a moment. Let the Word echo within you. Once you sense that something has touched you – you may move to the next step: Meditatio.',
      'closingQuote':
          '"The Word is like a seed. Reading sows it. Meditation waters it. Prayer lets it grow. Contemplation dwells in it."',
      'back': 'Silencio',
      'next': 'Meditatio',
    },
    'meditatio': {
      'stepIndicator': 'Step 3 of 6',
      'stepTitle': '💭 MEDITATIO – Meditation',
      'quoteText':
          'All Scripture is inspired by God and is useful for teaching, for refutation, for correction, and for training in righteousness.',
      'quoteReference': '2 Tim 3:16',
      'introParagraph':
          'After reading and receiving the Word into our hearts, it is time to "chew" it – to let it mature within us and unfold its meaning.',
      'whatIsTitle': '🔍 What is Meditatio?',
      'whatIsContent1':
          'Meditatio is quiet, attentive reflection. It\'s not an intellectual analysis, but a listening with the heart.',
      'whatIsContent2':
          'Just like we chew food slowly to draw all nourishment from it – in this phase, we let the Word penetrate our thoughts, feelings, and soul.',
      'whatIsQuote':
          '"God\'s Word is the bread of life. Let it enter your innermost being – not as information, but as nourishment."',
      'howToTitle': '🧠 How to practice meditation?',
      'howToSteps': [
        'Stay with the word, phrase, or image that touched you during the reading (Lectio).',
        'Repeat it slowly in your mind – as if you were savoring it again and again.',
        'Notice what stirs in you: feelings, thoughts, invitations, challenges, light.',
      ],
      'practicalTipsTitle': '✍️ Practical tips',
      'practicalTips': [
        {
          'title': 'Repeat the Word',
          'description': 'Stay with the word that touched you in Lectio',
          'content':
              'Take the word from the reading and repeat it in your mind. Not mechanically, but like savoring a delicious meal.',
        },
        {
          'title': 'Ask questions',
          'description': 'Two essential directions for meditation',
          'content':
              'Ask yourself: 1) What does this text say about God? 2) What does it say about me and my life today?',
        },
        {
          'title': 'Look for connections',
          'description': 'Link the text with the broader biblical context',
          'content':
              'If a word reminds you of another Scripture, look it up. It\'s not about studying, but deeper listening.',
        },
        {
          'title': 'Remain in silence',
          'description': 'Give the Word space to grow',
          'content':
              'After meditating, don\'t rush ahead. Remain in silence, like Mary who "kept all these things in her heart."',
        },
        {
          'title': 'Write down observations',
          'description': 'Preserve the fruit of meditation',
          'content':
              'Jot down in a journal: the word that spoke to you, your feelings, responses, personal insights.',
        },
      ],
      'exampleTitle': '📝 Example of meditation',
      'exampleVerse': 'Word that touched me: "Do not be afraid" (Lk 1:30)',
      'exampleSteps': [
        'What does it say about God? He sees my fear and wants to calm me. He is kind and caring.',
        'What does it say about me? It\'s okay to be afraid, but I don\'t have to stay in fear. God invites me to trust.',
      ],
      'exampleSummary':
          'Today I\'m afraid of a job interview. God tells me "do not be afraid" – not because nothing will happen, but because He is with me.',
      'closingTitle': '🕯️ Be silent and listen',
      'closingText':
          'Don\'t speak immediately after the answers. Stay in silence. Let the Word "take root" – just as a seed needs time in the soil.',
      'closingQuote': '"Mary kept all these things in her heart." (Lk 2:19)',
      'back': 'Lectio',
      'next': 'Oratio',
    },
    'oratio': {
      'stepIndicator': 'Step 4 of 6',
      'stepTitle': '🙏 ORATIO – Prayer',
      'quoteText':
          '"This is the confidence we have in approaching God: that if we ask anything according to his will, he hears us."',
      'quoteReference': '1 John 5:14',
      'introParagraph':
          'After reading and meditation comes a natural and beautiful step: responding to God. In the Oratio phase, it\'s no longer just God speaking to us – now we are the ones speaking to Him.',
      'whatIsTitle': '💬 What is Oratio?',
      'whatIsContent':
          'Oratio is prayer as a response to what you have heard and understood. It\'s not reciting memorized sentences, but sincere dialogue.',
      'whatIsQuote':
          'Your prayer is not a performance. It\'s a response to the loving God who first listened to you.',
      'howToTitle': '🧎 How to pray in this phase?',
      'howToSteps': [
        'Start from the Word you received. Don\'t separate yourself from lectio and meditatio.',
        'Be honest and natural. Pray in your own words.',
        'Speak as if you truly stand before God. And at the same time: listen between the lines.',
      ],
      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'Start from the Word',
          'description': 'Pray based on what spoke to you',
          'content':
              'Don\'t separate prayer from the preceding reading and meditation. Use words, sentences or images that spoke to you.',
        },
        {
          'title': 'Be honest',
          'description': 'Pray in your own words',
          'content':
              'Don\'t recite memorized prayers. Speak to God honestly, as if He sat next to you.',
        },
        {
          'title': 'Try different forms',
          'description': 'Prayer doesn\'t have to be just verbal',
          'content':
              'Besides speaking, you can express prayer through: writing, drawing, singing, dancing. Sometimes the most beautiful prayer is just sitting silently in God\'s presence.',
        },
        {
          'title': 'Adapt to God\'s image',
          'description': 'Pray according to how God spoke to you',
          'content':
              'If in meditation you perceived God as a loving Father, pray with a child\'s trust. If as a Friend, be open.',
        },
        {
          'title': 'End in silence',
          'description': 'After prayer, be quiet for contemplation',
          'content':
              'When you\'ve told God everything on your heart, don\'t hurry to leave. Stay a moment longer in His presence.',
        },
      ],
      'exampleTitle': '📝 Example of Oratio prayer',
      'exampleVerse':
          'Word from meditation: "Do not be afraid, God is with you" (Luke 1:30)',
      'exampleSteps': [
        '"Lord, thank You for this word. I know I\'m afraid of that interview tomorrow."',
        '"Help me trust You more than my fear. Give me the peace that comes from You."',
        '"Thank You for knowing me and caring for me. I surrender my fear to You."',
      ],
      'exampleSummary': '(Then I remain in silence for a while...)',
      'closingTitle': '🕯️ Closing the prayer',
      'closingText':
          'After prayer, be quiet again. Like when a beloved person responds, and then both just look into each other\'s eyes – without words. We enter contemplation.',
      'closingQuote':
          '"Prayer is not to change God, but for God to change us." – St. Augustine',
      'back': 'Meditatio',
      'next': 'Contemplatio',
    },
    'contemplatio': {
      'stepIndicator': 'Step 5 of 6',
      'stepTitle': '🌿 CONTEMPLATIO – Contemplation',
      'quoteText':
          '"Show me your face, let me hear your voice; for your voice is lovely and your face is beautiful."',
      'quoteReference': 'Song of Songs 2:14',
      'introParagraph':
          'After reading, meditation, and prayer comes silence. Not emptiness, but filled silence – with the presence of God.',
      'whatIsTitle': '🕊️ What is Contemplatio?',
      'whatIsContent1':
          'Contemplatio is resting in God. It is not effort, not achievement – it is being in love.',
      'whatIsContent2':
          'Without expectations. Without words. Just with the desire to be with Him.',
      'whatIsQuote':
          '"Silence is the language of God. Everything else is a bad translation." — Thomas Keating',
      'howToTitle': '🙌 How to practice contemplation?',
      'howToSteps': [
        'Sit or kneel in a comfortable but alert posture. Close your eyes.',
        'Breathe peacefully. Slow the rhythm of body and soul. Let all thoughts go.',
        'Sometimes you experience peace, clarity, consolation. Other times nothing. Both are good.',
      ],
      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'Preparing for silence',
          'description': 'Create an environment for contemplation',
          'content':
              'Find a quiet place where nothing will disturb you. Sit comfortably but stay alert. You may light a candle or place an icon before you.',
        },
        {
          'title': 'Let thoughts go',
          'description': 'Don\'t push them away, just let them float by',
          'content':
              'When thoughts about work, worries, or plans come, observe them like clouds in the sky and let them pass.',
        },
        {
          'title': 'Breathe with God',
          'description': 'Use breath as a path to presence',
          'content':
              'Breathe peacefully and naturally. You may say "Lord Jesus" on the inhale and "have mercy" on the exhale.',
        },
        {
          'title': 'Use a spiritual anchor',
          'description': 'Tools to maintain attention',
          'content':
              'If concentration is difficult, repeat the Jesus Prayer, observe a candle flame, or repeat a verse that spoke to you.',
        },
        {
          'title': 'Simply be',
          'description': 'Expect nothing, just receive presence',
          'content':
              'Just know that God is here and you are with Him. Even if you feel nothing extraordinary, contemplation is happening.',
        },
      ],
      'exampleTitle': '📝 Example of contemplation',
      'exampleVerse': '"Remain in me, and I in you." (John 15:4)',
      'exampleSteps': [
        'I close my eyes and breathe peacefully. I let all thoughts go.',
        'I am simply here – with God. I expect nothing special.',
        'If my mind wanders, I gently say: "You are here, Lord" and return.',
        'I stay like this for 5–10 minutes in simple being with Him.',
      ],
      'exampleSummary':
          'Maybe I feel nothing extraordinary. But I know He is here. And that is enough.',
      'closingTitle': '🔜 Ready to turn your prayer into action?',
      'closingText':
          'From contemplation flows the last step of Lectio Divina – ACTIO, where the Word transforms into life.',
      'closingQuote': '"Remain in me, and I in you." (John 15:4)',
      'back': 'Oratio',
      'next': 'Actio',
    },
    'actio': {
      'stepIndicator': 'Step 6 of 6',
      'stepTitle': '🕊️ ACTIO – Living God\'s Word',
      'quoteText':
          '"Be doers of the word, and not hearers only, deceiving yourselves."',
      'quoteReference': 'James 1:22',
      'introParagraph':
          'Lectio Divina does not end in the silence of contemplation. The Word we\'ve heard, reflected on, responded to in prayer, and rested in – now wants to enter our daily life.',
      'whatIsTitle': '🌱 What is Actio?',
      'whatIsContent':
          'Actio is the step where the Word becomes action. Not a grand dramatic gesture, but a quiet decision to live according to what we received from God.',
      'whatIsQuote':
          '"Actio answers the question: How will I live today what God told me?"',
      'howToTitle': '🌍 Actio in everyday life',
      'howToSteps': [
        'Relationships: Forgive, understand, listen. Respond with grace, not automatically.',
        'Work: Do things honestly. Serve without expecting reward.',
        'Silence: Maintain inner peace. Avoid unnecessary arguments.',
      ],
      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'Name one concrete step',
          'description': 'What will you specifically do today?',
          'content':
              'After Lectio Divina, ask yourself: What can I specifically do today based on what God told me? One small decision is enough.',
        },
        {
          'title': 'Write down your commitment',
          'description': 'A written commitment helps you persevere',
          'content':
              'Write in your journal: "Today I will..." For example: "Today I won\'t complain" or "Today I\'ll say something kind to someone."',
        },
        {
          'title': 'Return to the Word during the day',
          'description': 'Repeat the word that spoke to you',
          'content':
              'During the day, recall the word from Lectio Divina several times. Write it on a note or set a phone reminder.',
        },
        {
          'title': 'Share with someone',
          'description': 'Tell someone close what God told you',
          'content':
              'Tell your spouse, friend, or spiritual director what God told you. Sharing helps deepen the experience.',
        },
        {
          'title': 'Evening examination',
          'description': 'Evaluate how your day went',
          'content':
              'Before bed, ask: Did I live according to the Word? Where yes? Where not? Don\'t judge – just observe. And start again tomorrow.',
        },
      ],
      'exampleTitle': '📝 Example of Actio',
      'exampleVerse':
          'After the full Lectio Divina with the Word "Do not be afraid"',
      'exampleSteps': [
        'Morning: I wake up and my first thought is: "Do not be afraid." I breathe deeply and surrender the day to God.',
        'At work: Before the interview I say: "God is with me." Instead of panic, I focus on the present moment.',
        'Evening: I write: "Today I was not afraid. Not because I was brave, but because I trusted."',
        'Before bed: I thank God for today. I repeat: "Do not be afraid." And I fall asleep in peace.',
      ],
      'exampleSummary':
          'Actio is not about perfection. It\'s about faithfulness. About small steps.',
      'closingTitle': '🌟 Closing Lectio Divina',
      'closingText':
          'You have completed all steps of Lectio Divina. Silencio – silence that opens the heart. Lectio – reading that listens. Meditatio – meditation that deepens. Oratio – prayer that responds. Contemplatio – contemplation that rests. And now Actio – life that transforms.',
      'closingQuote':
          '"Let your light shine before others, that they may see your good deeds and glorify your Father in heaven." (Mt 5:16)',
      'back': 'Contemplatio',
      'backToOverview': 'Back to overview',
    },
  };

  // ============================================================
  // SPANISH (ES)
  // ============================================================
  static const Map<String, Map<String, dynamic>> _es = {
    'silencio': {
      'stepIndicator': 'Paso 1 de 6',
      'stepTitle': '🤫 SILENCIO – Silencio',
      'quoteText': '"Y después del fuego, un susurro suave y delicado."',
      'quoteReference': '1 Re 19,12',
      'introParagraph':
          'Silencio es el primer y más importante paso de Lectio Divina. No es solo una preparación – es la puerta. Sin silencio, la Palabra no puede asentarse.',
      'whatIsTitle': '🔑 ¿Por qué el silencio?',
      'whatIsContent1':
          'Vivimos en un ruido constante – notificaciones, imágenes, expectativas. Nuestra conciencia está fragmentada en breves intervalos de atención.',
      'whatIsContent2':
          'Blaise Pascal escribió que toda la desdicha del hombre proviene de una sola cosa: la incapacidad de quedarse quieto en una habitación.',
      'whatIsQuote':
          'Dios no levanta la voz. Dios espera hasta que tú enmudeces.',
      'practicalTipsTitle': '✍️ Consejos prácticos',
      'practicalTips': [
        {
          'title': 'Puerta práctica al Silencio',
          'description': 'Siéntate de forma estable y digna',
          'content':
              'Siéntate de forma estable y digna. Columna erguida pero relajada. Unas respiraciones lentas al abdomen. Solo percibe el movimiento.',
        },
        {
          'title': 'Usa una palabra ancla',
          'description': 'Cuando la mente se dispersa',
          'content':
              'Cuando la mente se dispersa, usa una palabra corta como ancla: Jesús. Maranatha. Aquí estoy. No luches con los pensamientos. Solo regresa suavemente.',
        },
        {
          'title': 'Dedica tiempo al silencio',
          'description': 'Antes de abrir la Biblia',
          'content':
              'Dedica 2–5 minutos de silencio puro antes de abrir la Biblia. El silencio no es algo que debas dominar. Es un lugar donde Dios ya te espera.',
        },
        {
          'title': 'A qué prestar atención',
          'description': 'El silencio no es un logro',
          'content':
              'El silencio no es un logro. No intentes alcanzarlo con fuerza o perfeccionismo. Si surge el miedo, no lo analices. Confía.',
        },
        {
          'title': 'Paso práctico',
          'description': '5 minutos al día',
          'content':
              '5 minutos al día – por la mañana, al despertar. Sin móvil. Sin música. Sin palabras – solo ser silencioso. Mejor con fidelidad que con perfección.',
        },
      ],
      'closingTitle': '🤲 Cierre del paso Silencio',
      'closingText':
          'El silencio no es el objetivo. Es la puerta. Antes de abrir la Biblia, detente. Di en tu corazón: "Ahora no hago nada. Estoy aquí para ti, Señor."',
      'closingQuote':
          'Se dice que en el matrimonio, el silencio es la condición indispensable para un beso. No porque las palabras sean malas. Sino porque en cierto momento deben retirarse.',
      'back': 'Volver al resumen',
      'next': 'Lectio',
    },
    'lectio': {
      'stepIndicator': 'Paso 2 de 6',
      'stepTitle': '🕯️ LECTIO – Lectura',
      'quoteText': 'Habla, Señor, que tu siervo escucha.',
      'quoteReference': '1 Sam 3,10',
      'introParagraph':
          'Lectio es el primer paso fundamental de la Lectio Divina. Significa leer – pero no solo con los ojos. Significa leer de tal forma que podamos escuchar la voz de Dios.',
      'whatIsTitle': '🔑 ¿Qué es Lectio?',
      'whatIsContent1':
          'Lectio nos invita a escuchar con atención cada palabra, dejando que penetre en nosotros. No solo buscamos el significado – buscamos la presencia de Aquel que habla.',
      'whatIsContent2':
          'La Palabra se vuelve viva cuando la recibimos con el corazón abierto, confiando en que Dios tiene hoy un mensaje personal para nosotros.',
      'howToTitle': '🙏 ¿Cómo comenzar?',
      'howToList': [
        'Busca un lugar tranquilo y un momento adecuado',
        'Respira profundamente y aquieta tus pensamientos',
        'Invoca al Espíritu Santo: "Espíritu Santo, abre mis oídos y mi corazón."',
      ],
      'practicalTipsTitle': '✍️ Consejos prácticos',
      'practicalTips': [
        {
          'title': 'Preparación para la lectura',
          'description': 'Crea un espacio para el encuentro con Dios',
          'content':
              'Encuentra un lugar tranquilo sin distracciones. Lo importante es sentirte en paz y seguro. Ten a mano una Biblia o una app bíblica.',
        },
        {
          'title': 'Elección del texto',
          'description': 'Elige un pasaje corto pero significativo',
          'content':
              'Empieza con 3–5 versículos. Usa el Evangelio del día, un salmo o un pasaje temático. La calidad es más importante que la cantidad.',
        },
        {
          'title': 'Lectura atenta',
          'description': 'Lee despacio y con atención',
          'content':
              'Lee el texto tres veces: la primera para comprender, la segunda para fijarte en cada palabra, y la tercera para notar lo que te toca.',
        },
        {
          'title': 'Escuchar con el corazón',
          'description': 'Atiende a tus sentimientos',
          'content':
              'Escucha no solo con la mente, sino también con el corazón. ¿Qué emociones surgen? Acepta todo como parte de tu diálogo con Dios.',
        },
        {
          'title': 'Anotar la Palabra',
          'description': 'Escribe una palabra que te haya tocado',
          'content':
              'Si algo te impactó – una palabra, frase o imagen – escríbelo. Esa palabra te acompañará durante el día.',
        },
      ],
      'exampleTitle': '📝 Ejemplo práctico',
      'exampleVerse':
          'Elijo el texto: "Vengan conmigo y los haré pescadores de hombres" (Mt 4,19)',
      'exampleSteps': [
        'Primera lectura: Me concentro en el contexto general',
        'Segunda lectura: Me llama la atención la palabra "vengan" – es una invitación',
        'Tercera lectura: "Conmigo" resuena en mí – ¿a dónde me invita Jesús?',
      ],
      'exampleSummary':
          'Me detengo en la palabra "vengan" y la repito. Siento que Dios me llama a estar más cerca.',
      'closingTitle': '🤲 Cierre del paso Lectio',
      'closingText':
          'Después de leer, permanece en silencio un momento. Deja que la Palabra resuene dentro de ti.',
      'closingQuote':
          '"La Palabra es como una semilla. Leer la siembra. Meditar la riega. Orar la hace crecer. Contemplar la habita."',
      'back': 'Silencio',
      'next': 'Meditatio',
    },
    'meditatio': {
      'stepIndicator': 'Paso 3 de 6',
      'stepTitle': '💭 MEDITATIO – Meditación',
      'quoteText':
          'Toda la Escritura está inspirada por Dios y es útil para enseñar, para reprender, para corregir y para educar en la justicia.',
      'quoteReference': '2 Tim 3,16',
      'introParagraph':
          'Después de leer y acoger la Palabra en el corazón, llega el momento de "rumiarla" – dejar que madure en nosotros.',
      'whatIsTitle': '🔍 ¿Qué es la Meditatio?',
      'whatIsContent1':
          'Meditatio es una reflexión silenciosa y atenta. No es un análisis intelectual, sino una escucha con el corazón.',
      'whatIsContent2':
          'Así como se mastica lentamente el alimento para extraer todos sus nutrientes, dejamos que la Palabra penetre nuestros pensamientos, sentimientos y alma.',
      'whatIsQuote':
          '"La Palabra de Dios es pan de vida. Déjala entrar en tu interior, no como información, sino como alimento."',
      'howToTitle': '🧠 ¿Cómo practicar la meditación?',
      'howToSteps': [
        'Permanece con la palabra, frase o imagen que resonó durante la lectura (Lectio).',
        'Repítela lentamente en tu mente, como si la saborearas una y otra vez.',
        'Observa lo que se mueve en ti: sentimientos, pensamientos, invitaciones, desafíos, luz.',
      ],
      'practicalTipsTitle': '✍️ Consejos prácticos',
      'practicalTips': [
        {
          'title': 'Repite la palabra',
          'description': 'Permanece con la palabra que te tocó en Lectio',
          'content':
              'Toma la palabra de la lectura y repítela en tu mente. No de forma mecánica, sino como quien saborea un buen plato.',
        },
        {
          'title': 'Hazte preguntas',
          'description': 'Dos direcciones clave para meditar',
          'content':
              'Pregúntate: 1) ¿Qué me dice este texto sobre Dios? 2) ¿Qué me dice sobre mí y mi vida hoy?',
        },
        {
          'title': 'Busca conexiones',
          'description': 'Relaciona el texto con otros pasajes',
          'content':
              'Si una palabra te recuerda otro pasaje bíblico, búscalo. No se trata de estudiar, sino de escuchar más profundamente.',
        },
        {
          'title': 'Permanece en silencio',
          'description': 'Dale espacio a la Palabra para que madure',
          'content':
              'Después de meditar, no sigas enseguida. Quédate un momento en silencio, como María que "guardaba todas estas cosas en su corazón".',
        },
        {
          'title': 'Escribe lo que has descubierto',
          'description': 'Guarda el fruto de tu meditación',
          'content':
              'Escribe en un diario: la palabra que te tocó, tus sentimientos, respuestas, observaciones personales.',
        },
      ],
      'exampleTitle': '📝 Ejemplo de meditación',
      'exampleVerse': 'Palabra que resuena: "No temas" (Lc 1,30)',
      'exampleSteps': [
        '¿Qué me dice sobre Dios? Dios ve mi miedo y quiere calmarme. Es bondadoso y cuidadoso.',
        '¿Qué me dice sobre mí? Tengo derecho a tener miedo, pero no debo quedarme en él.',
      ],
      'exampleSummary':
          'Hoy tengo miedo por una entrevista de trabajo. Dios me dice "no temas" – porque Él está conmigo.',
      'closingTitle': '🕯️ Permanece en silencio y escucha',
      'closingText':
          'No hables de inmediato después de meditar. Quédate un momento en silencio. Deja que la Palabra "germine".',
      'closingQuote':
          '"María guardaba todas estas cosas en su corazón." (Lc 2,19)',
      'back': 'Lectio',
      'next': 'Oratio',
    },
    'oratio': {
      'stepIndicator': 'Paso 4 de 6',
      'stepTitle': '🙏 ORATIO – Oración',
      'quoteText':
          '"Esta es la confianza que tenemos en Él: que si pedimos algo conforme a su voluntad, él nos oye."',
      'quoteReference': '1 Juan 5:14',
      'introParagraph':
          'Después de la lectura y la meditación viene un paso natural y hermoso: responder a Dios.',
      'whatIsTitle': '💬 ¿Qué es Oratio?',
      'whatIsContent':
          'Oratio es la oración como respuesta a lo que has escuchado y comprendido. No es recitar frases memorizadas, sino un diálogo sincero.',
      'whatIsQuote':
          'Tu oración no es una actuación. Es una respuesta al Dios amoroso que primero te escuchó.',
      'howToTitle': '🧎 ¿Cómo orar en esta fase?',
      'howToSteps': [
        'Parte de la Palabra que recibiste. No te separes de la lectio y la meditatio.',
        'Sé honesto y natural. Ora con tus propias palabras.',
        'Habla como si verdaderamente estuvieras ante Dios. Y al mismo tiempo: escucha entre líneas.',
      ],
      'practicalTipsTitle': '✍️ Consejos prácticos',
      'practicalTips': [
        {
          'title': 'Parte de la Palabra',
          'description': 'Ora basándote en lo que te habló',
          'content':
              'No separes la oración de la lectura y meditación precedentes. Usa palabras, frases o imágenes que te hablaron.',
        },
        {
          'title': 'Sé honesto',
          'description': 'Ora con tus propias palabras',
          'content':
              'No recites oraciones memorizadas. Habla a Dios honestamente, como si estuviera sentado a tu lado.',
        },
        {
          'title': 'Prueba diferentes formas',
          'description': 'La oración no tiene que ser solo verbal',
          'content':
              'Además de hablar, puedes expresar la oración: escribiendo, dibujando, cantando, bailando. A veces la oración más hermosa es solo sentarse en silencio.',
        },
        {
          'title': 'Adáptate a la imagen de Dios',
          'description': 'Ora según como Dios te habló',
          'content':
              'Si en la meditación percibiste a Dios como Padre amoroso, ora con la confianza de un niño.',
        },
        {
          'title': 'Termina en silencio',
          'description': 'Después de orar, quédate en silencio',
          'content':
              'Cuando le hayas dicho a Dios todo lo que tienes en tu corazón, no te apresures a irte. Quédate un momento más.',
        },
      ],
      'exampleTitle': '📝 Ejemplo de oración Oratio',
      'exampleVerse':
          'Palabra de la meditación: "No temas, Dios está contigo" (Lc 1:30)',
      'exampleSteps': [
        '"Señor, te doy gracias por esta palabra. Sé que tengo miedo de esa entrevista de mañana."',
        '"Ayúdame a confiar en Ti más que en mi miedo. Dame la paz que viene de Ti."',
        '"Te doy gracias porque me conoces y te preocupas por mí. Te entrego mi miedo."',
      ],
      'exampleSummary': '(Luego permanezco en silencio por un momento...)',
      'closingTitle': '🕯️ Cierre de la oración',
      'closingText':
          'Después de orar, quédate en silencio otra vez. Entramos en la contemplación – la siguiente fase de Lectio Divina.',
      'closingQuote':
          '"La oración no es para cambiar a Dios, sino para que Dios nos cambie." – San Agustín',
      'back': 'Meditatio',
      'next': 'Contemplatio',
    },
    'contemplatio': {
      'stepIndicator': 'Paso 5 de 6',
      'stepTitle': '🌿 CONTEMPLATIO – Contemplación',
      'quoteText':
          '"Muéstrame tu rostro, déjame oír tu voz; porque tu voz es dulce y tu rostro hermoso."',
      'quoteReference': 'Cantar de los Cantares 2,14',
      'introParagraph':
          'Después de leer, meditar y orar, llega el silencio. No vacío, sino un silencio lleno – de la presencia de Dios.',
      'whatIsTitle': '🕊️ ¿Qué es Contemplatio?',
      'whatIsContent1':
          'Contemplatio es descansar en Dios. No es esfuerzo, no es logro – es ser en amor.',
      'whatIsContent2':
          'Sin expectativas. Sin palabras. Solo con el deseo de estar con Él.',
      'whatIsQuote':
          '"El silencio es el lenguaje de Dios. Todo lo demás es una mala traducción." — Thomas Keating',
      'howToTitle': '🙌 ¿Cómo practicar la contemplación?',
      'howToSteps': [
        'Siéntate o arrodíllate en una postura cómoda pero alerta. Cierra los ojos.',
        'Respira con calma. Desacelera el ritmo del cuerpo y del alma.',
        'A veces sentirás paz, claridad, consuelo. Otras veces nada. Ambas cosas están bien.',
      ],
      'practicalTipsTitle': '✍️ Consejos prácticos',
      'practicalTips': [
        {
          'title': 'Preparación para el silencio',
          'description': 'Crea un ambiente para la contemplación',
          'content':
              'Encuentra un lugar tranquilo. Siéntate cómodamente pero con atención. Puedes encender una vela o poner un ícono frente a ti.',
        },
        {
          'title': 'Deja ir los pensamientos',
          'description': 'No los expulses, solo déjalos pasar',
          'content':
              'Cuando lleguen pensamientos, obsérvalos como nubes en el cielo y déjalos pasar. Regresa suavemente a la presencia de Dios.',
        },
        {
          'title': 'Respira con Dios',
          'description': 'Usa la respiración como camino a la presencia',
          'content':
              'Respira con calma. Puedes decir al inhalar "Señor Jesús" y al exhalar "ten piedad".',
        },
        {
          'title': 'Usa un ancla espiritual',
          'description': 'Herramientas para mantener la atención',
          'content':
              'Si te cuesta concentrarte, repite la oración de Jesús, observa la llama de una vela o repite un versículo.',
        },
        {
          'title': 'Simplemente sé',
          'description': 'No esperes nada, solo recibe la presencia',
          'content':
              'Basta saber que Dios está aquí y tú estás con Él. Aunque no sientas nada especial, la contemplación sucede.',
        },
      ],
      'exampleTitle': '📝 Ejemplo de contemplación',
      'exampleVerse': '"Permanezcan en mí, y yo en ustedes." (Jn 15,4)',
      'exampleSteps': [
        'Cierro los ojos y respiro con calma. Dejo ir todos los pensamientos.',
        'Simplemente estoy aquí – con Dios. No espero nada especial.',
        'Si mi mente divaga, suavemente digo: "Estás aquí, Señor" y regreso.',
        'Me quedo así 5–10 minutos simplemente siendo con Él.',
      ],
      'exampleSummary':
          'Quizás no siento nada extraordinario. Pero sé que Él está aquí. Y eso basta.',
      'closingTitle': '🔜 ¿Listo para convertir tu oración en acción?',
      'closingText':
          'De la contemplación nace el último paso de Lectio Divina – ACTIO, donde la Palabra se transforma en vida.',
      'closingQuote': '"Permanezcan en mí, y yo en ustedes." (Jn 15,4)',
      'back': 'Oratio',
      'next': 'Actio',
    },
    'actio': {
      'stepIndicator': 'Paso 6 de 6',
      'stepTitle': '🕊️ ACTIO – Vivir la Palabra de Dios',
      'quoteText':
          '"Sean hacedores de la Palabra, y no solo oyentes que se engañan a sí mismos."',
      'quoteReference': 'Santiago 1:22',
      'introParagraph':
          'Lectio Divina no termina en el silencio de la contemplación. La Palabra que hemos escuchado quiere entrar en nuestra vida diaria.',
      'whatIsTitle': '🌱 ¿Qué es Actio?',
      'whatIsContent':
          'Actio es el paso en el que la Palabra se convierte en acción. No un gran gesto dramático, sino una decisión silenciosa de vivir según lo que hemos recibido de Dios.',
      'whatIsQuote':
          '"Actio responde a la pregunta: ¿Cómo viviré hoy lo que Dios me dijo?"',
      'howToTitle': '🌍 Actio en la vida diaria',
      'howToSteps': [
        'Relaciones: Perdonar, comprender, escuchar. Responder con gracia.',
        'Trabajo: Hacer las cosas con honestidad. Servir sin esperar recompensa.',
        'Silencio: Mantener la paz interior. No entrar en discusiones innecesarias.',
      ],
      'practicalTipsTitle': '✍️ Consejos prácticos',
      'practicalTips': [
        {
          'title': 'Nombra un paso concreto',
          'description': '¿Qué harás específicamente hoy?',
          'content':
              'Después de Lectio Divina, pregúntate: ¿Qué puedo hacer hoy concretamente? Basta una pequeña decisión.',
        },
        {
          'title': 'Escribe tu compromiso',
          'description': 'Un compromiso escrito ayuda a perseverar',
          'content':
              'Escribe en tu diario: "Hoy voy a..." Por ejemplo: "Hoy no me quejaré" o "Hoy diré algo bonito a alguien".',
        },
        {
          'title': 'Vuelve a la Palabra durante el día',
          'description': 'Repite la palabra que te tocó',
          'content':
              'Durante el día, recuerda la palabra de Lectio Divina varias veces. Escríbela en un papel o pon una alarma.',
        },
        {
          'title': 'Comparte con alguien',
          'description': 'Cuéntale a alguien cercano lo que Dios te dijo',
          'content':
              'Comparte con tu pareja, amigo o director espiritual lo que Dios te dijo. Compartir profundiza la experiencia.',
        },
        {
          'title': 'Examen vespertino',
          'description': 'Por la noche evalúa cómo te fue',
          'content':
              'Antes de dormir pregúntate: ¿Viví según la Palabra? ¿Dónde sí? ¿Dónde no? No te juzgues – solo observa.',
        },
      ],
      'exampleTitle': '📝 Ejemplo de Actio',
      'exampleVerse':
          'Después de toda la Lectio Divina con la Palabra "No temas"',
      'exampleSteps': [
        'Mañana: Me despierto y mi primer pensamiento es: "No temas." Respiro profundo y entrego el día a Dios.',
        'En el trabajo: Antes de la entrevista me digo: "Dios está conmigo."',
        'Noche: Escribo: "Hoy no tuve miedo. No porque fuera valiente, sino porque confié."',
        'Antes de dormir: Doy gracias a Dios por el día de hoy. Me duermo en paz.',
      ],
      'exampleSummary':
          'Actio no se trata de perfección. Se trata de fidelidad. De pequeños pasos.',
      'closingTitle': '🌟 Cierre de Lectio Divina',
      'closingText':
          'Han completado todos los pasos de Lectio Divina. Silencio – que abre el corazón. Lectio – lectura que escucha. Meditatio – meditación que profundiza. Oratio – oración que responde. Contemplatio – contemplación que descansa. Y ahora Actio – vida que transforma.',
      'closingQuote':
          '"Así brille su luz delante de los hombres, para que vean sus buenas obras y glorifiquen a su Padre que está en los cielos." (Mt 5,16)',
      'back': 'Contemplatio',
      'backToOverview': 'Volver al resumen',
    },
  };
}

class IntroStepTranslations {
  Map<String, dynamic>? getTranslations(String languageCode, String step) {
    final translations = languageCode == 'en' ? _en : _sk;
    return translations[step];
  }

  static const Map<String, Map<String, dynamic>> _sk = {
    'lectio': {
      'stepIndicator': 'Krok 1 z 5',
      'stepTitle': '🕯️ LECTIO – Čítanie',
      'quoteText': 'Hovor, Hospodine, lebo tvoj služobník počúva.',
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

      'back': 'Späť na prehľad',
      'next': 'Meditatio',
    },

    'meditatio': {
      'stepIndicator': 'Krok 2 z 5',
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
          'Božie slovo je chlieb života. Nechaj ho preniknúť do svojho vnútra, nie ako informáciu, ale ako výživu.',

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
        'Rozjímanie: Čo mi hovorí o Bohu? Boh vidí môj strach a chce ma upokojiť. Je láskavý a starostlivý.',
        'Čo mi hovorí o mne? Mám právo mať strach, ale nemusím v ňom zostať. Boh ma pozýva k dôvere.',
        'Dnes mám strach z pracovného pohovoru. Boh mi hovorí "neboj sa" – nie preto, že by sa nič nestalo, ale preto, že On je so mnou.',
      ],
      'exampleSummary': '"Neboj sa, Boh je s tebou."',

      'closingTitle': '🕯️ Buď v tichu a počúvaj',
      'closingText':
          'Po odpovediach nehovor hneď ďalej. Zostaň chvíľu v tichu. Nechaj Slovo „vyklíčiť" – tak ako semienko potrebuje čas v zemi.',
      'closingQuote':
          'Mária zachovávala všetky tieto slová vo svojom srdci. (Lk 2,19)',

      'back': 'Lectio',
      'next': 'Oratio',
    },

    'oratio': {
      'stepIndicator': 'Krok 3 z 5',
      'stepTitle': '🙏 ORATIO – Modlitba',
      'quoteText':
          'Toto je naša dôvera v Neho: že nás počuje, keď prosíme o niečo podľa Jeho vôle.',
      'quoteReference': '1 Jn 5,14',
      'introParagraph':
          'Po čítaní a rozjímaní prichádza prirodzený a krásny krok: odpoveď Bohu. Vo fáze Oratio už nehovorí len Boh nám – teraz sme to my, kto hovorí Jemu.',

      'whatIsTitle': '💬 Čo je Oratio?',
      'whatIsContent':
          'Oratio je modlitba ako odpoveď na to, čo si počul a pochopil. Nie je to recitácia naučených viet, ale úprimný dialóg. Ako keď dieťa dôverne hovorí s otcom. Ako keď priateľ hovorí priateľovi, čo ho teší, trápi, čo objavil alebo prežil.',
      'whatIsQuote':
          'Tvoja modlitba nie je prednes. Je to odpoveď milujúcemu Bohu, ktorý ťa najprv počúval.',

      'howToTitle': '🧎 Ako sa modliť v tejto fáze?',
      'howToSteps': [
        {
          'title': 'Vychádzaj zo Slova, ktoré si prijal',
          'items': [
            'Neoddeluj sa od lectio a meditatio',
            'Použi tie slová, ktoré ťa oslovili, vetu, ktorú si nosíš v srdci',
          ],
        },
        {
          'title': 'Buď úprimný a prirodzený',
          'items': [
            'Modli sa svojimi vlastnými slovami',
            'Môžeš ďakovať, prosiť, chváliť, ľutovať...',
          ],
        },
        {
          'title': 'Hovor, akoby si skutočne stál pred Bohom',
          'items': [
            'A zároveň: počúvaj medzi riadkami',
            'V modlitbe nie si sám',
          ],
        },
      ],

      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Vychádzaj zo Slova',
          'description': 'Modli sa na základe toho, čo ťa oslovilo',
          'content':
              'Neoddeľuj modlitbu od predchádzajúceho čítania a rozjímania. Použij slová, vety alebo obrazy, ktoré ťa oslovili. Ak ťa napríklad dojalo "Neboj sa", modli sa o odvahu. Ak "Boh ťa miluje", ďakuj za lásku.',
        },
        {
          'title': 'Buď úprimný',
          'description': 'Modli sa svojimi vlastnými slovami',
          'content':
              'Nerecituj naučené modlitby. Hovor Bohu úprimne, ako keby sedel vedľa teba. Môžeš mu povedať o svojich radostiach, strachoch, túžbach. Boh chce počuť tvoj hlas, tvoje srdce.',
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
              'Ak si v rozjímaní vnímal Boha ako milujúceho Otca, modli sa s dôverou dieťaťa. Ak ako Priateľa, buď otvorený. Ak ako Učiteľa, pros o múdrosť. Nech tvoja modlitba odpovedá na to, ako sa ti Boh zjavil.',
        },
        {
          'title': 'Zakončí v tichu',
          'description': 'Po modlitbe sa stíš pre kontempláciu',
          'content':
              'Keď si povedal Bohu všetko, čo máš na srdci, neponáhľaj sa odísť. Zostaň ešte chvíľu v jeho prítomnosti. Ako keď sa milujúci ľudia pozerajú do očí bez slov. Toto ticho pripravuje na kontempláciu.',
        },
      ],

      'exampleTitle': '📝 Príklad modlitby Oratio',
      'exampleVerse':
          'Slovo z rozjímania: "Neboj sa, Boh je s tebou" (Lk 1,30)',
      'exampleSteps': [
        '"Pane, ďakujem Ti za toto slovo. Viem, že mám strach z toho pohovoru zajtra. Ale Ty mi hovoríš \'neboj sa\' - nie preto, že by sa nič nestalo, ale preto, že Ty budeš so mnou."',
        '"Pomôž mi dôverovať Ti viac ako svojmu strachu. Chcem cítiť Tvoju prítomnosť, keď budem nervózny. Daj mi pokoj, ktorý prichádza od Teba."',
        '"Ďakujem Ti, že ma poznáš a staráš sa o mňa. Odovzdávam Ti svoj strach a prijímam Tvoju lásku."',
      ],
      'exampleSummary': '(Potom zostanem chvíľu v tichu...)',

      'closingTitle': '🕯️ Záver modlitby',
      'closingText':
          'Po modlitbe sa znovu stíš. Ako keď milovaný človek odpovie, a potom sa obaja len pozerajú jeden druhému do očí – bez slov. Vstupujeme do kontemplácie – ďalšej fázy Lectio Divina.',
      'closingQuote':
          'Modlitba nie je preto, aby sme zmenili Boha, ale aby Boh zmenil nás. – sv. Augustín',

      'back': 'Meditatio',
      'next': 'Contemplatio',
    },

    'contemplatio': {
      'stepIndicator': 'Krok 4 z 5',
      'stepTitle': '🌿 CONTEMPLATIO – Kontemplácia',
      'quoteText':
          'Ukáž mi svoju tvár, daj mi počuť tvoj hlas, lebo tvoj hlas je sladký a tvoja tvár je pôvabná.',
      'quoteReference': 'Pieseň piesní 2,14',
      'introParagraph':
          'Po čítaní, rozjímaní a modlitbe prichádza ticho. Nie prázdnota, ale naplnené ticho – prítomnosťou Boha. V kroku Contemplatio už nesnažíme sa hovoriť ani analyzovať – iba sme.',

      'whatIsTitle': '🕊️ Čo je Contemplatio?',
      'whatIsContent1':
          'Contemplatio je spočinutie v Bohu. Nie je to úsilie, nie je to výkon – je to bytie v láske. Po tom, ako sme v lectio počúvali Slovo, v meditatio nad ním premýšľali a v oratio odpovedali, teraz zostávame v Jeho prítomnosti.',
      'whatIsContent2': 'Bez očakávaní. Bez slov. Len s túžbou byť s Ním.',
      'whatIsQuote':
          'Ticho je jazyk Boha. Všetko ostatné je len zlá interpretácia. — Thomas Keating',

      'howToTitle': '🙌 Ako praktizovať kontempláciu?',
      'howToSteps': [
        'Sadni si alebo si kľakni do pohodlnej, ale bdelej polohy',
        'Zatvor oči',
        'Dýchaj pokojne. Zvoľni rytmus tela aj duše',
        'Nechaj odísť všetky myšlienky – netlač ich preč, len ich nechaj odplávať',
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
              'Keď prídu myšlienky na prácu, starosti alebo plány, netlač ich násilne preč. Jednoducho ich pozoruj ako oblaky na oblohe a nechaj ich odísť. Jemne sa vráť k prítomnosti Boha.',
        },
        {
          'title': 'Dýchaj s Bohom',
          'description': 'Použij dych ako cestu k prítomnosti',
          'content':
              'Dýchaj pokojne a prirodzene. Môžeš si pri vdychu povedať "Pane Ježišu" a pri výdychu "zmiluj sa". Alebo jednoducho vnímaj dych ako dar života od Boha. Nech ťa dych spája s Ním.',
        },
        {
          'title': 'Použij duchovnú kotvu',
          'description': 'Pomôcky na udržanie pozornosti',
          'content':
              'Ak sa ťažko sústredíš, pomôž si: opakuj Ježišovu modlitbu, pozoruj plameň sviečky, alebo si opakuj verš, ktorý ťa oslovil. Tieto "kotvy" ťa pomôžu udržať v Božej prítomnosti.',
        },
        {
          'title': 'Jednoducho buď',
          'description': 'Neočakávaj nič, len prijímaj prítomnosť',
          'content':
              'Neočakávaj žiadne zvláštne pocity ani zážitky. Stačí vedieť, že Boh je tu a ty si s Ním. Aj keď necítiš nič výnimočné, kontemplácia sa deje. Láska nemusí byť vždy cítená, ale je vždy prítomná.',
        },
      ],

      'exampleTitle': '📝 Príklad kontemplácie',
      'exampleVerse': 'Po modlitbe o "Neboj sa" sa usadím v tichu.',
      'exampleSteps': [
        'Zatvorím oči a dýcham pokojne. Nechám odísť všetky myšlienky na zajtra, na prácu, na starosti.',
        'Jednoducho som tu - s Bohom. Neočakávam nič zvláštne. Len prijímam Jeho prítomnosť.',
        'Ak sa mi mysle zatúlajú k strachu z pohovoru, jemne si poviem: "Si tu, Pane" a vraciam sa k prítomnosti.',
        'Možno necítim nič výnimočné. Ale viem, že On je tu. A to stačí.',
      ],
      'exampleSummary':
          'Zostanem tak 5-10 minút v jednoduchom bytí s Ním. "Zotrvávajte vo mne a ja vo vás." (Jn 15,4)',

      'closingTitle': '🔜 Pripravený premeniť svoju modlitbu na skutok?',
      'closingText':
          'Z kontemplácie pramení posledný krok Lectio Divina – ACTIO, kde sa Slovo premieňa na život. Ale ešte chvíľu zostaň... v tichu. V Božej blízkosti. V láske.',
      'closingQuote': 'Zotrvávajte vo mne a ja vo vás. (Jn 15,4)',

      'back': 'Oratio',
      'next': 'Actio',
    },

    'actio': {
      'stepIndicator': 'Krok 5 z 5',
      'stepTitle': '🕊️ ACTIO – Žiť Božie slovo',
      'quoteText':
          'Dobré je tiež pripomenúť, že dynamika lectio divina sa nenapĺňa, kým neprejde do činnosti (actio), čím podnecuje život veriaceho, aby sa v láske stal darom pre druhých.',
      'quoteReference': '– Pápež Benedikt XVI., Verbum Domini, 87',
      'introParagraph':
          'Po chvíľach počúvania, rozjímania, modlitby a spočinutia v Božej prítomnosti prichádza ovocie: život premieňaný Slovom. Modlitba Lectio Divina nekončí v tichu – končí v skutkoch.',

      'whatIsTitle': '🔥 Čo je Actio?',
      'whatIsContent':
          'Actio nie je len ďalší bod na zozname – je to dôsledok. Je to syla Krista, ktorú sme prijali, a ktorá nás teraz pohýba k láske. Slovo, ktoré nás zasiahlo, sa má prejaviť v konkrétnych činoch: v láskavosti, službe, odpustení, pozornosti, odvahe...',
      'whatIsQuote':
          'Milujte sa navzájom, ako som ja miloval vás. (Jn 13,34) Nie teória, ale prax lásky – to je actio.',

      'howToTitle': '💡 Ako žiť Actio v každodennosti?',
      'howToSteps': [
        'V práci: láskavosť namiesto podráždenia, pokoj namiesto súťaženia',
        'V rodine: načúvať skôr, než súdiť. Byť darom pre druhých',
        'Na ulici, v obchode, v doprave: nenápadné skutky lásky sú najčistejšou formou evanjelia',
        'V utrpení: priniesť ho ako obetu, nie ako hnev',
        'V radosti: oslavovať Boha a zdieľať nádej',
      ],

      'practicalTipsTitle': '✍️ Praktické návody',
      'practicalTips': [
        {
          'title': 'Identifikuj konkrétny čin',
          'description': 'Spoj actio s tým, čo ťa oslovilo',
          'content':
              'Opýtaj sa: Čo konkrétne mi Boh hovorí cez toto Slovo? Ak ťa oslovilo "neboj sa", možno ťa pozýva prekonať konkrétny strach. Ak "odpusť", možno niekomu odpustiť. Nechaj Slovo ukázať cestu.',
        },
        {
          'title': 'Začni malými skutkami',
          'description': 'Veľká láska rastie z malých gestí',
          'content':
              'Neočakávaj od seba dramatické zmeny. Začni malým krokom: úsmevom, telefonátom, ospravedlnením, pomocou. Boh koná cez jednoduché gesto lásky rovnako mocne ako cez veľké skutky.',
        },
        {
          'title': 'Zapíš si rozhodnutie',
          'description': 'Zachovaj ovocie rozjímania',
          'content':
              'Napíš si do denníka alebo poznámok konkrétne rozhodnutie. "Dnes zavolám mame", "Odpustím kolegovi v srdci", "Budem trpezlivejší s deťmi". Písanie posilňuje zámer a pomáha pamätať.',
        },
        {
          'title': 'Zdieľaj sa s ostatnými',
          'description': 'Actio môže byť aj svedectvo',
          'content':
              'Podeľ sa s niekým blízkym o to, čo ťa oslovilo. Nie z povinnosti, ale z radosti. Keď vidíš, že niekto trpí, podeľ sa o Slovo útechy. Tvoje svedectvo môže byť Božím darom pre druhého.',
        },
        {
          'title': 'Priprav sa na ďalší cyklus',
          'description': 'Actio uzatvára a zároveň otvára',
          'content':
              'Jeden cyklus Lectio Divina sa končí, ale život premenený Slovom túži po ďalšom stretnutí s Bohom. Môžeš sa vrátiť k tomu istému textu alebo vybrať nový. Lectio Divina je cesta, nie cieľ.',
        },
      ],

      'exampleTitle': '📝 Príklad Actio',
      'exampleVerse':
          'Po rozjímaní nad "Neboj sa" a kontemplácii som sa rozhodol:',
      'exampleSteps': [
        'Konkrétny skutok: Zavolám kolegovi, s ktorým som sa pohádal, a ospravedlním sa. Môj strach z toho, že ma odmietne, odovzdávam Bohu.',
        'Malý skutok: Keď budem dnes nervózny, namiesto strachu si poviem "Boh je so mnou" a pokúsim sa byť láskavý k ostatným.',
        'Tichý skutok: Napíšem si do denníka: "Pane, ďakujem Ti za slovo o odvage. Pomôž mi dôverovať Ti viac ako svojmu strachu."',
        'Svedectvo: Ak sa ma niekto spýta, prečo som pokojný, poviem mu, že ma Boh utešuje svojím slovom.',
      ],
      'exampleSummary':
          '"Toto Slovo, ktoré ma dnes navštívilo, chcem niesť ďalej – v skutkoch, v láske, v pravde. Amen."',

      'closingTitle': '🔚 Lectio Divina nekončí – začína sa žiť',
      'closingText':
          'Modlitba je krásna, ale jej ovocie rastie v živote medzi ľuďmi. Preto sa po Lectio Divina neodchádza len do ticha, ale do sveta. So srdcom premeneným Slovom. So skutkami, ktoré sú svetlom. S milosťou, ktorá sa stáva telom.',
      'closingQuote':
          'Actio ako svedectvo: Actio je prijaté Slovo premenené na dar. Nie zo sily človeka, ale z moci Ducha. Nie preto, aby sme niečo dokázali, ale preto, že sme boli milovaní – a teraz milujeme.',

      'back': 'Contemplatio',
      'backToOverview': 'Späť na prehľad',
    },
  };

  static const Map<String, Map<String, dynamic>> _en = {
    'lectio': {
      'stepIndicator': 'Step 1 of 5',
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
              'Find a quiet place free from distractions – a corner of your room, by a window, or even in nature. What matters is that you feel calm and safe. Have a Bible or a Bible app ready.',
        },
        {
          'title': 'Choosing a passage',
          'description': 'Pick a short but meaningful text',
          'content':
              'Start with 3–5 verses. Use the daily Gospel, a Psalm, or a passage based on a theme (peace, love, trust). Quality of attention is more important than quantity.',
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
              'Listen not only with your mind but also your heart. What feelings arise? What memories or thoughts come up? Accept everything as part of your dialogue with God.',
        },
        {
          'title': 'Noting the word',
          'description': 'Write down a word or phrase that touched you',
          'content':
              'If something stood out – a word, phrase, or image – write it down. Use a journal, your phone, or a small piece of paper. Let that word accompany you throughout the day.',
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
          'After reading, remain in silence for a moment. Let the Word echo within you. Once you sense that something has touched you – that something remains – you may move to the next step: Meditatio – reflection.',
      'closingQuote':
          'The Word is like a seed. Reading sows it. Meditation waters it. Prayer lets it grow. Contemplation dwells in it.',

      'back': 'Back to overview',
      'next': 'Meditatio',
    },

    'meditatio': {
      'stepIndicator': 'Step 2 of 5',
      'stepTitle': '💭 MEDITATIO – Meditation',
      'quoteText':
          'All Scripture is inspired by God and is useful for teaching, for refutation, for correction, and for training in righteousness.',
      'quoteReference': '2 Tim 3:16',
      'introParagraph':
          'After reading and receiving the Word into our hearts, it is time to "chew" it – to let it mature within us and unfold its meaning. The meditatio phase is about diving deep.',

      'whatIsTitle': '🔍 What is Meditatio?',
      'whatIsContent1':
          'Meditatio is quiet, attentive reflection. It\'s not an intellectual analysis, but a listening with the heart. It\'s no longer just about words, but about their inner message, their touch.',
      'whatIsContent2':
          'Just like we chew food slowly to draw all nourishment from it – in this phase, we let the Word penetrate our thoughts, feelings, and soul.',
      'whatIsQuote':
          'God\'s Word is the bread of life. Let it enter your innermost being – not as information, but as nourishment.',

      'howToTitle': '🧠 How to Practice Meditation?',
      'howToSteps': [
        'Stay with the word, phrase, or image that touched you during the reading (Lectio).',
        'Repeat it slowly in your mind – as if you were savoring it again and again.',
        'Notice what stirs in you: feelings, thoughts, invitations, challenges, light.',
      ],

      'practicalTipsTitle': '✍️ Practical Tips',
      'practicalTips': [
        {
          'title': 'Repeat the Word',
          'description': 'Stay with the word that touched you in Lectio',
          'content':
              'Take the word, phrase, or image from the reading and repeat it in your mind. Not mechanically, but like savoring a delicious meal – slowly and attentively. Let it dissolve into your heart.',
        },
        {
          'title': 'Ask Questions',
          'description': 'Two essential directions for meditation',
          'content':
              'Ask yourself: 1) What does this text say about God? How is He revealing Himself? 2) What does it say about me and my life today? Don\'t rush – let the answers rise naturally from within.',
        },
        {
          'title': 'Look for Connections',
          'description': 'Link the text with the broader biblical context',
          'content':
              'If a word reminds you of another Scripture, look it up. How has God spoken about this theme elsewhere? For example, "do not be afraid" – where else does He say that? It\'s not about studying, but deeper listening.',
        },
        {
          'title': 'Remain in Silence',
          'description': 'Give the Word space to grow',
          'content':
              'After meditating, don\'t rush ahead. Remain in silence, like Mary who "kept all these things in her heart." Let the Word take root like a seed in the soil.',
        },
        {
          'title': 'Write Down Observations',
          'description': 'Preserve the fruit of meditation',
          'content':
              'Jot down in a journal or notes: the word that spoke to you, your feelings, responses, personal insights. You may return to them later today or in the future.',
        },
      ],

      'exampleTitle': '📝 Example of Meditation',
      'exampleVerse': 'Word that touched me: "Do not be afraid" (Lk 1:30)',
      'exampleSteps': [
        'Meditation: What does it say about God? He sees my fear and wants to calm me. He is kind and caring.',
        'What does it say about me? It\'s okay to be afraid, but I don\'t have to stay in fear. God invites me to trust.',
        'Today I\'m afraid of a job interview. God tells me "do not be afraid" – not because nothing will happen, but because He is with me.',
      ],
      'exampleSummary': '"Do not be afraid, God is with you."',

      'closingTitle': '🕯️ Be Silent and Listen',
      'closingText':
          'Don\'t speak immediately after the answers. Stay in silence. Let the Word "take root" – just as a seed needs time in the soil.',
      'closingQuote': 'Mary kept all these things in her heart. (Lk 2:19)',

      'back': 'Lectio',
      'next': 'Oratio',
    },

    'oratio': {
      'stepIndicator': 'Step 3 of 5',
      'stepTitle': '🙏 ORATIO – Prayer',
      'quoteText':
          'This is the confidence we have in approaching God: that if we ask anything according to his will, he hears us.',
      'quoteReference': '1 John 5:14',
      'introParagraph':
          'After reading and meditation comes a natural and beautiful step: responding to God. In the Oratio phase, it\'s no longer just God speaking to us – now we are the ones speaking to Him.',

      'whatIsTitle': '💬 What is Oratio?',
      'whatIsContent':
          'Oratio is prayer as a response to what you have heard and understood. It\'s not reciting memorized sentences, but sincere dialogue. Like when a child speaks intimately with their father. Like when a friend tells a friend what brings them joy, what troubles them, what they\'ve discovered or experienced.',
      'whatIsQuote':
          'Your prayer is not a performance. It\'s a response to the loving God who first listened to you.',

      'howToTitle': '🧎 How to pray in this phase?',
      'howToSteps': [
        {
          'title': 'Start from the Word you received',
          'items': [
            'Don\'t separate yourself from lectio and meditatio',
            'Use those words that spoke to you, the verse you carry in your heart',
          ],
        },
        {
          'title': 'Be honest and natural',
          'items': [
            'Pray in your own words',
            'You can thank, ask, praise, repent...',
          ],
        },
        {
          'title': 'Speak as if you truly stand before God',
          'items': [
            'And at the same time: listen between the lines',
            'In prayer you are not alone',
          ],
        },
      ],

      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'Start from the Word',
          'description': 'Pray based on what spoke to you',
          'content':
              'Don\'t separate prayer from the preceding reading and meditation. Use words, sentences or images that spoke to you. If for example "Don\'t be afraid" touched you, pray for courage. If "God loves you", thank for love.',
        },
        {
          'title': 'Be honest',
          'description': 'Pray in your own words',
          'content':
              'Don\'t recite memorized prayers. Speak to God honestly, as if He sat next to you. You can tell Him about your joys, fears, desires. God wants to hear your voice, your heart.',
        },
        {
          'title': 'Try different forms',
          'description': 'Prayer doesn\'t have to be just verbal',
          'content':
              'Besides speaking, you can express prayer through: writing in a journal, drawing, singing, dancing, embracing the cross. Sometimes the most beautiful prayer is just sitting silently in God\'s presence.',
        },
        {
          'title': 'Adapt to God\'s image',
          'description': 'Pray according to how God spoke to you',
          'content':
              'If in meditation you perceived God as a loving Father, pray with a child\'s trust. If as a Friend, be open. If as a Teacher, ask for wisdom. Let your prayer respond to how God revealed Himself to you.',
        },
        {
          'title': 'End in silence',
          'description': 'After prayer, be quiet for contemplation',
          'content':
              'When you\'ve told God everything on your heart, don\'t hurry to leave. Stay a moment longer in His presence. Like when loving people look into each other\'s eyes without words. This silence prepares for contemplation.',
        },
      ],

      'exampleTitle': '📝 Example of Oratio prayer',
      'exampleVerse':
          'Word from meditation: "Do not be afraid, God is with you" (Luke 1:30)',
      'exampleSteps': [
        '"Lord, thank You for this word. I know I\'m afraid of that interview tomorrow. But You tell me \'don\'t be afraid\' - not because nothing will happen, but because You will be with me."',
        '"Help me trust You more than my fear. I want to feel Your presence when I\'m nervous. Give me the peace that comes from You."',
        '"Thank You for knowing me and caring for me. I surrender my fear to You and receive Your love."',
      ],
      'exampleSummary': '(Then I remain in silence for a while...)',

      'closingTitle': '🕯️ Closing the prayer',
      'closingText':
          'After prayer, be quiet again. Like when a beloved person responds, and then both just look into each other\'s eyes – without words. We enter contemplation – the next phase of Lectio Divina.',
      'closingQuote':
          'Prayer is not to change God, but for God to change us. – St. Augustine',

      'back': 'Meditatio',
      'next': 'Contemplatio',
    },

    'contemplatio': {
      'stepIndicator': 'Step 4 of 5',
      'stepTitle': '🌿 CONTEMPLATIO – Contemplation',
      'quoteText':
          'Show me your face, let me hear your voice, for your voice is sweet and your face is lovely.',
      'quoteReference': 'Song of Songs 2:14',
      'introParagraph':
          'After reading, meditation and prayer comes silence. Not emptiness, but filled silence – with God\'s presence. In the Contemplatio step we no longer try to speak or analyze – we simply are.',

      'whatIsTitle': '🕊️ What is Contemplatio?',
      'whatIsContent1':
          'Contemplatio is resting in God. It\'s not effort, it\'s not performance – it\'s being in love. After we listened to the Word in lectio, reflected on it in meditatio and responded in oratio, now we remain in His presence.',
      'whatIsContent2':
          'Without expectations. Without words. Just with the desire to be with Him.',
      'whatIsQuote':
          'Silence is God\'s first language. Everything else is a poor translation. — Thomas Keating',

      'howToTitle': '🙌 How to practice contemplation?',
      'howToSteps': [
        'Sit or kneel in a comfortable but alert position',
        'Close your eyes',
        'Breathe peacefully. Slow the rhythm of body and soul',
        'Let all thoughts go – don\'t push them away, just let them float away',
      ],

      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'Preparing for silence',
          'description': 'Create an environment for contemplation',
          'content':
              'Find a quiet place where nothing will disturb you. Sit comfortably but stay alert. You can light a candle or place an icon before you. Close your eyes and slow your breathing rhythm.',
        },
        {
          'title': 'Let thoughts go',
          'description': 'Don\'t push them away, just let them float away',
          'content':
              'When thoughts about work, worries or plans come, don\'t push them away forcefully. Simply observe them like clouds in the sky and let them go. Gently return to God\'s presence.',
        },
        {
          'title': 'Breathe with God',
          'description': 'Use breath as a path to presence',
          'content':
              'Breathe peacefully and naturally. You can say "Lord Jesus" on the inhale and "have mercy" on the exhale. Or simply perceive breath as a gift of life from God. Let breath unite you with Him.',
        },
        {
          'title': 'Use a spiritual anchor',
          'description': 'Aids for maintaining attention',
          'content':
              'If you have trouble concentrating, help yourself: repeat the Jesus Prayer, watch a candle flame, or repeat a verse that spoke to you. These "anchors" will help you stay in God\'s presence.',
        },
        {
          'title': 'Simply be',
          'description': 'Expect nothing, just receive presence',
          'content':
              'Don\'t expect any special feelings or experiences. It\'s enough to know that God is here and you are with Him. Even if you feel nothing exceptional, contemplation is happening. Love doesn\'t always have to be felt, but it\'s always present.',
        },
      ],

      'exampleTitle': '📝 Example of contemplation',
      'exampleVerse':
          'After praying about "Do not be afraid" I settle into silence.',
      'exampleSteps': [
        'I close my eyes and breathe peacefully. I let go of all thoughts about tomorrow, work, worries.',
        'I\'m simply here - with God. I don\'t expect anything special. I just receive His presence.',
        'If my mind wanders to fear about the interview, I gently say to myself: "You are here, Lord" and return to presence.',
        'I may not feel anything exceptional. But I know He is here. And that\'s enough.',
      ],
      'exampleSummary':
          'I remain like this for 5-10 minutes in simple being with Him. "Remain in me, and I will remain in you." (John 15:4)',

      'closingTitle': '🔜 Ready to transform your prayer into action?',
      'closingText':
          'From contemplation springs the final step of Lectio Divina – ACTIO, where the Word is transformed into life. But stay a moment longer... in silence. In God\'s closeness. In love.',
      'closingQuote': 'Remain in me, and I will remain in you. (John 15:4)',

      'back': 'Oratio',
      'next': 'Actio',
    },

    'actio': {
      'stepIndicator': 'Step 5 of 5',
      'stepTitle': '🕊️ ACTIO – Living God\'s Word',
      'quoteText':
          'It is also good to remember that the dynamics of lectio divina are not complete until they reach action (actio), which moves the believer\'s life to become a gift for others in love.',
      'quoteReference': '– Pope Benedict XVI, Verbum Domini, 87',
      'introParagraph':
          'After moments of listening, meditation, prayer and resting in God\'s presence comes the fruit: life transformed by the Word. Lectio Divina prayer doesn\'t end in silence – it ends in action.',

      'whatIsTitle': '🔥 What is Actio?',
      'whatIsContent':
          'Actio is not just another item on a list – it\'s a consequence. It\'s the energy of Christ that we have received, which now moves us toward love. The Word that struck us must manifest in concrete actions: in kindness, service, forgiveness, attention, courage...',
      'whatIsQuote':
          'Love one another as I have loved you. (John 13:34) Not theory, but the practice of love – that is actio.',

      'howToTitle': '💡 How to live Actio in everyday life?',
      'howToSteps': [
        'At work: kindness instead of irritation, peace instead of competition',
        'In family: listen before judging. Be a gift to others',
        'On the street, in stores, in traffic: unnoticed acts of love are the purest form of gospel',
        'In suffering: bring it as an offering, not as anger',
        'In joy: celebrate God and share hope',
      ],

      'practicalTipsTitle': '✍️ Practical guidance',
      'practicalTips': [
        {
          'title': 'Identify a concrete action',
          'description': 'Connect actio with what spoke to you',
          'content':
              'Ask yourself: What specifically is God saying to me through this Word? If "do not fear" spoke to you, perhaps He\'s inviting you to overcome a specific fear. If "forgive", perhaps to forgive someone. Let the Word show the way.',
        },
        {
          'title': 'Start with small actions',
          'description': 'Great love grows from small gestures',
          'content':
              'Don\'t expect dramatic changes from yourself. Start with a small step: a smile, a phone call, an apology, help. God acts through simple gestures of love as powerfully as through great deeds.',
        },
        {
          'title': 'Write down your decision',
          'description': 'Preserve the fruit of meditation',
          'content':
              'Write down a concrete decision in your journal or notes. "Today I will call mom", "I will forgive my colleague in my heart", "I will be more patient with children". Writing strengthens intention and helps remember.',
        },
        {
          'title': 'Share with others',
          'description': 'Actio can also be witness',
          'content':
              'Share with someone close what spoke to you. Not from obligation, but from joy. When you see someone suffering, share a Word of comfort. Your witness can be God\'s gift to another.',
        },
        {
          'title': 'Prepare for the next cycle',
          'description': 'Actio closes and simultaneously opens',
          'content':
              'One cycle of Lectio Divina ends, but a life transformed by the Word yearns for another encounter with God. You can return to the same text or choose a new one. Lectio Divina is a journey, not a destination.',
        },
      ],

      'exampleTitle': '📝 Example of Actio',
      'exampleVerse':
          'After meditating on "Do not fear" and contemplation, I decided:',
      'exampleSteps': [
        'Concrete action: I will call the colleague I argued with and apologize. My fear that he will reject me, I surrender to God.',
        'Small action: When I\'m nervous today, instead of fear I\'ll tell myself "God is with me" and try to be kind to others.',
        'Silent action: I\'ll write in my journal: "Lord, thank You for the word about courage. Help me trust You more than my fear."',
        'Witness: If someone asks why I\'m peaceful, I\'ll tell them that God comforts me with His word.',
      ],
      'exampleSummary':
          '"This Word that visited me today, I want to carry forward – in actions, in love, in truth. Amen."',

      'closingTitle': '🔚 Lectio Divina doesn\'t end – it begins to be lived',
      'closingText':
          'Prayer is beautiful, but its fruit grows in life among people. Therefore, after Lectio Divina we don\'t just go into silence, but into the world. With hearts transformed by the Word. With actions that are light. With grace that becomes flesh.',
      'closingQuote':
          'Actio as witness: Actio is the received Word transformed into a gift. Not from human strength, but from the power of the Spirit. Not to prove something, but because we have been loved – and now we love.',

      'back': 'Contemplatio',
      'backToOverview': 'Back to overview',
    },
  };
}

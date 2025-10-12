class IntroTranslations {
  Map<String, dynamic> getTranslations(String languageCode) {
    switch (languageCode) {
      case 'en':
        return _en;
      case 'sk':
      default:
        return _sk;
    }
  }

  static const Map<String, dynamic> _sk = {
    'heroTitle': 'Počúvaj, čo ti Boh chce povedať',
    'heroSubtitle': 'Objav modlitbu Lectio Divina',
    'heroDescription':
        'V rýchlom svete, kde sa veľa hovorí, ale málo skutočne počúva, je čoraz ťažšie nájsť ticho. A predsa – práve ticho je miesto, kde môže zaznieť Boží hlas.',
    'startLectio': 'Začni s Lectio Divina',

    'whatIs': 'Čo je Lectio Divina?',
    'whatIsText1':
        'Lectio Divina je starobylá forma modlitby s Bibliou, ale nečakaj výklad ani analýzu. Nie je to prednáška. Nie je to ani výkon. Je to stretnutie – tiché, osobné, skutočné. Cez Božie slovo vstupujeme do rozhovoru s Tým, ktorý nás pozná do hĺbky.',
    'whatIsText2':
        'Táto forma vznikla v prvotných kláštoroch a neskôr ju rozvíjali ľudia ako sv. Benedikt, Origenes, sv. Gregor z Nyssy či kartuzián Guigo II. Dnes si ju znovu osvojujú ľudia všetkých vekov, ktorí túžia po vzťahu s Bohom – aj mimo múrov kláštorov.',

    'fiveStepsTitle': 'Päť krokov Lectio Divina',
    'fiveStepsText':
        'Každý krok vás priblíži k hlbšiemu vzťahu s Bohom. Postupujte svojím tempom a nechajte Ducha Svätého viesť vaše srdce.',

    'benefitsTitle': 'Posvätné čítanie ako stretnutie',
    'benefitsText':
        'Pravidelná prax Lectio Divina prináša pokoj, jasnosť a hlbší duchovný rast. Tisíce kresťanov po celom svete objavili transformačnú silu tejto modlitby.',

    'howToTitle': 'Lectio Divina je pre všetkých',
    'howToText':
        'Nepotrebujete žiadne špeciálne znalosti. Stačí otvoriť srdce, vybrať si text a začať prvým krokom. Boh sa postará o zvyšok.',
    'startFirstStep': 'Začať s prvým krokom',

    'closingQuote':
        'Slovo, ktoré k tebe dnes prichádza, ťa hľadá. Otvor srdce. Nechaj sa nájsť.',
    'closingText':
        'Lectio Divina nie je len starobylá metóda – je to živá cesta pre dnešného človeka. Slovo Boha, ktoré sa dnes dotkne tvojho srdca, môže zmeniť celý tvoj deň… a možno aj celý tvoj život.',

    'steps': [
      {
        'number': 1,
        'slug': 'lectio',
        'title': 'Lectio - Čítanie',
        'subtitle': 'Pozorné čítanie Božieho slova',
        'description': 'Pomalé, sústredené načúvanie Božiemu hlasu cez Písmo.',
        'duration': '10 min',
      },
      {
        'number': 2,
        'slug': 'meditatio',
        'title': 'Meditatio - Meditácia',
        'subtitle': 'Hlboké rozjímanie nad textom',
        'description': 'Nechávame Slovo preniknúť z hlavy do srdca.',
        'duration': '15 min',
      },
      {
        'number': 3,
        'slug': 'oratio',
        'title': 'Oratio - Modlitba',
        'subtitle': 'Rozhovor s Bohom',
        'description': 'Úprimný dialóg s Bohom na základe Jeho Slova.',
        'duration': '10 min',
      },
      {
        'number': 4,
        'slug': 'contemplatio',
        'title': 'Contemplatio - Kontemplácia',
        'subtitle': 'Ticho s Bohom',
        'description': 'Spočinutie v Božej prítomnosti bez slov.',
        'duration': '20 min',
      },
      {
        'number': 5,
        'slug': 'actio',
        'title': 'Actio - Žiť Božie slovo',
        'subtitle': 'Žiť podľa Božieho slova',
        'description': 'Praktická aplikácia do každodenného života.',
        'duration': '5 min',
      },
    ],

    'benefits': [
      {
        'title': 'Počúvanie Božieho hlasu',
        'description':
            'V tichu Lectio Divina sa učíme rozoznávať Boží hlas a otvárať mu srdce.',
      },
      {
        'title': 'Premena srdca',
        'description':
            'Lectio Divina nie je len čítanie - je to proces premeny cez Božie slovo.',
      },
      {
        'title': 'Obnovenie a pokoj',
        'description':
            'V rýchlom svete nachádza duša odpočinok v tichom stretnutí s Bohom.',
      },
      {
        'title': 'Pre všetkých a všade',
        'description':
            'Môžeš ju praktizovať sám alebo v spoločenstve, nie je potrebná teologická príprava.',
      },
    ],

    'guide': [
      {
        'title': 'Vyber si čas a miesto',
        'description':
            'Stačí 10-15 minút denne v kľudnom prostredí. Dôležitá je pravidelnosť, nie dĺžka.',
      },
      {
        'title': 'Vyber si krátky biblický text',
        'description':
            'Nepotrebuješ čítať celé kapitoly. Stačí pár veršov z Evanjelia alebo žalmov.',
      },
      {
        'title': 'Otvor sa Bohu',
        'description':
            'Začni krátkou modlitbou: "Pane, chcem Ťa počuť. Otvor moje srdce pre Tvoje slovo."',
      },
      {
        'title': 'Neponáhľaj sa',
        'description':
            'Lectio Divina nie je o rýchlosti ani výkone. Boh sa prispôsobuje tvojmu tempu.',
      },
    ],
  };

  static const Map<String, dynamic> _en = {
    'heroTitle': 'Listen to what God wants to tell you',
    'heroSubtitle': 'Discover the prayer of Lectio Divina',
    'heroDescription':
        'In a fast-paced world where many speak but few truly listen, silence becomes harder to find. And yet — it is in silence that God\'s voice can be heard.',
    'startLectio': 'Start with Lectio Divina',

    'whatIs': 'What is Lectio Divina?',
    'whatIsText1':
        'Lectio Divina is an ancient way of praying with the Bible — but don\'t expect a lecture or analysis. It\'s not about performance. It\'s not an explanation. It\'s an encounter — quiet, personal, real. Through God\'s Word, we enter into a conversation with the One who knows us deeply.',
    'whatIsText2':
        'This form of prayer began in the early monasteries and was later shaped by saints like Benedict, Origen, Gregory of Nyssa, and the Carthusian Guigo II. Today, people of all ages rediscover it — seeking a relationship with God, even beyond monastery walls.',

    'fiveStepsTitle': 'The Five Steps of Lectio Divina',
    'fiveStepsText':
        'Each step brings you closer to a deeper relationship with God. Go at your own pace, and let the Holy Spirit guide your heart.',

    'benefitsTitle': 'Sacred reading as encounter',
    'benefitsText':
        'A regular practice of Lectio Divina brings peace, clarity, and spiritual growth. Thousands of Christians around the world have experienced its transforming power.',

    'howToTitle': 'Lectio Divina is for everyone',
    'howToText':
        'You don\'t need any special knowledge. Just open your heart, choose a passage, and take the first step. God will take care of the rest.',
    'startFirstStep': 'Begin the first step',

    'closingQuote':
        'The Word that comes to you today is looking for you. Open your heart. Let yourself be found.',
    'closingText':
        'Lectio Divina is not just an ancient method — it is a living path for today. The Word of God that touches your heart today may change your whole day… or even your life.',

    'steps': [
      {
        'number': 1,
        'slug': 'lectio',
        'title': 'Lectio – Reading',
        'subtitle': 'Attentive reading of God\'s Word',
        'description':
            'Slow, focused listening to the voice of God through Scripture.',
        'duration': '10 min',
      },
      {
        'number': 2,
        'slug': 'meditatio',
        'title': 'Meditatio – Meditation',
        'subtitle': 'Deep reflection on the text',
        'description': 'Letting the Word move from the head to the heart.',
        'duration': '15 min',
      },
      {
        'number': 3,
        'slug': 'oratio',
        'title': 'Oratio – Prayer',
        'subtitle': 'Speaking with God',
        'description': 'A sincere dialogue with God, inspired by His Word.',
        'duration': '10 min',
      },
      {
        'number': 4,
        'slug': 'contemplatio',
        'title': 'Contemplatio – Contemplation',
        'subtitle': 'Silent being with God',
        'description': 'Resting in God\'s presence without words.',
        'duration': '20 min',
      },
      {
        'number': 5,
        'slug': 'actio',
        'title': 'Actio – Action',
        'subtitle': 'Living according to God\'s Word',
        'description': 'Putting the Word into practice in daily life.',
        'duration': '5 min',
      },
    ],

    'benefits': [
      {
        'title': 'Hearing God\'s voice',
        'description':
            'In the silence of Lectio Divina, we learn to recognize God\'s voice and open our hearts to it.',
      },
      {
        'title': 'Heart transformation',
        'description':
            'Lectio Divina is not just reading — it\'s a process of inner change through God\'s Word.',
      },
      {
        'title': 'Renewal and peace',
        'description':
            'In a noisy world, the soul finds rest in the quiet encounter with God.',
      },
      {
        'title': 'For everyone, everywhere',
        'description':
            'You can practice it alone or in a group. No theological training is required.',
      },
    ],

    'guide': [
      {
        'title': 'Choose a time and place',
        'description':
            'Just 10–15 minutes a day in a quiet setting is enough. What matters most is consistency, not duration.',
      },
      {
        'title': 'Choose a short Bible passage',
        'description':
            'You don\'t need to read whole chapters. A few verses from the Gospels or Psalms is enough.',
      },
      {
        'title': 'Open yourself to God',
        'description':
            'Begin with a short prayer: "Lord, I want to hear You. Open my heart to Your Word."',
      },
      {
        'title': 'Don\'t rush',
        'description':
            'Lectio Divina isn\'t about speed or achievement. God meets you at your pace.',
      },
    ],
  };
}

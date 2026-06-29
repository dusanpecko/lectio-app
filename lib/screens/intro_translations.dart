class IntroTranslations {
  Map<String, dynamic> getTranslations(String languageCode) {
    switch (languageCode) {
      case 'en':
        return _en;
      case 'es':
        return _es;
      case 'fr':
        return _fr;
      case 'cz':
      case 'cs':
        return _cz;
      case 'sk':
      default:
        return _sk;
    }
  }

  static const Map<String, dynamic> _sk = {
    'stepLabel': 'Krok',
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

    'fiveStepsTitle': 'Šesť krokov Lectio Divina',
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
        'slug': 'silencio',
        'title': 'Silencio - Ticho',
        'subtitle': 'Brána do modlitby',
        'description':
            'Zastav sa. Stíš sa. Vytvor priestor, kde môže Boh prehovoriť.',
        'duration': '5 min',
      },
      {
        'number': 2,
        'slug': 'lectio',
        'title': 'Lectio - Čítanie',
        'subtitle': 'Pozorné čítanie Božieho slova',
        'description': 'Pomalé, sústredené načúvanie Božiemu hlasu cez Písmo.',
        'duration': '10 min',
      },
      {
        'number': 3,
        'slug': 'meditatio',
        'title': 'Meditatio - Meditácia',
        'subtitle': 'Hlboké rozjímanie nad textom',
        'description': 'Nechávame Slovo preniknúť z hlavy do srdca.',
        'duration': '15 min',
      },
      {
        'number': 4,
        'slug': 'oratio',
        'title': 'Oratio - Modlitba',
        'subtitle': 'Rozhovor s Bohom',
        'description': 'Úprimný dialóg s Bohom na základe Jeho Slova.',
        'duration': '10 min',
      },
      {
        'number': 5,
        'slug': 'contemplatio',
        'title': 'Contemplatio - Kontemplácia',
        'subtitle': 'Ticho s Bohom',
        'description': 'Spočinutie v Božej prítomnosti bez slov.',
        'duration': '20 min',
      },
      {
        'number': 6,
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

  static const Map<String, dynamic> _es = {
    'stepLabel': 'Paso',
    'heroTitle': 'Escucha lo que Dios quiere decirte',
    'heroSubtitle': 'Descubre la oración de Lectio Divina',
    'heroDescription':
        'En un mundo acelerado, donde todos hablan pero pocos escuchan, el silencio parece inalcanzable. Sin embargo, es precisamente allí donde puede resonar la voz de Dios.',
    'startLectio': 'Comienza con Lectio Divina',

    'whatIs': '¿Qué es Lectio Divina?',
    'whatIsText1':
        'Lectio Divina es una forma antigua de orar con la Biblia. No es una clase ni un análisis. No se trata del rendimiento. Es un encuentro — silencioso, personal, real. Por medio de la Palabra de Dios entramos en diálogo con Aquel que nos conoce profundamente.',
    'whatIsText2':
        'Nació en los primeros monasterios y la desarrollaron san Benito, Orígenes, san Gregorio de Nisa y el cartujo Guigo II. Hoy la redescubren personas de todas las edades que buscan una relación con Dios incluso fuera de los muros monásticos.',

    'fiveStepsTitle': 'Los seis pasos de Lectio Divina',
    'fiveStepsText':
        'Cada paso te acerca a una relación más profunda con Dios. Avanza a tu ritmo y deja que el Espíritu Santo guíe tu corazón.',

    'benefitsTitle': 'Lectura sagrada como encuentro',
    'benefitsText':
        'Practicar Lectio Divina con regularidad trae paz, claridad y crecimiento espiritual. Miles de cristianos en todo el mundo han experimentado su fuerza transformadora.',

    'howToTitle': 'Lectio Divina es para todos',
    'howToText':
        'No necesitas conocimientos especiales. Abre el corazón, elige un pasaje y da el primer paso. Dios se encargará del resto.',
    'startFirstStep': 'Iniciar el primer paso',

    'closingQuote':
        'La Palabra que llega hoy a ti te está buscando. Abre el corazón. Déjate encontrar.',
    'closingText':
        'Lectio Divina no es solo un método antiguo; es un camino vivo para el presente. La Palabra de Dios que toque tu corazón hoy puede cambiar tu día… y quizá tu vida entera.',

    'steps': [
      {
        'number': 1,
        'slug': 'silencio',
        'title': 'Silencio – Silencio',
        'subtitle': 'Puerta a la oración',
        'description':
            'Deténte. Haz silencio. Crea un espacio donde Dios pueda hablar.',
        'duration': '5 min',
      },
      {
        'number': 2,
        'slug': 'lectio',
        'title': 'Lectio – Lectura',
        'subtitle': 'Lectura atenta de la Palabra',
        'description':
            'Escucha lenta y concentrada de la voz de Dios en la Escritura.',
        'duration': '10 min',
      },
      {
        'number': 3,
        'slug': 'meditatio',
        'title': 'Meditatio – Meditación',
        'subtitle': 'Profundizar en el texto',
        'description': 'Permitimos que la Palabra baje de la mente al corazón.',
        'duration': '15 min',
      },
      {
        'number': 4,
        'slug': 'oratio',
        'title': 'Oratio – Oración',
        'subtitle': 'Conversar con Dios',
        'description': 'Diálogo sincero con Dios inspirado en su Palabra.',
        'duration': '10 min',
      },
      {
        'number': 5,
        'slug': 'contemplatio',
        'title': 'Contemplatio – Contemplación',
        'subtitle': 'Silencio con Dios',
        'description': 'Reposo en la presencia de Dios sin palabras.',
        'duration': '20 min',
      },
      {
        'number': 6,
        'slug': 'actio',
        'title': 'Actio – Vivir la Palabra',
        'subtitle': 'Llevar la Palabra a la vida',
        'description': 'Aplicar el Evangelio en los gestos cotidianos.',
        'duration': '5 min',
      },
    ],

    'benefits': [
      {
        'title': 'Escuchar la voz de Dios',
        'description':
            'En el silencio de Lectio Divina aprendemos a reconocer la voz de Dios y abrirle el corazón.',
      },
      {
        'title': 'Transformación del corazón',
        'description':
            'No es solo lectura: es un proceso de cambio interior guiado por la Palabra.',
      },
      {
        'title': 'Renovación y paz',
        'description':
            'En medio del ruido diario, el alma encuentra descanso en este encuentro silencioso.',
      },
      {
        'title': 'Para todos y en cualquier lugar',
        'description':
            'Puedes practicarla solo o en comunidad, sin preparación teológica previa.',
      },
    ],

    'guide': [
      {
        'title': 'Elige tiempo y lugar',
        'description':
            'Basta con 10-15 minutos diarios en un ambiente tranquilo. La constancia importa más que la duración.',
      },
      {
        'title': 'Selecciona un pasaje breve',
        'description':
            'No necesitas capítulos enteros. Unos versículos del Evangelio o de los salmos son suficientes.',
      },
      {
        'title': 'Ábrete a Dios',
        'description':
            'Inicia con una breve oración: "Señor, quiero escucharte. Abre mi corazón a tu Palabra".',
      },
      {
        'title': 'No tengas prisa',
        'description':
            'Lectio Divina no trata de velocidad ni de logros. Dios se encuentra contigo a tu propio ritmo.',
      },
    ],
  };

  static const Map<String, dynamic> _en = {
    'stepLabel': 'Step',
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

    'fiveStepsTitle': 'The Six Steps of Lectio Divina',
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
        'slug': 'silencio',
        'title': 'Silencio – Silence',
        'subtitle': 'Gateway to prayer',
        'description': 'Stop. Be still. Create a space where God can speak.',
        'duration': '5 min',
      },
      {
        'number': 2,
        'slug': 'lectio',
        'title': 'Lectio – Reading',
        'subtitle': 'Attentive reading of God\'s Word',
        'description':
            'Slow, focused listening to the voice of God through Scripture.',
        'duration': '10 min',
      },
      {
        'number': 3,
        'slug': 'meditatio',
        'title': 'Meditatio – Meditation',
        'subtitle': 'Deep reflection on the text',
        'description': 'Letting the Word move from the head to the heart.',
        'duration': '15 min',
      },
      {
        'number': 4,
        'slug': 'oratio',
        'title': 'Oratio – Prayer',
        'subtitle': 'Speaking with God',
        'description': 'A sincere dialogue with God, inspired by His Word.',
        'duration': '10 min',
      },
      {
        'number': 5,
        'slug': 'contemplatio',
        'title': 'Contemplatio – Contemplation',
        'subtitle': 'Silent being with God',
        'description': 'Resting in God\'s presence without words.',
        'duration': '20 min',
      },
      {
        'number': 6,
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

  static const Map<String, dynamic> _cz = {
    'stepLabel': 'Krok',
    'heroTitle': 'Naslouchej, co ti Bůh chce říct',
    'heroSubtitle': 'Objev modlitbu Lectio Divina',
    'heroDescription':
        'V rychlém světě, kde se hodně mluví, ale málo skutečně naslouchá, je stále těžší najít ticho. A přesto – právě ticho je místo, kde může zaznít Boží hlas.',
    'startLectio': 'Začni s Lectio Divina',

    'whatIs': 'Co je Lectio Divina?',
    'whatIsText1':
        'Lectio Divina je starobylá forma modlitby s Biblí, ale nečekej výklad ani analýzu. Není to přednáška. Není to ani výkon. Je to setkání – tiché, osobní, skutečné. Skrze Boží slovo vstupujeme do rozhovoru s Tím, kdo nás zná do hloubky.',
    'whatIsText2':
        'Tato forma vznikla v prvních klášterech a později ji rozvíjeli lidé jako sv. Benedikt, Origenes, sv. Řehoř z Nyssy či kartuzián Guigo II. Dnes si ji znovu osvojují lidé všech věků, kteří touží po vztahu s Bohem.',

    'fiveStepsTitle': 'Šest kroků Lectio Divina',
    'fiveStepsText':
        'Každý krok vás přiblíží k hlubšímu vztahu s Bohem. Postupujte svým tempem a nechte Ducha Svatého vést vaše srdce.',

    'benefitsTitle': 'Posvátné čtení jako setkání',
    'benefitsText':
        'Pravidelná praxe Lectio Divina přináší pokoj, jasnost a hlubší duchovní růst. Tisíce křesťanů po celém světě objevily transformační sílu této modlitby.',

    'howToTitle': 'Lectio Divina je pro všechny',
    'howToText':
        'Nepotřebujete žádné speciální znalosti. Stačí otevřít srdce, vybrat si text a začít prvním krokem. Bůh se postará o zbytek.',
    'startFirstStep': 'Začít s prvním krokem',

    'closingQuote':
        'Slovo, které k tobě dnes přichází, tě hledá. Otevři srdce. Nech se najít.',
    'closingText':
        'Lectio Divina není jen starobylá metoda – je to živá cesta pro dnešního člověka. Slovo Boha, které se dnes dotkne tvého srdce, může změnit celý tvůj den… a možná i celý tvůj život.',

    'steps': [
      {
        'number': 1,
        'slug': 'silencio',
        'title': 'Silencio - Ticho',
        'subtitle': 'Brána do modlitby',
        'description':
            'Zastav se. Ztichni. Vytvoř prostor, kde může Bůh promluvit.',
        'duration': '5 min',
      },
      {
        'number': 2,
        'slug': 'lectio',
        'title': 'Lectio - Čtení',
        'subtitle': 'Pozorné čtení Božího slova',
        'description':
            'Pomalé, soustředěné naslouchání Božímu hlasu skrze Písmo.',
        'duration': '10 min',
      },
      {
        'number': 3,
        'slug': 'meditatio',
        'title': 'Meditatio - Meditace',
        'subtitle': 'Hluboké rozjímání nad textem',
        'description': 'Necháváme Slovo proniknout z hlavy do srdce.',
        'duration': '15 min',
      },
      {
        'number': 4,
        'slug': 'oratio',
        'title': 'Oratio - Modlitba',
        'subtitle': 'Rozhovor s Bohem',
        'description': 'Upřímný dialog s Bohem na základě Jeho Slova.',
        'duration': '10 min',
      },
      {
        'number': 5,
        'slug': 'contemplatio',
        'title': 'Contemplatio - Kontemplace',
        'subtitle': 'Ticho s Bohem',
        'description': 'Spočinutí v Boží přítomnosti bez slov.',
        'duration': '20 min',
      },
      {
        'number': 6,
        'slug': 'actio',
        'title': 'Actio - Žít Boží slovo',
        'subtitle': 'Žít podle Božího slova',
        'description': 'Praktická aplikace do každodenního života.',
        'duration': '5 min',
      },
    ],

    'benefits': [
      {
        'title': 'Naslouchání Božímu hlasu',
        'description':
            'V tichu Lectio Divina se učíme rozpoznávat Boží hlas a otevírat mu srdce.',
      },
      {
        'title': 'Proměna srdce',
        'description':
            'Lectio Divina není jen čtení – je to proces proměny skrze Boží slovo.',
      },
      {
        'title': 'Obnova a pokoj',
        'description':
            'V rychlém světě nachází duše odpočinek v tichém setkání s Bohem.',
      },
      {
        'title': 'Pro všechny a všude',
        'description':
            'Můžete ji praktikovat sami nebo ve společenství, teologická příprava není potřeba.',
      },
    ],

    'guide': [
      {
        'title': 'Vyber si čas a místo',
        'description':
            'Stačí 10–15 minut denně v klidném prostředí. Důležitá je pravidelnost, ne délka.',
      },
      {
        'title': 'Vyber si krátký biblický text',
        'description':
            'Nepotřebuješ číst celé kapitoly. Stačí pár veršů z Evangelia nebo žalmů.',
      },
      {
        'title': 'Otevři se Bohu',
        'description':
            'Začni krátkou modlitbou: "Pane, chci Tě slyšet. Otevři mé srdce pro Tvé slovo."',
      },
      {
        'title': 'Nespěchej',
        'description':
            'Lectio Divina není o rychlosti ani výkonu. Bůh se přizpůsobuje tvému tempu.',
      },
    ],
  };

  // FRENCH (FR)
  static const Map<String, dynamic> _fr = {
    'stepLabel': 'Étape',
    'heroTitle': 'Écoute ce que Dieu veut te dire',
    'heroSubtitle': 'Découvre la prière de la Lectio Divina',
    'heroDescription':
        'Dans un monde effréné où beaucoup parlent mais peu écoutent vraiment, le silence devient plus difficile à trouver. Et pourtant — c\'est dans le silence que la voix de Dieu peut se faire entendre.',
    'startLectio': 'Commence par la Lectio Divina',

    'whatIs': 'Qu\'est-ce que la Lectio Divina ?',
    'whatIsText1':
        'La Lectio Divina est une forme ancienne de prière avec la Bible, mais n\'attends ni explication ni analyse. Ce n\'est pas une conférence. Ce n\'est pas non plus une performance. C\'est une rencontre – silencieuse, personnelle, réelle. À travers la Parole de Dieu, nous entrons en conversation avec Celui qui nous connaît en profondeur.',
    'whatIsText2':
        'Cette forme est née dans les premiers monastères et fut ensuite développée par des figures comme saint Benoît, Origène, saint Grégoire de Nysse et le chartreux Guigues II. Aujourd\'hui, des personnes de tous âges se la réapproprient, car elles désirent une relation avec Dieu – même hors des murs des monastères.',

    'fiveStepsTitle': 'Les six étapes de la Lectio Divina',
    'fiveStepsText':
        'Chaque étape te rapproche d\'une relation plus profonde avec Dieu. Avance à ton propre rythme, et laisse le Saint-Esprit guider ton cœur.',

    'benefitsTitle': 'La lecture sacrée comme rencontre',
    'benefitsText':
        'Une pratique régulière de la Lectio Divina apporte la paix, la clarté et une croissance spirituelle plus profonde. Des milliers de chrétiens à travers le monde ont découvert la puissance transformatrice de cette prière.',

    'howToTitle': 'La Lectio Divina est pour tout le monde',
    'howToText':
        'Tu n\'as besoin d\'aucune connaissance particulière. Ouvre simplement ton cœur, choisis un passage et fais le premier pas. Dieu se chargera du reste.',
    'startFirstStep': 'Commencer par la première étape',

    'closingQuote':
        'La Parole qui vient à toi aujourd\'hui te cherche. Ouvre ton cœur. Laisse-toi trouver.',
    'closingText':
        'La Lectio Divina n\'est pas seulement une méthode ancienne – c\'est un chemin vivant pour l\'homme d\'aujourd\'hui. La Parole de Dieu qui touche ton cœur aujourd\'hui peut changer toute ta journée… et peut-être même toute ta vie.',

    'steps': [
      {
        'number': 1,
        'slug': 'silencio',
        'title': 'Silencio – Silence',
        'subtitle': 'Porte d\'entrée de la prière',
        'description':
            'Arrête-toi. Fais silence. Crée un espace où Dieu peut parler.',
        'duration': '5 min',
      },
      {
        'number': 2,
        'slug': 'lectio',
        'title': 'Lectio – Lecture',
        'subtitle': 'Lecture attentive de la Parole de Dieu',
        'description':
            'Une écoute lente et concentrée de la voix de Dieu à travers l\'Écriture.',
        'duration': '10 min',
      },
      {
        'number': 3,
        'slug': 'meditatio',
        'title': 'Meditatio – Méditation',
        'subtitle': 'Méditation profonde sur le texte',
        'description': 'Nous laissons la Parole pénétrer de la tête au cœur.',
        'duration': '15 min',
      },
      {
        'number': 4,
        'slug': 'oratio',
        'title': 'Oratio – Prière',
        'subtitle': 'Conversation avec Dieu',
        'description': 'Un dialogue sincère avec Dieu, inspiré par sa Parole.',
        'duration': '10 min',
      },
      {
        'number': 5,
        'slug': 'contemplatio',
        'title': 'Contemplatio – Contemplation',
        'subtitle': 'Silence avec Dieu',
        'description': 'Repos dans la présence de Dieu sans paroles.',
        'duration': '20 min',
      },
      {
        'number': 6,
        'slug': 'actio',
        'title': 'Actio – Vivre la Parole de Dieu',
        'subtitle': 'Vivre selon la Parole de Dieu',
        'description': 'Application pratique dans la vie quotidienne.',
        'duration': '5 min',
      },
    ],

    'benefits': [
      {
        'title': 'Écoute de la voix de Dieu',
        'description':
            'Dans le silence de la Lectio Divina, nous apprenons à reconnaître la voix de Dieu et à lui ouvrir notre cœur.',
      },
      {
        'title': 'Transformation du cœur',
        'description':
            'La Lectio Divina n\'est pas seulement une lecture — c\'est un processus de changement intérieur par la Parole de Dieu.',
      },
      {
        'title': 'Renouvellement et paix',
        'description':
            'Dans un monde qui va vite, l\'âme trouve le repos dans la rencontre silencieuse avec Dieu.',
      },
      {
        'title': 'Pour tous, partout',
        'description':
            'Tu peux la pratiquer seul ou en communauté, aucune préparation théologique n\'est nécessaire.',
      },
    ],

    'guide': [
      {
        'title': 'Choisis un temps et un lieu',
        'description':
            'Il suffit de 10 à 15 minutes par jour dans un environnement calme. L\'important, c\'est la régularité, non la durée.',
      },
      {
        'title': 'Choisis un court passage de la Bible',
        'description':
            'Tu n\'as pas besoin de lire des chapitres entiers. Quelques versets des Évangiles ou des Psaumes suffisent.',
      },
      {
        'title': 'Ouvre-toi à Dieu',
        'description':
            'Commence par une courte prière : « Seigneur, je veux t\'entendre. Ouvre mon cœur à ta Parole. »',
      },
      {
        'title': 'Ne te précipite pas',
        'description':
            'La Lectio Divina n\'est pas une question de vitesse ni de performance. Dieu s\'adapte à ton rythme.',
      },
    ],
  };
}

#!/bin/bash

echo "🔕 AUTOMATICKÉ TESTOVANIE DO NOT DISTURB FUNKCIONALITY"
echo "======================================================"
echo

echo "📱 1. Spúšťam aplikáciu na Android emulátore..."
cd /Users/dusanpecko/lectiodivina/mobile

# Spustenie aplikácie
flutter run -d emulator-5554 > flutter_output.log 2>&1 &
FLUTTER_PID=$!

echo "⏳ Čakám 30 sekúnd na načítanie aplikácie..."
sleep 30

echo "✅ Aplikácia je spustená"
echo
echo "📋 MANUÁLNY TEST CHECKLIST:"
echo "=========================="
echo
echo "1. ✏️  Navigujte do Settings v aplikácii"
echo "   - Stlačte floating action button (plus ikonu)"
echo "   - Vyberte Settings z menu"
echo
echo "2. 🔕 Skontrolujte Do Not Disturb sekciu"
echo "   - Vidíte sekciu 'Automatické stlmenie notifikácií'?"
echo "   - Aký je status oprávnení (Permission Status)?"
echo "   - Sú dostupné nastavenia aktivácie?"
echo
echo "3. ⚙️  Povoľte oprávnenia (ak potrebné)"
echo "   - Ak permissions nie sú granted, stlačte 'Povoliť prístup'"
echo "   - Prejdite do system settings a povoľte 'Do Not Disturb access'"
echo "   - Vráťte sa do aplikácie"
echo
echo "4. 🎵 Testovanie automatickej aktivácie"
echo "   - Povoľte 'Aktivovať automaticky počas prehrávania'"
echo "   - Nastavte delay na 10 sekúnd (pre rýchle testovanie)"
echo "   - Prejdite do hlavnej obrazovky a spustite nejaké audio"
echo
echo "5. ⏰ Sledujte DND aktiváciu"
echo "   - Po 10 sekundách by sa malo aktivovať DND"
echo "   - Skontrolujte notification panel - mali by byť potlačené"
echo "   - Ukončite audio - DND by sa malo deaktivovať"
echo
echo "🔍 LOGOV MONITORING:"
echo "==================="
echo "V termináli sledujte tieto oznámenia:"
echo "- '🔕 Do Not Disturb activated'"
echo "- '🔕 Do Not Disturb deactivated'"
echo "- Chyby s DND permissions alebo aktiváciou"
echo
echo "💡 Pre ukončenie testovania stlačte Ctrl+C"
echo

# Sledovanie logov
echo "📊 Sledovanie Flutter logov (hľadám DND správy)..."
tail -f flutter_output.log | grep -E "(🔕|Do Not Disturb|DND|checkDndPermissions|activateAndroidDnd|deactivateAndroidDnd)" --line-buffered &
LOG_PID=$!

# Čakanie na interrupt
trap "echo; echo '🛑 Ukončujem test...'; kill $FLUTTER_PID 2>/dev/null; kill $LOG_PID 2>/dev/null; exit 0" INT

echo "⌚ Test beží... Stlačte Ctrl+C pre ukončenie."
wait $FLUTTER_PID
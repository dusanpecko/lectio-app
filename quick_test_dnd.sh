#!/bin/bash

echo "🔕 === QUICK TEST: DO NOT DISTURB FUNCTIONALITY ==="
echo ""

echo "📱 1. OTVOR APLIKÁCIU"
echo "   • Spusti Lectio Divina aplikáciu"
echo "   • Prejdi do Settings (⚙️ ikona)"
echo ""

echo "🔧 2. SKONTROLUJ NASTAVENIA"
echo "   • Nájdi sekciu 'Režim Nerušiť'"
echo "   • Skontroluj stav povolení"
echo "   • Ak sú potrebné povolenia, klikni 'Povoliť prístup'"
echo ""

echo "⚡ 3. QUICK TEST"
echo "   • Zapni 'Zapnúť automaticky'"
echo "   • Vráť sa na hlavnú obrazovku"
echo "   • Spusti akékoľvek audio"
echo ""

echo "⏱️ 4. ČAKAJ 30 SEKÚND"
echo "   • Timer sa spustí automaticky"
echo "   • Po 30 sekundách sa aktivuje DND"
echo "   • Android: Notification panel bude tichý"
echo ""

echo "🧪 5. OVERENIE"
echo "   • Pošli si test notifikáciu (email, SMS)"
echo "   • Mala by byť stlmená počas prehrávania"
echo ""

echo "🛑 6. UKONČENIE"
echo "   • Zastav audio prehrávanie"
echo "   • DND sa automaticky deaktivuje"
echo "   • Notifikácie sa vrátia do normálu"
echo ""

echo "🔍 7. DEBUGGING (ak niečo nefunguje)"
echo "   • flutter logs | grep '🔕'"
echo "   • Hľadaj: 'DND session started/ended'"
echo ""

echo "✅ EXPECTED: Počas audio = tichý režim, po zastavení = normálny režim"
echo "🔕 === TEST COMPLETE ==="
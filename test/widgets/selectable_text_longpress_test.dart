import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Overenie (23. 9. 2026): dlhý stisk na text kroku → výberové menu, bez
/// červenej obrazovky. Rozloženie ako karta kroku / čítačka: PageView →
/// Column → Expanded(SingleChildScrollView(GestureDetector(SelectableText))).
void main() {
  const longText =
      'Na počiatku bolo Slovo a Slovo bolo u Boha a to Slovo bolo Boh. '
      'Ono bolo na počiatku u Boha. Všetko povstalo skrze neho a bez neho '
      'nepovstalo nič z toho, čo povstalo. V ňom bol život a život bol svetlom ľudí.';

  Widget host(Widget textWidget) => MaterialApp(
        home: Scaffold(
          body: PageView(
            children: [
              Column(
                children: [
                  const SizedBox(height: 40),
                  Expanded(
                    child: SingleChildScrollView(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: textWidget,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(),
            ],
          ),
        ),
      );

  testWidgets('SelectableText: dlhý stisk vyberie slovo bez výnimky', (tester) async {
    await tester.pumpWidget(host(const SelectableText(longText)));
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.textEditingValue.selection.isCollapsed, isFalse,
        reason: 'po dlhom stisku má byť vybraté slovo');
  });

  testWidgets('SelectionArea + Text: dlhý stisk bez výnimky', (tester) async {
    await tester.pumpWidget(host(const SelectionArea(child: Text(longText))));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Text)),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

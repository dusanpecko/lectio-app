import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectio_divina/utils/ui_helpers.dart';
import 'package:lectio_divina/shared/app_colors.dart';

void main() {
  group('UIHelpers Tests', () {
    testWidgets('showSuccess displays a green SnackBar', (
      WidgetTester tester,
    ) async {
      const message = 'Success Message';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => UIHelpers.showSuccess(context, message),
                child: const Text('Show Success'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pump(); // Start animation

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, Colors.green);
    });

    testWidgets('showError displays a red SnackBar', (
      WidgetTester tester,
    ) async {
      const message = 'Error Message';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => UIHelpers.showError(context, message),
                child: const Text('Show Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, Colors.red);
    });

    testWidgets('showInfo displays a primary color SnackBar', (
      WidgetTester tester,
    ) async {
      const message = 'Info Message';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => UIHelpers.showInfo(context, message),
                child: const Text('Show Info'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Info'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, AppColors.primary);
    });

    testWidgets('showConfirmDialog returns true on Confirm', (
      WidgetTester tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await UIHelpers.showConfirmDialog(
                    context,
                    title: 'Title',
                    message: 'Message',
                  );
                },
                child: const Text('Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);

      await tester.tap(find.text('Áno'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('showConfirmDialog returns false on Cancel', (
      WidgetTester tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await UIHelpers.showConfirmDialog(
                    context,
                    title: 'Title',
                    message: 'Message',
                  );
                },
                child: const Text('Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nie'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    group('UIHelpersExtension', () {
      testWidgets('context.showSuccess works correctly', (
        WidgetTester tester,
      ) async {
        const message = 'Extension Success';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => context.showSuccess(message),
                  child: const Text('Extension'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Extension'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.green);
      });
    });
  });
}

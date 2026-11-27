import 'package:cofradeo/features/historias/models/historia_reading_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_flip/page_flip.dart';

void main() {
  test('sin marca, el lector abre en la primera hoja de texto', () {
    expect(historiaReaderStartPage(0, 4), 1);
    expect(historiaReaderStartPage(3, 4), 3);
    expect(historiaReaderStartPage(9, 4), 1);
    expect(historiaReaderStartPage(0, 0), 0);
  });

  testWidgets('un toque a la derecha muestra la hoja siguiente', (tester) async {
    int? flipped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            initialIndex: 1,
            onPageFlipped: (page) => flipped = page,
            children: const [
              ColoredBox(
                color: Color(0xFF2A1210),
                child: Center(child: Text('portada')),
              ),
              ColoredBox(
                color: Color(0xFFFBF6EA),
                child: Center(child: Text('primera hoja')),
              ),
              ColoredBox(
                color: Color(0xFFFBF6EA),
                child: Center(child: Text('segunda hoja')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('primera hoja'), findsOneWidget);
    expect(find.text('portada'), findsNothing);

    await tester.tapAt(const Offset(600, 300));
    await tester.pump();

    expect(flipped, 2);
    expect(find.text('segunda hoja'), findsOneWidget);
    expect(find.text('primera hoja'), findsNothing);
  });

  testWidgets('un toque a la izquierda vuelve a la portada', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            initialIndex: 1,
            children: const [
              ColoredBox(
                color: Color(0xFF2A1210),
                child: Center(child: Text('portada')),
              ),
              ColoredBox(
                color: Color(0xFFFBF6EA),
                child: Center(child: Text('primera hoja')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(40, 300));
    await tester.pump();

    expect(find.text('portada'), findsOneWidget);
    expect(find.text('primera hoja'), findsNothing);
  });
}

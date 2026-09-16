import 'package:cofradeo/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _scrollDown(WidgetTester tester) async {
  for (final type in [CustomScrollView, ListView]) {
    final scrollable = find.byType(type);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -400));
      await tester.pumpAndSettle();
      return;
    }
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es', null);
  });

  testWidgets('Círculo Cofrade abre en Calendario', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendario'), findsWidgets);

    await _scrollDown(tester);
    expect(find.text('Días destacados'), findsOneWidget);
  });

  testWidgets('Al pulsar un día muestra su evento', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // En la cabecera se muestra una franja semanal, así que el día visible
    // en tests depende del "selectedDate" inicial. Con el dataset mock, el
    // día 23 tiene eventos como "Concierto de marchas".
    await tester.tap(find.text('23').last);
    await tester.pumpAndSettle();

    // En el carousel se muestra primero el evento "más temprano" (por hora).
    await tester.tap(find.text('Traslado del Cristo').first);
    await tester.pumpAndSettle();

    expect(find.text('Detalle del evento'), findsOneWidget);
    // Puede aparecer tanto en el carousel (slide) como dentro del bottom sheet.
    expect(find.text('Traslado del Cristo'), findsWidgets);
  });

  testWidgets('Foro abre hilo con respuestas', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Foros').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Círculo Cofrade'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Nueva ruta de la procesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Escribe una respuesta…'), findsOneWidget);

    await _scrollDown(tester);

    // El título se renderiza en mayúsculas.
    expect(find.text('RESPUESTAS'), findsOneWidget);
    expect(find.text('@jose_carpintero'), findsWidgets);
    expect(find.text('Resuelto'), findsOneWidget);
    expect(find.text('Escribe una respuesta…'), findsOneWidget);
  });

  testWidgets('Buscar filtra temas y rellena desde recientes', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();

    expect(find.text('Tendencias'), findsOneWidget);
    expect(find.text('#ViernesSanto'), findsOneWidget);

    await _scrollDown(tester);

    expect(find.text('Recientes'), findsOneWidget);

    await tester.tap(find.text('itinerario'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Resultados'), findsOneWidget);
    expect(find.textContaining('Itinerario extraordinario'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'banda',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('Banda de la procesión'), findsOneWidget);
  });

  testWidgets('Perfil sin sesión no muestra mock y abre login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Hermandad Sevilla'), findsNothing);
  });

  testWidgets('Notificaciones lista mock y quita punto rojo en Foros', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Foros').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_outlined).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('#ViernesSanto'), findsOneWidget);
    expect(find.text('Hermandad Sevilla publicó'), findsOneWidget);

    // Al abrir Notificaciones se marcan como leídas (desaparece el punto rojo).
    await tester.tap(find.text('Calendario').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foros').last);
    await tester.pumpAndSettle();

    final dotFinder = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color ==
              const Color(0xFFE53935) &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    expect(dotFinder, findsNothing);

    // Algunos widgets (p. ej. VisibilityDetector) crean timers internos para
    // medir visibilidad. Si se desmontan justo al terminar el test, Flutter
    // marca "timersPending" y falla.
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('Atajo calendario desde Buscar y hilo', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calendario'));
    await tester.pumpAndSettle();

    expect(find.text('CALENDARIO'), findsWidgets);

    await tester.tap(find.text('Foros').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Círculo Cofrade'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nueva ruta de la procesión').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calendario'));
    await tester.pumpAndSettle();

    expect(find.text('CALENDARIO'), findsWidgets);
  });

  testWidgets('Perfil sin sesión abre login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('INICIAR SESIÓN'), findsOneWidget);
  });
}

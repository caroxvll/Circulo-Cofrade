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
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Junio 2026'), findsOneWidget);

    await _scrollDown(tester);
    expect(find.text('Eventos del mes'), findsOneWidget);
  });

  testWidgets('Al pulsar un día muestra su evento', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();

    await _scrollDown(tester);

    expect(find.textContaining('Concierto de marchas'), findsOneWidget);
    expect(find.text('Limpiar'), findsOneWidget);
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

    await tester.tap(find.text('Foro Cofradiero'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Nueva ruta de la procesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Escribe una respuesta…'), findsOneWidget);

    await _scrollDown(tester);

    expect(find.text('Respuestas'), findsOneWidget);
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

    expect(find.text('Búsquedas Recientes'), findsOneWidget);

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

  testWidgets('Perfil muestra tabs Publicaciones y Acerca de', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    expect(find.text('Hermandad Sevilla'), findsOneWidget);
    expect(find.text('@hermandad_sevilla'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('15.2K'), findsOneWidget);

    await tester.tap(find.text('Acerca de'));
    await tester.pumpAndSettle();

    await _scrollDown(tester);

    expect(find.text('Información'), findsOneWidget);
    expect(find.text('Calle Sierpes, 12, Sevilla'), findsOneWidget);
    expect(find.text('Fundada en 1565'), findsOneWidget);
    expect(find.text('www.hermandadsevilla.es'), findsOneWidget);

    await tester.tap(find.text('Publicaciones'));
    await tester.pumpAndSettle();

    expect(find.text('Próximamente'), findsOneWidget);
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

    expect(find.text('Junio 2026'), findsOneWidget);

    await tester.tap(find.text('Foros').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foro Cofradiero'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nueva ruta de la procesión').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calendario'));
    await tester.pumpAndSettle();

    expect(find.text('Junio 2026'), findsOneWidget);
  });

  testWidgets('Perfil invitado abre pantalla de login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CofradeoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    expect(find.text('Modo invitado'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar con Google'), findsOneWidget);

    await _scrollDown(tester);

    expect(find.text('Explorar sin cuenta'), findsOneWidget);
  });
}

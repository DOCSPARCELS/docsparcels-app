import 'package:flutter_test/flutter_test.dart';

import 'package:docsparcels_app/main.dart';
import 'package:docsparcels_app/schermate/profilo.dart';
import 'package:docsparcels_app/testi.dart';

void main() {
  test('i testi esistono nelle tre lingue', () {
    for (final lingua in Testi.lingue) {
      expect(Testi.chiavi(lingua), Testi.chiavi('it'), reason: 'chiavi diverse in $lingua');
      final t = Testi(lingua);
      expect(t.t('entra').isNotEmpty, true);
      expect(t.errore('credenziali_errate') != t.errore('codice_inventato'), true);
    }
  });

  testWidgets('senza chiave si apre la schermata di entrata', (tester) async {
    await tester.pumpWidget(const AppDocsParcels(conChiave: false));
    await tester.pump();
    expect(find.text("Doc's & Parcels"), findsOneWidget);
  });

  test('credito con il separatore delle migliaia', () {
    expect(SchermataProfiloState.euro(1000, 'it'), '€ 1.000,00');
    expect(SchermataProfiloState.euro(1234567.5, 'es'), '€ 1.234.567,50');
    expect(SchermataProfiloState.euro(1000, 'en'), '€ 1,000.00');
    expect(SchermataProfiloState.euro(12.3, 'it'), '€ 12,30');
    expect(SchermataProfiloState.euro(1000, 'fr'), '€ 1 000,00');
    expect(SchermataProfiloState.euro(1000, 'de'), '€ 1.000,00');
    expect(SchermataProfiloState.euro(-1500, 'it'), '€ -1.500,00');
  });
}

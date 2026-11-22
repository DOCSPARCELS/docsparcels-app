import 'package:flutter_test/flutter_test.dart';

import 'package:docsparcels_app/main.dart';
import 'package:docsparcels_app/schermate/profilo.dart';
import 'package:docsparcels_app/schermate/scheda_ritiro.dart';
import 'package:docsparcels_app/servizi/api.dart';
import 'package:docsparcels_app/testi.dart';
import 'package:docsparcels_app/widget/barra.dart';

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
    // Nota 373 V3: al posto della scritta c'e' il logo
    expect(find.byType(LogoApp), findsOneWidget);
  });

  test('CAP una volta sola nella riga del luogo', () {
    expect(Api.rigaLuogo('00185', 'Roma 00185', 'RM', 'Italia'), '00185 Roma RM Italia');
    expect(Api.rigaLuogo('00185', '00185 Roma', 'RM', 'Italia'), '00185 Roma RM Italia');
    expect(Api.rigaLuogo('20121', 'Milano', 'MI'), '20121 Milano MI');
    expect(Api.rigaLuogo('', 'Dubai', '', 'Emirati Arabi Uniti'), 'Dubai Emirati Arabi Uniti');
  });

  test('note del ritiro senza annotazioni interne', () {
    expect(SchermataSchedaRitiro.noteCliente('\n[Email Fornitore] CP: 123'), '');
    expect(SchermataSchedaRitiro.noteCliente('Citofono 4\r\n[Manuale] x\nsecondo piano'), 'Citofono 4 · secondo piano');
    expect(SchermataSchedaRitiro.noteCliente(null), '');
  });

  test('numero della fattura senza anno', () {
    expect(Api.numeroFattura('399/2026'), '399');
    expect(Api.numeroFattura('NC 20/2026'), 'NC 20');
    expect(Api.numeroFattura('399'), '399');
    expect(Api.numeroFattura(null), '');
  });

  test("dogana solo fuori dall'Unione Europea", () {
    const ue = {'IT', 'DE', 'ES'};
    const territori = {'ES': {'35': 'IC', '38': 'IC', '51': 'ES-CE', '52': 'ES-ML'}};
    expect(Api.fuoriUe('IT', '00185', ue, territori), false);
    expect(Api.fuoriUe('de', '35037', ue, territori), false);
    expect(Api.fuoriUe('ES', '28001', ue, territori), false);
    expect(Api.fuoriUe('ES', '35001', ue, territori), true);
    expect(Api.fuoriUe('ES', '52001', ue, territori), true);
    expect(Api.fuoriUe('US', '50011', ue, territori), true);
    expect(Api.fuoriUe('', '', ue, territori), false);
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

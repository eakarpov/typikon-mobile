import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:typikon/components/study_source_text.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/utils/script_convert.dart';

void main() {
  for (final setting in [scriptAsSource, scriptCivil])
    testWidgets(
      'selected second occurrence retains source offset with $setting',
      (t) async {
        const raw = 'Сло́во **ѿрокъ** и ѿрокъ';
        String? quote;
        int? offset;
        await t.pumpWidget(
          StoreProvider<AppState>(
            store: Store<AppState>(appReducer, initialState: AppState.init()),
            child: MaterialApp(
              home: Scaffold(
                body: StudySourceText(
                  text: raw,
                  script: TextScript.church,
                  setting: setting,
                  onSelection: (q, o) {
                    quote = q;
                    offset = o;
                  },
                  onAction: (_) {},
                  onFootnote: (_) {},
                ),
              ),
            ),
          ),
        );
        final text = t.widget<SelectableText>(find.byType(SelectableText)),
            plain = text.textSpan!.toPlainText();
        final word = presentScript('ѿрокъ', TextScript.church, setting),
            start = plain.lastIndexOf(word);
        text.onSelectionChanged!(
          TextSelection(baseOffset: start, extentOffset: start + word.length),
          SelectionChangedCause.toolbar,
        );
        expect(quote, 'ѿрокъ');
        expect(offset, raw.lastIndexOf('ѿрокъ'));
        expect(t.takeException(), isNull);
      },
    );
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:typikon/pages/book_page.dart';
import 'pages/library_page.dart';
import 'pages/main_page.dart';
import 'pages/text_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Typikon',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate
      ],
      supportedLocales: [
        const Locale('ru'),
      ],
      restorationScopeId: "root",
      initialRoute: '/',
      // routes: {
      //   '/': (context) => const MainPage(),
      //   '/library': (context) => const LibraryPage(),
      //   '/library/:id': (context) => const BookPage(),
      // },
      onGenerateRoute: (RouteSettings settings) {
        final arguments = settings.arguments;
        switch (settings.name) {
          case '/library':
            if (arguments is String) {
              return MaterialPageRoute(
                builder: (context) {
                  return BookPage(
                    context,
                    id: arguments,
                  );
                },
              );
            } else {
              return MaterialPageRoute(
                builder: (context) {
                  return LibraryPage(context);
                },
              );
            }
          case "/reading":
            if (arguments is String) {
              return MaterialPageRoute(
                builder: (context) {
                  return TextPage(
                    context,
                    id: arguments,
                  );
                },
              );
            }
            return null;
          case "/":
            return MaterialPageRoute(
              builder: (context) {
                return MainPage(context);
              },
            );
          default:
            return null;
        }
      },
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
    );
  }
}
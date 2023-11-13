import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:typikon/pages/book_page.dart';
import 'pages/library_page.dart';
import 'pages/main_page.dart';
import 'pages/text_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  var _hasSkippedUpdate = false;

  void _handleTapboxChanged(bool val) {
    setState(() {
      _hasSkippedUpdate = val;
    });
  }

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
                return MainPage(
                    context,
                    hasSkippedUpdate: _hasSkippedUpdate,
                    skipUpdateWindow: _handleTapboxChanged,
                );
              },
            );
          default:
            return null;
        }
      },
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: TextTheme(
          // bodyText1: TextStyle(fontSize: 18.0),
          // bodyText2: TextStyle(fontSize: 16.0),
          // button: TextStyle(fontSize: 16.0),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      ),
    );
  }
}
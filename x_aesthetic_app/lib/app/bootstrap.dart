import 'package:flutter/widgets.dart';
import 'package:x_aesthetic_app/app/app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XAestheticApp());
}

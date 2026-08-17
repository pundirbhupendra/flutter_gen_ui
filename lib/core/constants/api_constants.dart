import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get openRouterKey => dotenv.get('OPEN_ROUTER_API_KEY');
}

import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env.local', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'GOOGLE_MAPS_API_KEY')
  static String googleMapsAPIKey = _Env.googleMapsAPIKey;
}

import 'package:shared_preferences/shared_preferences.dart';

class OpenRouterModelStore {
  OpenRouterModelStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String defaultModel = 'openrouter/free';

  static const String _modelKey = 'open_router_model';

  final SharedPreferencesAsync _preferences;

  Future<String> getModel() async {
    final storedModel = await _preferences.getString(_modelKey);
    final model = storedModel?.trim();

    if (model == null || model.isEmpty) {
      return defaultModel;
    }

    return model;
  }

  Future<void> saveModel(String model) async {
    final trimmedModel = model.trim();

    if (trimmedModel.isEmpty) {
      throw ArgumentError.value(
        model,
        'model',
        'The model name cannot be empty.',
      );
    }

    await _preferences.setString(_modelKey, trimmedModel);
  }

  Future<void> resetModel() async {
    await _preferences.remove(_modelKey);
  }
}

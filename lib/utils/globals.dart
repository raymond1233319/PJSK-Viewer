class AppGlobals {
  static String databaseUrl = 'https://sekai-world.github.io';
  static String assetUrl = 'https://storage.sekai.best';
  static String localizationUrl = 'https://i18n-json.sekai.best';
  static String apiUrl = 'https://api.sekai.best';
  static String region = 'jp';
  static String jpAssetUrl = 'https://storage.sekai.best/sekai-jp-assets';
  static String jpDatabaseUrl = 'https://sekai-world.github.io/sekai-master-db-diff';
  static void reset() {
    databaseUrl = 'https://sekai-world.github.io';
    assetUrl = 'https://storage.sekai.best';
    localizationUrl = 'https://i18n-json.sekai.best';
    apiUrl = 'https://api.sekai.best';
    region = 'jp';
    jpAssetUrl = 'https://storage.sekai.best/sekai-jp-assets';
  }
}

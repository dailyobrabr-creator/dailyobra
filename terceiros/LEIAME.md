# Pacotes de terceiros com ajuste local

- `flutter_inappwebview_android` 1.1.3 (licença Apache-2.0, em LICENSE): cópia do pub.dev usada pelo
  `dependency_overrides` do app `dailyobra`. Única mudança: `android/build.gradle` usa
  `proguard-android-optimize.txt`, porque o Android Gradle Plugin 9 recusa `proguard-android.txt`.
  Serve para a leitura de foto e PDF no app Android (WebView escondido). Trocar pela versão do pub.dev
  quando sair uma compatível com o AGP 9.

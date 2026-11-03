{{flutter_js}}
{{flutter_build_config}}

// Carrega o app e tira a tela de abertura quando ele começa a desenhar
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const abertura = document.getElementById('abertura');
    if (abertura) {
      abertura.classList.add('saindo');
      setTimeout(() => abertura.remove(), 250);
    }
  },
});

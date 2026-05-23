{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      fontFallbackBaseUrl: 'assets/fonts/'
    });
    await appRunner.runApp();
  }
});

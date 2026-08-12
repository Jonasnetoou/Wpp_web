# WhatsApp Web Wrapper (Flutter)

## Como subir pro GitHub e buildar sem PC

1. No app ou site do GitHub (pelo celular mesmo), crie um repositório novo,
   ex. `wpp-web-wrapper` (deixe Private)
2. **Add file → Upload files** → arraste a pasta `wpp_web_wrapper` inteira
   (mantendo a estrutura de pastas) → **Commit changes**
3. Aba **Actions** → workflow "Build APK" → **Run workflow**
4. Espere uns 5-10 minutos
5. Entre na execução concluída → **Artifacts** → baixe `app-release-apk`
   (.zip com o `.apk` dentro)
6. Extraia e instale (libere "instalar de fontes desconhecidas" se pedir)

## ⚠️ Não consegui compilar/testar aqui

Ambiente sem Flutter SDK/Android SDK. Se o Actions der erro de versão de
Gradle/Kotlin na primeira tentativa, me manda o log da aba Actions que eu
ajusto.

## O que tem implementado

1. Upload de arquivo (`file_picker` + `onShowFileChooser`)
2. Permissões completas no manifest (`FOREGROUND_SERVICE_DATA_SYNC` p/
   Android 14+)
3. Tela de erro com botão de recarregar
4. Pause/resume do WebView em background/foreground
5. Ajuste de layout via viewport
6. Botão de logout (limpa cookies/sessão)

## Configuração no Black Shark 4 Pro

- Bateria → Sem restrições para o app
- Apps recentes → travar com o cadeado
- Configurações → Apps → [app] → Bateria → Sem otimização

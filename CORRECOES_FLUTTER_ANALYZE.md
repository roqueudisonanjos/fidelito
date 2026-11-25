# Correções do Flutter Analyze

Nesta versão foram tratados os apontamentos que constavam no relatório enviado:

- O teste de widget foi atualizado para iniciar o `VantyApp` real e verificar a tela de login, em vez de testar o contador padrão do template Flutter (`MyApp`).
- Os `RadioListTile` passaram a usar `RadioGroup`, removendo os parâmetros obsoletos `groupValue` e `onChanged` dos tiles.
- O campo de seleção de relatórios passou de `value` para `initialValue`.
- Foram removidos casts e operadores `!` desnecessários.
- Os `print()` do leitor de QR Code foram substituídos por `debugPrint()`.
- Foram removidos métodos privados sem uso, preservando a ação de WhatsApp que é chamada pela tela.
- O fluxo de criação de benefício passou a capturar `NavigatorState` e `ScaffoldMessengerState` antes dos `await`, evitando o uso de `BuildContext` após lacunas assíncronas.

**Validação:** o ambiente usado para preparar este ZIP não possui Flutter/Dart instalado. Portanto, as alterações foram revisadas no código, mas `flutter analyze` e `flutter test` precisam ser executados no computador de desenvolvimento.

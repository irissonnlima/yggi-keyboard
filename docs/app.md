# Yggi · app do computador

> Decisões e arquitetura. Como compilar e rodar: [app/README.md](../app/README.md).
> Funcionalidades de referência: [funcionalidades.md](funcionalidades.md), seção 2.

## Decisões

| | Decisão |
|---|---|
| ✅ Plataforma | **macOS** primeiro. O núcleo é portável, para Windows e Linux (e iOS) virem depois só com interface nova. |
| ✅ Divisão | **Núcleo em Rust** com toda a lógica + **interface nativa** em cada sistema (SwiftUI no macOS). Ponte gerada pelo **UniFFI**. |
| ✅ Forma no Mac | **barra de menus** (estado rápido) + **janela** (ajustes, simulador, depois o editor). Sem ícone no Dock. |
| ✅ Editor de teclas | falar o **protocolo do ZMK Studio** (RPC em protobuf, por USB ou Bluetooth), com editor próprio. Vem depois da tela de estado. |
| ✅ Estatísticas de digitação | tela desenhada e implementada com **dados simulados**. Onde contar de verdade (teclado ou app) ainda está em aberto. |
| ✅ Luzes | **LED RGB em cada tecla** (a luz passa pela legenda), em 3 camadas: efeito geral < cores por tecla < teclas de ação. As regras ficam gravadas no teclado. Os **LEDs de computador** são outra coisa: um por computador, só brancos. |
| ✅ E-reader | aparelho à parte, na **mesma cor do teclado**, que encaixa na lateral esquerda. O teclado funciona sem ele. |
| ✅ Aparência | tema claro e escuro, **seguindo o sistema** por padrão (Ajustes › Aparência). |
| ✅ Design | [canvas no Claude](https://claude.ai/artifact/6vRzYKWAszEfThTY9fC1pt): barra lateral estilo Finder, teclado desenhado à direita. |
| ✅ Firmware | ainda não existe: o núcleo tem um **teclado simulado** atrás da mesma interface que o teclado real vai usar. |
| ✅ Primeira entrega | tela de estado (2.1): computador ativo, bateria das duas metades, conexão, alimentada pelo simulador. |

## Arquitetura

```
 interface (por sistema)             núcleo yggi-core (Rust, igual em todos)
┌──────────────────────────┐        ┌─────────────────────────────────────────┐
│ macOS: SwiftUI           │ chama  │ KeyboardSession                         │
│   barra de menus, janela │ ─────▶ │   state, subscribe, connect,            │
│   KeyboardStore          │        │   disconnect, select_host               │
│                          │ ◀───── │                                         │
│ Windows, Linux: depois   │ avisa  │ Keyboard (interface)                    │
└──────────────────────────┘        │   ├─ Simulator          hoje            │
         ponte: UniFFI              │   ├─ BluetoothKeyboard  depois          │
                                    │   └─ ZMKStudioClient    depois          │
                                    └─────────────────────────────────────────┘
```

**Regra da divisão:** a interface só desenha e repassa cliques. Tudo que seria igual em qualquer sistema fica no núcleo: estado, regras (ex.: o que é bateria baixa), simulador, protocolos, mensagens de erro (em português).

- **Modelo** (`KeyboardState`): conexão (desconectado, conectando, conectado por Bluetooth ou USB), cada metade (alcançável, bateria e se está carregando), computador ativo e as 5 vagas de computador (nome, pareado, se é este computador).
  Também o estado físico: abertura do stagger (0 a 100%), metades juntas ou separadas, e-reader (encaixado, solto, ausente), caps lock e pareamento.
- **Layout** (`yggiLayout`): as 79 teclas, as 8 colunas móveis e quanto cada uma sobe (`columnLift`). As interfaces desenham a partir daqui.
- **Luzes** (`LightingConfig` + `LightingEngine`): a config é o que vai ao teclado; o motor calcula, quadro a quadro, a cor e a intensidade de cada tecla (efeitos, camadas, reação ao toque, onda ao encaixar o e-reader, brilho de 0 a 100%). Todas as interfaces desenham igual.
- **Estatísticas** (`Statistics`): totais, velocidade por hora/dia/semana, contagem por tecla (mapa de calor), divisão por computador, ortho × stagger. Hoje vêm de `simulatedStatistics`.
- **Marca e ícone da barra** (`brand.rs`): a marca do Yggi em cápsulas (`yggiMark`) e o teclado em miniatura (`keyboardGlyph`, `menuBarGlyph`): uma barrinha por coluna, que sobe com o stagger pela mesma curva do layout, as metades se afastam quando separadas, e fica apagado quando desconectado. O ícone do app sai de `docs/brand/yggi-icone.svg` com `swift scripts/make-icons.swift`.
- **No Mac**, o ícone da barra, o balão (`NSPopover`) e as janelas ficam no `AppDelegate` (AppKit); as telas continuam em SwiftUI.
- **Barra de menus** (`MenuBarConfig`, `menubar.rs`): o popover é montado em abas (até 6) com widgets numa grade de 3 colunas. Há 16 widgets (stagger, computadores, bateria, luz, escrita, pausa, atalhos, firmware…), cada um com os tamanhos que aceita entre 1×1, 2×1, 3×1, 2×2 e 3×2.
  O núcleo guarda o catálogo (`widgetCatalog`) e a posição de cada widget (coluna e linha): a grade respeita células vazias. `menuCanPlace` diz se um tamanho cabe numa célula, `menuPlaceWidget` põe o widget onde foi solto, `menuMoveWidgetToTab` e `menuAddWidget` sem célula usam o primeiro lugar livre, e `menuCompactTab` tira os buracos. Cada operação devolve uma config nova e ignora pedidos inválidos.
  A config vira texto (`menuBarEncode`/`menuBarDecode`; lê também a versão 1, sem posições, e tolera widgets de versões mais novas). Hoje fica no Mac; quando houver firmware, pode ir para o teclado. No app, "Barra de menus" na janela é o editor: a prévia mostra as células, arrastar mostra onde o widget cai (azul se cabe, vermelho se cobre outro), parar sobre uma aba abre ela, a biblioteca fica embaixo e soltar nela remove.
- **`Keyboard`**: a interface que o simulador e o teclado real implementam. As interfaces nunca a veem, só `KeyboardSession`.
- **Avisos**: a interface se inscreve com um `StateListener` e recebe cada mudança de estado. O núcleo avisa de qualquer thread; cada interface leva o aviso para a sua thread de tela.
- **Simulador**: cenários prontos (normal, bateria baixa, carregando, metade direita sem sinal, com outro computador, desconectado). Com o tempo passando, a bateria desce 1% a cada 3 s (esquerda) ou 5 s (direita) e sobe no USB. Ele mostra só o que o app veria de verdade: desconectado, não há bateria nem computador ativo.
- **Teclado real** (quando houver firmware): a bateria vem do Battery Service padrão. O ZMK repassa a da metade direita com `SPLIT_BLE_CENTRAL_BATTERY_LEVEL_PROXY`. O computador ativo e os nomes vêm de um serviço Yggi próprio (módulo ZMK). O transporte de bytes é uma interface: `btleplug` por padrão, e um adaptador nativo onde for preciso (ex.: no macOS, um teclado já conectado não anuncia a presença e precisa ser pedido ao CoreBluetooth).
- **Editor**: `ZMKStudioClient` no núcleo, com as mensagens protobuf do ZMK Studio (`prost`), sobre o mesmo transporte.

**Versões:** macOS 14+ (Observation, MenuBarExtra), Swift 6 com checagem estrita de concorrência, Rust edição 2024, UniFFI 0.32.

## Perguntas em aberto

1. **Nomes dos computadores.** Quem guarda o nome ("MacBook trabalho"): o teclado (aparece em qualquer computador e no e-reader) ou o app? O modelo já tem o campo, e o simulador usa nomes fixos.
2. **Computador ativo sem o módulo Yggi.** Só com o ZMK padrão, o Mac sabe apenas se o teclado está com ele. A proposta é o módulo Yggi publicar o perfil ativo, e o simulador já mostra a versão completa.

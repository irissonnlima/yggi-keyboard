# Arquitetura do app

O app é um **monolito modular**: um núcleo em Rust (`app/core`, crate `yggi-core`) com toda a lógica, e uma casca fina por sistema (hoje só o macOS, em SwiftUI + AppKit) que desenha e repassa gestos. Tudo vive num repositório e num binário, mas com fronteiras que os testes conferem.

```
┌──────────────────────── macOS (app/macos) ─────────────────────────┐
│ AppDelegate       ícone na barra, balão, janelas (AppKit)          │
│ MenuBarIcon       ícone animado que segue o teclado                │
│ KeyboardStore     guarda o último estado e repassa comandos        │
│ Views/…           telas e widgets: só desenham o que o núcleo diz  │
└──────────────────────────────┬─────────────────────────────────────┘
                   ponte UniFFI │ (tipos de valor + KeyboardSession)
┌──────────────────────────────┴───── núcleo (app/core) ─────────────┐
│ fachada    session     o que as interfaces enxergam                │
│ adaptador  simulator   teclado simulado (depois: Bluetooth, ZMK)   │
│ porta      keyboard    o que um teclado oferece (trait Keyboard)   │
│ domínio    lighting · stats · brand   regras puras                 │
│ base       model · layout · menubar   tipos e regras sem estado    │
└─────────────────────────────────────────────────────────────────────┘
```

## Regras

1. **Lógica fica no núcleo.** Se a regra seria igual no Windows ou no Linux, ela é Rust: estado, validação, geometria do teclado, encaixe da grade, desenho da marca e do ícone, formato de gravação. A casca converte unidades em pontos e trata gestos.
2. **Cada módulo só usa as camadas de baixo.** Base não depende de ninguém; domínio só da base; a porta não conhece o simulador; só a sessão junta tudo. `app/core/tests/arquitetura.rs` confere isso no código-fonte e falha se um módulo novo não tiver camada.
3. **Módulos puros não têm estado nem relógio.** `model`, `layout`, `menubar`, `stats` e `brand` não usam travas, threads nem hora. Toda operação da barra de menus recebe a config e devolve outra.
4. **Uma fonte para cada coisa.** A geometria do teclado simplificado sai de `keyboard_shape`, e a marca sai de `yggi_mark`, que um teste compara com os SVGs de `docs/brand/`. Nada de refazer a mesma conta em Swift.
5. **Aviso é erro.** Rust (`clippy -D warnings`, `cargo fmt --check`) e Swift (`SWIFT_TREAT_WARNINGS_AS_ERRORS`).

## Testes

| Onde | O que cobre | Como rodar |
|---|---|---|
| `core/src/*` (`#[cfg(test)]`) | regras de cada módulo, casos de regressão com o nome do bug | `cargo test` |
| `core/src/menubar.rs` | 20 sementes × 300 edições aleatórias sem quebrar a grade nem a gravação | idem |
| `core/tests/arquitetura.rs` | camadas e pureza dos módulos | idem |
| `core/tests/marca.rs` | SVG da marca = desenho do núcleo | idem |
| `macos/Yggi/Verificacoes.swift` | a cola com o macOS (abaixo) | `Yggi --verificar` |
| `macos/Yggi/Snapshots.swift` | desenha telas, widgets e ícones em PNG para olhar | `make snapshots` |

`make test` roda os testes do núcleo e as verificações; `make check` também formato, lint e imagens. O CI (`.github/workflows/app.yml`) roda o mesmo a cada push.

## Regressões que já aconteceram e o que as segura

| Regressão | Causa | Guarda |
|---|---|---|
| Ícone da barra parou de mudar; botões do balão não abriam janelas | `AppDelegate.shared` lia `NSApp.delegate`, que o SwiftUI ocupa com outro objeto | verificação "AppDelegate.shared…" e "o ícone da barra segue o teclado"; ícone isolado em `MenuBarIcon` |
| Janela cortava a barra lateral e a biblioteca | tela mais larga que o mínimo da janela | `MainView.minimumSize` + verificação "toda seção cabe na janela mínima" (já pegou "Luzes e efeitos" pedindo 1204 com mínimo 1100) |
| Janela sempre por cima / em outra mesa; app fora do Dock | `LSUIElement` + `fullScreenAuxiliary`/`moveToActiveSpace` | verificações "janela comum" e "app normal" |
| Mapa de calor com vão entre as metades juntas | geometria refeita em Swift, esquecendo que a metade direita começa em x 12 | `keyboard_shape` no núcleo + teste `metades_juntas_encostam…` |
| Marca do núcleo e SVG podiam divergir | mesmas medidas em dois lugares | `tests/marca.rs` |
| Ids de widgets apagados voltavam depois de reabrir (achado pelo teste aleatório) | `next_id` não era gravado | gravação inclui `next_id`; teste `ids_apagados_nao_voltam…` |
| Dock e Spotlight com o ícone velho | cópias antigas registradas; app só em `build/` | `make install` em `~/Applications`, só essa cópia registrada; verificação do ícone no pacote |
| Avisos passando despercebidos | nada barrava | avisos viram erro no Rust e no Swift |

## O que ainda é fraco

- **O teclado grande (`KeyboardView`) ainda calcula a própria geometria** (carcaça, saia, deslocamento da metade direita). É o mesmo risco do mapa de calor. Próximo passo: estender `keyboard_shape` com carcaça e e-reader e desenhar só a partir dele.
- **Contas de gesto no editor ficam em Swift**: célula sob o cursor (`GridDrop`) e pontos → células ao redimensionar. São conversões de tela, mas a regra "centrar o widget no cursor" poderia ir para o núcleo com teste.
- **`KeyboardStore` junta coisas demais**: estado do teclado, rascunho das luzes, config da barra de menus e navegação. Dá para separar um `MenuBarStore` e um rascunho de luzes.
- **`menubar.rs` passou de 900 linhas**: vale dividir em catálogo, grade, operações e gravação (submódulos, mesma camada).
- **Swift sem alvo de testes do Xcode**: `--verificar` roda dentro do app (como os snapshots) e cobre a cola. Quando a casca crescer, vale um alvo Swift Testing.
- **Estatísticas ainda são de exemplo** (`simulated_statistics`); o motor real de contagem entra com o firmware.

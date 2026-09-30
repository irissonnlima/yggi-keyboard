# Yggi Keyboard

**Um teclado split ortholinear que vira column stagger com um clique.** Open hardware e open source.

![Yggi indo de ortholinear para column stagger](hardware/docs/media/yggi-stagger.gif)

O nome é uma homenagem a Yggdrasil, a árvore que liga os nove mundos da mitologia nórdica. O objetivo de longo prazo é que o Yggi seja o centro que liga os seus computadores e periféricos.

## Onde está cada coisa

| Pasta | O que tem |
|---|---|
| [`hardware/`](hardware/) | mecanismo de stagger (CAD), placas de circuito, layout das teclas, simulação interativa |
| [`app/`](app/) | app do computador: núcleo em Rust + interface macOS em SwiftUI ([como rodar](app/README.md)) |
| [`docs/`](docs/) | documentação do produto: [funcionalidades](docs/funcionalidades.md), [app](docs/app.md) |

Ainda virá `firmware/` (ZMK + módulos Yggi).

## Fases

1. **Teclado Bluetooth** com o mecanismo de stagger.
2. **E-reader destacável** que encaixa no teclado.
3. **Hub**: mouse, trackpad e áudio passando pelo Yggi.

**[▶ Simulação interativa](https://htmlpreview.github.io/?https://github.com/irissonnlima/yggi-keyboard/blob/main/hardware/docs/simulacao.html)**

## Licença

A definir. Sugestão: **CERN-OHL-S-2.0** para o hardware e **MIT** para firmware e software.

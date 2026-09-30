<p align="center"><img src="docs/brand/yggi-marca.svg" width="72" alt="Marca do Yggi"></p>

# Yggi Keyboard

**Um teclado split ortholinear que vira column stagger com um clique.** Open hardware e open source.

![Yggi indo de ortholinear para column stagger](hardware/docs/media/yggi-stagger.gif)

O nome é uma homenagem a Yggdrasil, a árvore que liga os nove mundos da mitologia nórdica. O objetivo de longo prazo é que o Yggi seja o centro que liga os seus computadores e periféricos.

## Conceito de design

> Imagens de conceito para guiar o visual do produto. O projeto técnico (medidas, mecanismo, placas) está em [`hardware/`](hardware/).

**Ortholinear e column stagger.** Em cima, o teclado fechado: um retângulo perfeito, com a baia do e-reader à esquerda. Embaixo, as colunas destravadas e deslizadas no stagger: as colunas externas e a fileira do polegar ficam fixas.

![Yggi em ortholinear e em column stagger](docs/media/conceito/ortho-e-stagger.webp)

**Colunas que deslizam inteiras.** Cada coluna corre sobre trilhos, e o vão que ela deixa fica aparente e acabado, sem moldura solta.

![Colunas deslizantes sobre trilhos](docs/media/conceito/colunas-deslizantes.webp)

**E-reader destacável e conectores.** O e-reader tem tela e-ink, três botões, apoio de mesa e USB-C próprio. Ele encaixa na lateral do teclado por uma fileira de contatos pogo, com ímãs acima e abaixo.

![E-reader destacável e conectores pogo](docs/media/conceito/e-reader-e-conectores.webp)

## Marca

Três barrinhas iguais em Y, na simetria isométrica (120° entre elas): os dois braços são as metades do teclado e a haste é o tronco que liga tudo, como a Yggdrasil. Os arquivos estão em [`docs/brand/`](docs/brand/): [marca](docs/brand/yggi-marca.svg), [marca branca](docs/brand/yggi-marca-branca.svg), [assinatura](docs/brand/yggi-assinatura.svg) e [ícone do app](docs/brand/yggi-icone.svg).

Na barra de menus do Mac, o ícone é o próprio teclado em miniatura, visto de cima: as colunas sobem conforme o stagger abre (de 0 a 100%), as metades se afastam quando estão separadas, e o ícone fica apagado quando o teclado está desconectado. Clicar nele abre o balão com os widgets.

![Ícone da barra de menus em cada estado](docs/brand/barra-de-menus-estados.png)

## Onde está cada coisa

| Pasta | O que tem |
|---|---|
| [`hardware/`](hardware/) | mecanismo de stagger (CAD), placas de circuito, layout das teclas, simulação interativa |
| [`app/`](app/) | app do computador: núcleo em Rust + interface macOS em SwiftUI ([como rodar](app/README.md)) |
| [`docs/`](docs/) | documentação do produto: [funcionalidades](docs/funcionalidades.md), [app](docs/app.md), [arquitetura e testes](docs/arquitetura.md), marca e imagens de conceito |

Ainda virá `firmware/` (ZMK + módulos Yggi).

## Fases

1. **Teclado Bluetooth** com o mecanismo de stagger.
2. **E-reader destacável** que encaixa no teclado.
3. **Hub**: mouse, trackpad e áudio passando pelo Yggi.

**[▶ Simulação interativa](https://htmlpreview.github.io/?https://github.com/irissonnlima/yggi-keyboard/blob/main/hardware/docs/simulacao.html)**

## Licença

A definir. Sugestão: **CERN-OHL-S-2.0** para o hardware e **MIT** para firmware e software.

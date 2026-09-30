# Yggi · funcionalidades (rascunho)

> **Status:** rascunho para discussão. Nada aqui está decidido até ser marcado como ✅.
> Legenda de fase: **F1** = teclado Bluetooth (primeira versão) · **F2** = e-reader destacável · **F3** = hub (mouse, trackpad, áudio).

## 1. Teclado

| # | Funcionalidade | Fase | Onde roda | Observações |
|---|---|---|---|---|
| 1.1 | Digitação com layout Mac (79 teclas, split 7 + 7) | F1 | firmware | ZMK |
| 1.2 | Camada **fn**: teclas de mídia e funções do Mac na fileira F | F1 | firmware | brilho, Mission Control, Spotlight, ditado, mídia, volume |
| 1.3 | **Tecla Yggi**: trocar de computador | F1 | firmware | toque = próximo; segurar + 1…5 = direto; segurar 3 s = parear; troca ao soltar |
| 1.4 | **3 LEDs** de aparelho ativo | F1 | firmware | também piscam no pareamento e na bateria baixa? |
| 1.5 | Até 5 computadores pareados por Bluetooth | F1 | firmware | limite do ZMK |
| 1.6 | Split sem fio (metades separadas) e com fio (metades encaixadas pelo pogo) | F1 | firmware | detectar se estão encaixadas? |
| 1.7 | Bateria: nível de cada metade, carga pelo USB-C, sono profundo | F1 | firmware | aviso de bateria baixa |
| 1.8 | Stagger mecânico (0–150%) com mola e trava | F1 | mecânica | **saber em que modo está?** (sensor) |
| 1.9 | Remapeamento de teclas e camadas sem regravar firmware | F1 | firmware + app | ZMK Studio já faz isso por USB/Bluetooth |
| 1.10 | Macros | F1/F2 | firmware + app | |

## 2. App no computador (Swift)

| # | Funcionalidade | Fase | Observações |
|---|---|---|---|
| 2.1 | Ver estado: computador ativo, bateria das metades, conexão | F1 | na barra de menus do macOS |
| 2.2 | Editor visual do teclado: remapear teclas, camadas, macros | F1 | falar o protocolo do ZMK Studio ou um próprio |
| 2.3 | Estatísticas de digitação: palavras, ritmo, teclas mais usadas (mapa de calor) | F1/F2 | **sem guardar o texto digitado** |
| 2.4 | Perfis por aplicativo: trocar camada quando muda o app em foco | F2 | o app avisa o teclado |
| 2.5 | Lembretes de pausa e ergonomia (ex.: sugerir mudar o stagger) | F2 | |
| 2.6 | Atualizar o firmware | F1 | DFU por USB ou Bluetooth |
| 2.7 | Coordenar a troca de computador (app em cada máquina) | F3 | ajuda a mover mouse e áudio junto |

## 3. E-reader e tela (depois)

| # | Funcionalidade | Fase |
|---|---|---|
| 3.1 | Mostrar estado do teclado quando encaixado | F2 |
| 3.2 | Leitor de livros quando solto (base: CrossPoint) | F2 |
| 3.3 | Contador de palavras / sessão de escrita na tela | F2 |
| 3.4 | Menu do teclado (tecla Yggi longa abre na tela) | F2 |

## 4. Hub (depois)

| # | Funcionalidade | Fase |
|---|---|---|
| 4.1 | Mouse e trackpad Bluetooth passando pelo Yggi | F3 |
| 4.2 | Fone: áudio e microfone acompanhando o computador ativo | F3 |

## Perguntas em aberto

1. **O app é só para macOS**, ou também iPhone/iPad (para ver bateria, trocar computador)?
2. **Editor de teclas**: usar o **ZMK Studio** (pronto, open source) e o app foca no resto, ou o app tem o próprio editor?
3. **Estatísticas**: contar no teclado (funciona em qualquer computador, sem app) ou no app (mais detalhe, só onde o app está instalado)?
4. **Sensor de stagger**: vale colocar um sensor (ex.: hall) para o teclado saber se está em ortho ou stagger? Permitiria camadas diferentes por modo e mostrar no app.
5. **Perfis por aplicativo** entram na primeira versão?

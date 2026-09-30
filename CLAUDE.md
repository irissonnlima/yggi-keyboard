# Yggi Keyboard

Teclado split open hardware (`hardware/`) e o app que conversa com ele (`app/`). Documentação em `docs/`; a do app está em `docs/app.md` e a arquitetura em `docs/arquitetura.md`.

## App: regras

- Lógica no núcleo em Rust (`app/core`); a casca macOS (`app/macos`) só desenha e repassa gestos. Se a regra seria igual em outro sistema, ela é Rust e tem teste.
- Camadas do núcleo conferidas por `app/core/tests/arquitetura.rs`. Módulo novo: decida a camada ali e em `docs/arquitetura.md`.
- Não refaça em Swift uma conta que o núcleo já faz (geometria do teclado: `keyboard_shape`; marca: `yggi_mark`).
- Bug corrigido ganha teste com o caso que quebrou. Regra da cola com o macOS (janela, Dock, ícone da barra) vira verificação em `app/macos/Yggi/Verificacoes.swift`.
- Aviso é erro (Rust e Swift).

## Antes de subir

```bash
cd app && make check
```

Formato, clippy, testes do núcleo, `--verificar` e imagens. Olhe as imagens de `app/build/snapshots` quando mexer em tela ou widget. O mesmo roda no CI.

## Rodar o app

`cd app && make run` instala em `~/Applications` e abre. `--section barra` (ou `teclas`, `luzes`, `estatisticas`) abre direto numa seção.

## Preferências

Conversa e textos em português. Commits vão direto para `main`.

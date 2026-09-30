//! Regras de arquitetura do núcleo, conferidas no código-fonte.
//!
//! O núcleo é um monolito modular: cada módulo só pode usar os módulos das camadas abaixo.
//! Se este teste falhar, ou a dependência nova está no lugar errado, ou a regra precisa
//! mudar de propósito (e aí se muda aqui, junto com `docs/arquitetura.md`).

use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

/// Quem cada módulo pode usar (fora dos testes). Um módulo novo precisa entrar aqui.
const ALLOWED: &[(&str, &[&str])] = &[
    // Base: tipos e regras puras, sem dependência interna.
    ("model", &[]),
    ("layout", &[]),
    ("menubar", &[]),
    // Domínio: regras puras sobre a base.
    ("stats", &["layout"]),
    ("lighting", &["layout", "model"]),
    ("brand", &["layout", "model"]),
    // Porta: o que um teclado (real ou simulado) oferece.
    ("keyboard", &["lighting", "model", "stats"]),
    // Adaptador: o teclado simulado implementa a porta.
    ("simulator", &["keyboard", "layout", "lighting", "model", "stats"]),
    // Fachada: o que as interfaces enxergam.
    ("session", &["keyboard", "lighting", "model", "simulator", "stats"]),
];

/// Módulos puros: só cálculo. Nada de threads, travas ou relógio (isso fica no simulador e na sessão).
const PURE: &[&str] = &["model", "layout", "menubar", "stats", "brand"];
const IMPURE_MARKERS: &[&str] = &["Mutex", "RwLock", "std::thread", "std::time", "Instant::now", "SystemTime"];

fn sources() -> Vec<(String, String)> {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("src");
    let mut out: Vec<_> = fs::read_dir(dir)
        .unwrap()
        .filter_map(|e| {
            let path = e.ok()?.path();
            let name = path.file_stem()?.to_str()?.to_string();
            (path.extension()? == "rs" && name != "lib").then(|| (name, fs::read_to_string(&path).unwrap()))
        })
        .collect();
    out.sort();
    out
}

/// O código de produção: tudo antes do primeiro `#[cfg(test)]`.
fn production(code: &str) -> &str {
    code.split("#[cfg(test)]").next().unwrap_or(code)
}

fn uses(code: &str) -> BTreeSet<String> {
    let mut found = BTreeSet::new();
    for (i, _) in code.match_indices("crate::") {
        let rest = &code[i + "crate::".len()..];
        let name: String = rest.chars().take_while(|c| c.is_ascii_lowercase() || *c == '_').collect();
        if !name.is_empty() {
            found.insert(name);
        }
    }
    // `use crate::{a, b::X}` também conta.
    for (i, _) in code.match_indices("crate::{") {
        let rest = &code[i + "crate::{".len()..];
        let inside = &rest[..rest.find('}').unwrap_or(rest.len())];
        for part in inside.split(',') {
            let name: String = part.trim().chars().take_while(|c| c.is_ascii_lowercase() || *c == '_').collect();
            if !name.is_empty() {
                found.insert(name);
            }
        }
    }
    found
}

#[test]
fn todo_modulo_tem_camada() {
    for (name, _) in sources() {
        assert!(
            ALLOWED.iter().any(|(m, _)| *m == name),
            "o módulo `{name}` não está em ALLOWED (tests/arquitetura.rs): decida em que camada ele fica"
        );
    }
}

#[test]
fn modulos_so_usam_camadas_de_baixo() {
    for (name, code) in sources() {
        let allowed: BTreeSet<&str> =
            ALLOWED.iter().find(|(m, _)| *m == name).map(|(_, a)| a.iter().copied().collect()).unwrap_or_default();
        for dep in uses(production(&code)) {
            assert!(
                allowed.contains(dep.as_str()),
                "`{name}` usa `{dep}`, que não está entre as dependências permitidas {allowed:?} (tests/arquitetura.rs)"
            );
        }
    }
}

#[test]
fn modulos_puros_nao_tem_thread_nem_relogio() {
    for (name, code) in sources() {
        if !PURE.contains(&name.as_str()) {
            continue;
        }
        for marker in IMPURE_MARKERS {
            assert!(
                !production(&code).contains(marker),
                "`{name}` é puro e não pode usar `{marker}`: estado e tempo ficam no simulador/sessão"
            );
        }
    }
}

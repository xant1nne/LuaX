# LuaX

**Транспилятор расширенного Lua → чистый Lua 5.1 / LuaJIT**

[![CI](https://github.com/luax-team/luax/actions/workflows/ci.yml/badge.svg)](https://github.com/luax-team/luax/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

LuaX добавляет современный синтаксис поверх Lua — классы, `async`/`await`, импорты, перечисления и аннотации типов — и компилирует всё в обычный Lua, совместимый с LuaJIT и Lua 5.1.

| Версия | Статус | Фокус |
|--------|--------|-------|
| v0.5 | **Текущая** | Автономный Rust-лаунчер с встроенным LuaJIT |
| v0.4 | Стабильная | Классы и async/await |
| v0.3 | Стабильная | CLI, диагностика, система ошибок |

---

## Быстрый старт

### Вариант A — автономный бинарник (рекомендуется)

```bash
cd launcher
cargo build --release

# Linux/macOS
./target/release/luax run examples/example_class.lx

# Windows
.\target\release\luax.exe run examples\example_class.lx
```

Один исполняемый файл (~10–15 МБ): LuaJIT и все модули транспилятора встроены, внешние зависимости не нужны.

### Вариант B — Lua CLI

```bash
# Требуется Lua 5.1 или LuaJIT
./luax run examples/example_complete.lx
./luax compile examples/example_complete.lx output.lua
./luax doctor examples/example_complete.lx
```

### Вариант C — Docker

```bash
docker compose build luax
docker compose run --rm luax build examples/example_class.lx -o /workspace/out.lua
```

Подробнее: [docs/DOCKER.md](docs/DOCKER.md)

---

## Возможности языка

```lua
import math from "math"

enum Priority { Low, Normal = 10, High }

type Task = { id: number, name: string }

class Worker
    function new(name)
        self.name = name
    end

    function greet()
        print("Hello, " .. self.name)
    end
end

async function fetch(url)
    return await http.get(url)
end
```

| Конструкция | Описание |
|-------------|----------|
| `import` | Модульная система (`require`) |
| `enum` | Типизированные перечисления |
| `type` | Аннотации типов (удаляются при компиляции) |
| `class` | ООП на метатаблицах |
| `async`/`await` | Корутины |

Полная спецификация: [docs/LANGUAGE.md](docs/LANGUAGE.md)

---

## CLI

| Команда | Описание |
|---------|----------|
| `luax run <file.lx>` | Транспилировать и выполнить |
| `luax build <file.lx> [-o out.lua]` | Скомпилировать в файл |
| `luax eval '<code>'` | Выполнить строку (Rust-лаунчер) |
| `luax compile` | Транспилировать (Lua CLI) |
| `luax check` | Проверить синтаксис |
| `luax doctor` | Полная диагностика |
| `luax fmt` | Форматирование |
| `luax help` | Справка |

Справочник: [docs/CLI.md](docs/CLI.md)

---

## Структура проекта

```
LuaX/
├── ast.lua, lexer.lua, parser.lua    # Ядро транспилятора
├── codegen.lua, errors.lua, transforms.lua
├── luax.lua, luax, luax.bat          # Lua CLI
├── src/
│   ├── cli/cli.lua                   # Расширенный CLI
│   ├── transforms/                   # class, async
│   ├── errors/error_system.lua
│   └── tools/doctor.lua
├── launcher/                         # Rust-лаунчер (v0.5)
│   ├── src/main.rs
│   ├── build.rs                      # Встраивает .lua из корня
│   └── Cargo.toml
├── examples/                         # Примеры .lx
├── tests/                            # Тесты
├── docs/                             # Документация
├── Dockerfile, docker-compose.yml
└── LICENSE
```

Архитектура: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## Документация

| Документ | Содержание |
|----------|------------|
| [docs/INSTALL.md](docs/INSTALL.md) | Установка (Rust, Lua, Docker, релизы) |
| [docs/CLI.md](docs/CLI.md) | Справочник команд |
| [docs/LANGUAGE.md](docs/LANGUAGE.md) | Синтаксис LuaX |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Внутреннее устройство |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Разработка и тесты |
| [docs/DOCKER.md](docs/DOCKER.md) | Контейнеры |
| [CHANGELOG.md](CHANGELOG.md) | История версий |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Участие в проекте |

---

## Тесты

```bash
make test          # или: build.bat test
```

Запускает `tests/test_all.lua`, `tests/test_errors.lua`, `tests/compat/lua_compat.lua`.

---

## Лицензия

[MIT](LICENSE) — свободное использование, модификация и распространение.

---

## English summary

LuaX is a transpiler that extends Lua with classes, async/await, imports, enums, and type annotations, emitting plain Lua 5.1 compatible with LuaJIT. Use the Rust launcher for a single static binary, the Lua CLI for full tooling (`doctor`, `fmt`, `check`), or Docker for reproducible builds. See `docs/` for full documentation.

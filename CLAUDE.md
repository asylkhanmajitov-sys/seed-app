# Seed App — Инструкции для Claude Code

## Что такое Seed

Кросс-медийная социальная сеть для любителей кино и книг.
Один профиль: фильмы, книги, актёры, режиссёры, цитаты, подборки.
AI-помощник на Claude формирует культурный портрет пользователя.

## Структура репозитория

```
apps/web/        ← Next.js 15 (App Router) + Tailwind + TypeScript
apps/ios/        ← Swift + SwiftUI, iOS 17+
supabase/
  migrations/    ← SQL миграции (применять через Supabase CLI)
  functions/     ← Edge Functions (TypeScript / Deno)
docs/            ← Архитектура, алгоритмы, фазы
```

## Стек

| Слой | Технология |
|---|---|
| Web | Next.js 15, React, Tailwind CSS, TypeScript strict |
| iOS | Swift 6, SwiftUI, supabase-swift |
| Backend | Supabase (Postgres + Auth + Realtime + pgvector + Edge Functions) |
| AI | Claude via Anthropic API (Haiku 4.5 / Sonnet 4.6 / Opus 4.7) |
| Кэш | Upstash Redis |
| Файлы | Cloudflare R2 |
| Очереди | Inngest |
| Хостинг | Vercel (web) |

## Дизайн-система

```
Фон:        #0F0D0A  (тёплый чёрный)
Surface:    #221C16
Акцент:     #C47556  (терракотовый)
Текст:      #F0E6D2  (кремовый)
Текст-2:    #B8AB95

Шрифты:
  Display:  Fraunces (italic для заголовков)
  Body:     DM Sans
  Mono:     JetBrains Mono

Анимации: 200–250ms, ease-out, без bounce
```

## Правила разработки

1. **TypeScript strict mode везде** — никаких `any`
2. **Swift strict concurrency** — никаких `try?` без обработки
3. **Файл максимум 500 строк**, функция максимум 200 строк
4. **Все API ответы валидировать** через Zod (web) / Codable (iOS)
5. **RLS обязателен** на каждой таблице Supabase
6. **Секреты только в .env** — никогда в код
7. **Дизайн до кода** — три ключевых экрана сначала: профиль, рецензия, AI-чат

## Нельзя нарушать

- Нет алгоритмической ленты (только хронология + discover)
- Нет рекламы никогда
- Native iOS (не React Native)
- AI — второй слой, продукт работает без него
- Prompt caching обязателен на всех AI запросах

## Документация

- [docs/social_algorithm.md](docs/social_algorithm.md) — вирусный алгоритм + уведомления
- [docs/phases.md](docs/phases.md) — 7 фаз, 29 шагов, критерии готовности
- [docs/architecture.md](docs/architecture.md) — технические решения

## Текущая фаза

**Фаза 0 — Инфраструктура** (шаг 1/29)

Следующий шаг: зарегистрировать Supabase → создать проект → включить pgvector.
Трекинг прогресса: Telegram-бот @seed_progress_bot

# Seed App — Инструкции для Claude Code

## Что такое Seed

Кросс-медийная социальная сеть для любителей кино и книг.
Один профиль: фильмы, книги, актёры, режиссёры, цитаты, подборки.
AI-помощник на Claude формирует культурный портрет пользователя.
Premium = AI работает за тебя ($5–8/мес). Никакой рекламы никогда.

## Структура репозитория

```
apps/web/          ← Next.js 15 (App Router) + Tailwind + TypeScript strict
apps/ios/          ← Swift 6 + SwiftUI, iOS 17+
supabase/
  migrations/      ← SQL миграции (применять через SQL Editor или CLI)
  functions/       ← Edge Functions (TypeScript / Deno)
docs/              ← Архитектура, алгоритмы, фазы
```

## Технологический стек

| Слой | Технология |
|---|---|
| Web | Next.js 15, React, Tailwind CSS, TypeScript strict |
| iOS | Swift 6, SwiftUI, supabase-swift |
| Backend | Supabase (Postgres + Auth + Realtime + pgvector + Edge Functions) |
| AI | Anthropic API — Haiku 4.5 / Sonnet 4.6 / Opus 4.7 |
| Кэш | Upstash Redis |
| Файлы | Cloudflare R2 |
| Очереди | Inngest |
| Хостинг | Vercel |
| Контент | TMDB (фильмы) + Open Library / Google Books (книги) |

## Дизайн-система

```
Фон:        #0F0D0A  (тёплый чёрный)
Surface:    #221C16
Акцент:     #C47556  (терракотовый)
Текст:      #F0E6D2  (кремовый)
Текст-2:    #B8AB95

Шрифты: Fraunces (display) + DM Sans (body) + JetBrains Mono
Анимации: 200–250ms ease-out, без bounce
```

---

## Оркестрация Workflow

### 0. Проверка инфраструктуры перед любым действием

Перед реализацией — проверить что сервисы живые:
- Supabase проект отвечает (`https://irmktorraetgtxpelfzs.supabase.co`)
- `.env.local` заполнен корректными ключами
- Vercel деплой зелёный (если уже настроен)

Если что-то недоступно — разобраться самому, не гонять пользователя по кругу.

### 1. Режим планирования по умолчанию

- Входи в режим плана для ЛЮБОЙ нетривиальной задачи (3+ шагов)
- Если что-то идёт не так — СТОП и немедленно перепланируй
- Пиши детальные спеки заранее — убирай неоднозначность

### 2. Стратегия субагентов

- Используй субагентов щедро — держи основной контекст чистым
- Выгружай ресёрч, разведку и параллельный анализ на субагентов
- Одна задача на одного субагента

### 3. Цикл самоулучшения

- После ЛЮБОЙ правки от пользователя: обновляй `tasks/lessons.md`
- Пиши правила, которые не дадут повторить ту же ошибку

### 4. Верификация до «готово»

- Никогда не помечай задачу завершённой без доказательства что работает
- Запускай тесты, смотри логи, демонстрируй корректность
- Спроси себя: «Одобрил бы это staff-инженер?»

### 5. Автономная починка багов

- Получил баг — просто чини. Не проси вести за руку.
- Ноль переключений контекста со стороны пользователя

---

## Управление задачами

1. Сначала план: пиши в `tasks/todo.md` с чекбоксами
2. Проверь план до старта реализации
3. Отмечай пункты по ходу выполнения
4. Фиксируй уроки: обновляй `tasks/lessons.md` после правок

---

## Правила кода

- **TypeScript strict mode везде** — никаких `any`
- **Swift strict concurrency** — никаких `try?` без обработки
- Файл максимум 500 строк, функция максимум 200 строк
- Все API ответы валидировать через Zod (web) / Codable (iOS)
- **RLS обязателен** на каждой таблице Supabase
- Секреты только в `.env.local` — никогда в код
- Prompt caching обязателен на всех Anthropic API запросах

---

## Нельзя нарушать (Seed манифест)

- Нет алгоритмической ленты (только хронология + discover по engagement)
- Нет рекламы никогда
- Native iOS — никакого React Native
- Дизайн до кода: три ключевых экрана сначала (профиль, рецензия, AI-чат)
- AI — второй слой, продукт работает полноценно без него
- Бесплатная версия полноценная, Premium = AI делает за тебя

---

## Security

Полные правила — в [SECURITY.md](SECURITY.md). Кратко:
- Секреты только в `.env.local`, никогда в код и git
- `SUPABASE_SERVICE_ROLE_KEY` только на сервере (Edge Functions), никогда в клиенте
- RLS на каждой таблице — обязательно
- Edge Functions: валидация входных данных + error handling без stack-trace
- Rate limiting на AI endpoints через Redis

---

## Документация

- [docs/manifest.md](docs/manifest.md) — философия проекта
- [docs/architecture.md](docs/architecture.md) — технические решения
- [docs/roadmap.md](docs/roadmap.md) — дорожная карта
- [docs/phases.md](docs/phases.md) — 7 фаз, 29 шагов
- [docs/social_algorithm.md](docs/social_algorithm.md) — вирусный алгоритм

## Трекинг прогресса

Telegram-бот: @seed_progress_bot (29 шагов, команды /step /done /progress)

Текущая фаза: **Фаза 0 — Инфраструктура**
Supabase: `https://irmktorraetgtxpelfzs.supabase.co`
GitHub: `https://github.com/asylkhanmajitov-sys/seed-app`

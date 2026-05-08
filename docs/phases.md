# Seed — Полный план реализации по фазам

## Как читать этот документ

Каждая фаза — это законченная единица работы. Фазу нельзя считать завершённой,
пока все пункты не выполнены и не протестированы. Порядок фаз строгий.

---

## ФАЗА 0 — Инфраструктура и регистрации
*Цель: всё готово к написанию кода. Ни строчки бизнес-логики.*

### Шаг 0.1 — GitHub репозиторий
- [ ] Создать приватный репо `seed-app` на GitHub
- [ ] Структура: `/apps/web` (Next.js), `/apps/ios` (Swift), `/supabase` (migrations + functions)
- [ ] Branch protection на `main` (требует PR + review)
- [ ] Добавить `.gitignore` (не коммитить `.env`, `*.xcuserdatad`, `.next/`)

### Шаг 0.2 — Supabase
- [ ] Создать проект на supabase.com (регион: EU West / Frankfurt)
- [ ] Сохранить в `.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`
- [ ] Включить pgvector extension: `CREATE EXTENSION vector;`
- [ ] Включить Row Level Security (RLS) — глобально

### Шаг 0.3 — Остальные сервисы
- [ ] Vercel — создать проект, подключить GitHub репо, выбрать `/apps/web`
- [ ] Upstash Redis — создать базу, сохранить `UPSTASH_REDIS_URL` + `UPSTASH_REDIS_TOKEN`
- [ ] Cloudflare R2 — создать bucket `seed-media`, получить API ключ
- [ ] Inngest — создать аккаунт, получить `INNGEST_SIGNING_KEY` + `INNGEST_EVENT_KEY`
- [ ] Sentry — создать два проекта: `seed-web` и `seed-ios`
- [ ] PostHog — создать проект, получить `POSTHOG_KEY`
- [ ] Resend — создать аккаунт для email, подтвердить домен (позже)
- [ ] OneSignal — создать app для iOS Push + Web Push

### Шаг 0.4 — Next.js проект
```bash
cd apps/web
npx create-next-app@latest . --typescript --tailwind --app --src-dir --import-alias "@/*"
npm install @supabase/supabase-js @supabase/ssr zod lucide-react
npm install -D @types/node
```
- [ ] Настроить `tailwind.config.ts` с цветами Seed (--accent: #C47556 и др.)
- [ ] Создать `/src/lib/supabase/` (client.ts, server.ts, middleware.ts)
- [ ] GitHub Actions: lint + type-check + deploy preview на каждый PR

### Шаг 0.5 — iOS проект
- [ ] Создать Xcode проект `Seed`, Swift 6, SwiftUI, iOS 17+
- [ ] Добавить Swift Package: `supabase-swift` (через SPM)
- [ ] Настроить `SeedApp.swift` с Supabase client
- [ ] Настроить Sentry SDK для iOS

### Шаг 0.6 — Supabase миграции: core schema
```sql
-- Запустить в SQL Editor Supabase
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    handle          TEXT UNIQUE NOT NULL,
    display_name    TEXT NOT NULL,
    email           TEXT UNIQUE,
    phone           TEXT UNIQUE,
    avatar_url      TEXT,
    bio             TEXT,
    website         TEXT,
    is_verified     BOOLEAN DEFAULT FALSE,
    premium_until   TIMESTAMPTZ,
    visibility      TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'friends')),
    show_watched    BOOLEAN DEFAULT TRUE,
    show_ratings    BOOLEAN DEFAULT TRUE,
    show_saved      BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);

-- RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_public_read" ON users FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "users_own_update" ON users FOR UPDATE USING (auth.uid() = id);
```

**Критерий завершения Фазы 0:**
- Vercel деплоит заглушку `/` без ошибок
- Supabase подключён и принимает запросы
- iOS приложение запускается на симуляторе

---

## ФАЗА 1 — Аутентификация и онбординг
*Цель: пользователь может зарегистрироваться и пройти taste-swiper*

### Шаг 1.1 — Auth (Web)
- [ ] Supabase Auth: включить Apple ID, Google, Magic Link, Phone OTP
- [ ] Страница `/auth/login` — выбор метода входа
- [ ] Страница `/auth/callback` — обработка OAuth redirect
- [ ] Middleware: redirect неавторизованных на `/auth/login`
- [ ] Apple Sign In на web (через Supabase)

### Шаг 1.2 — Auth (iOS)
- [ ] Sign in with Apple (нативно через `AuthenticationServices`)
- [ ] Google Sign In (через Supabase OAuth)
- [ ] Phone OTP экран
- [ ] Keychain хранение токенов

### Шаг 1.3 — Создание профиля
- [ ] После первого входа → onboarding flow
- [ ] Экран 1: выбор `@handle` (проверка уникальности через Supabase)
- [ ] Экран 2: имя + фото (опционально)
- [ ] Экран 3: taste-swiper (см. 1.4)

### Шаг 1.4 — Taste-swiper
*5 минут, 20–30 карточек. Формирует начальный taste_vector.*

- [ ] Показать 30 фильмов из разных жанров (предзаполненный seed-список)
- [ ] Показать 20 книг из разных жанров
- [ ] Свайп вправо = нравится, влево = не нравится, вверх = "уже видел/читал"
- [ ] После свайпов → генерировать taste_vector через Voyage AI embeddings
- [ ] Сохранить в `taste_vectors` таблицу

### Шаг 1.5 — Supabase миграции для auth
```sql
CREATE TABLE taste_vectors (
    user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    vector      vector(1024),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE follows (
    follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
    followee_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id)
);
```

**Критерий завершения Фазы 1:**
- Полный onboarding flow работает на iOS и Web
- После регистрации taste_vector сохранён в БД

---

## ФАЗА 2 — Каталог и коллекция
*Цель: пользователь может находить фильмы/книги, оценивать, писать рецензии*

### Шаг 2.1 — Интеграция TMDB
- [ ] Edge Function `/api/tmdb/search?q=` — прокси к TMDB API (скрываем ключ)
- [ ] Edge Function `/api/tmdb/film/{id}` — детали фильма + кэш в таблицу `films`
- [ ] Cron (Inngest): обновлять popularity у топ-1000 фильмов еженедельно

### Шаг 2.2 — Интеграция Open Library / Google Books
- [ ] Edge Function `/api/books/search?q=` — поиск книг
- [ ] Edge Function `/api/books/{id}` — детали книги + кэш в `books`

### Шаг 2.3 — Supabase миграции: контент
```sql
CREATE TABLE films (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tmdb_id         INT UNIQUE NOT NULL,
    title           TEXT NOT NULL,
    original_title  TEXT,
    year            INT,
    genres          TEXT[],
    directors       JSONB,   -- [{tmdb_id, name}]
    actors          JSONB,   -- [{tmdb_id, name, character}]
    poster_url      TEXT,
    backdrop_url    TEXT,
    runtime_minutes INT,
    overview        TEXT,
    tmdb_rating     FLOAT,
    cached_at       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE books (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    openlibrary_id  TEXT UNIQUE,
    google_books_id TEXT UNIQUE,
    title           TEXT NOT NULL,
    authors         JSONB,   -- [{name, author_id}]
    year            INT,
    genres          TEXT[],
    cover_url       TEXT,
    description     TEXT,
    pages           INT,
    cached_at       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE reviews (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    item_type   TEXT CHECK (item_type IN ('film', 'book')),
    item_id     UUID,
    rating      SMALLINT CHECK (rating BETWEEN 1 AND 5),
    body        TEXT,
    is_public   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT now(),
    deleted_at  TIMESTAMPTZ,
    UNIQUE (user_id, item_type, item_id)
);

CREATE TABLE post_engagement (
    review_id       UUID PRIMARY KEY REFERENCES reviews(id),
    likes_count     INT DEFAULT 0,
    comments_count  INT DEFAULT 0,
    saves_count     INT DEFAULT 0,
    follows_from    INT DEFAULT 0,
    profile_clicks  INT DEFAULT 0,
    score           FLOAT DEFAULT 0,
    distribution_layer INT DEFAULT 0,
    score_updated_at TIMESTAMPTZ,
    promoted_at     TIMESTAMPTZ
);

CREATE TABLE review_likes (
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    review_id   UUID REFERENCES reviews(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, review_id)
);

CREATE TABLE review_comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id   UUID REFERENCES reviews(id) ON DELETE CASCADE,
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    body        TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
```

### Шаг 2.4 — Списки и полки
```sql
CREATE TABLE lists (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    visibility  TEXT DEFAULT 'public',
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE list_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id     UUID REFERENCES lists(id) ON DELETE CASCADE,
    item_type   TEXT,
    item_id     UUID,
    position    INT,
    note        TEXT,
    added_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE saved_items (
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    item_type   TEXT,
    item_id     UUID,
    saved_at    TIMESTAMPTZ DEFAULT now(),
    reminder_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, item_type, item_id)
);
```

### Шаг 2.5 — UI экраны
- [ ] Страница фильма (постер, описание, трейлер, оценка, кнопка "написать рецензию")
- [ ] Страница книги
- [ ] Экран написания рецензии (звёздочки + текст)
- [ ] Мои списки / полки
- [ ] Сохранённое

**Критерий завершения Фазы 2:**
- Поиск фильма → детали → оценка + рецензия → сохранено в БД

---

## ФАЗА 3 — Социальный слой
*Цель: подписки, лента, уведомления, DM*

### Шаг 3.1 — Follow система
- [ ] Кнопка "Подписаться" на профиле
- [ ] Список подписок / подписчиков
- [ ] Уведомление при новом подписчике

### Шаг 3.2 — Лента активности
- [ ] Хронологическая лента: рецензии людей, на которых подписан
- [ ] Отображение карточки рецензии: постер + имя + оценка + цитата из рецензии
- [ ] Лайк и комментарий к рецензии прямо из ленты

### Шаг 3.3 — Уведомления
```sql
CREATE TABLE notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    type        TEXT NOT NULL,
    payload     JSONB,
    is_read     BOOLEAN DEFAULT FALSE,
    sent_at     TIMESTAMPTZ DEFAULT now()
);
```
- [ ] Supabase Realtime подписка на уведомления
- [ ] Push через OneSignal (iOS + Web)
- [ ] Группировка: "5 друзей оценили твой отзыв"
- [ ] Rate limit: не более 3 push/час

### Шаг 3.4 — DM (личные сообщения)
```sql
CREATE TABLE direct_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id   UUID REFERENCES users(id),
    recipient_id UUID REFERENCES users(id),
    body        TEXT,
    sent_at     TIMESTAMPTZ DEFAULT now(),
    read_at     TIMESTAMPTZ
);
```
- [ ] Список диалогов
- [ ] Чат 1-на-1 через Supabase Realtime
- [ ] Push при новом сообщении

### Шаг 3.5 — Настройки приватности
- [ ] Переключатель public / friends-only в настройках
- [ ] Гранулярные переключатели: показывать оценки / сохранённое / историю

**Критерий завершения Фазы 3:**
- Подписаться → видеть рецензии в ленте → лайкнуть → автор получил уведомление

---

## ФАЗА 4 — Вирусный алгоритм
*Цель: хорошие рецензии выходят за пределы подписок*

### Шаг 4.1 — Engagement scoring
- [ ] Inngest cron каждые 2 часа: пересчёт score всех рецензий < 48ч
- [ ] `post_engagement` таблица заполняется триггерами на like/comment/save
- [ ] Postgres trigger: при INSERT в `review_likes` → UPDATE `post_engagement.likes_count`

### Шаг 4.2 — Слой 1: расширение по вкусам
- [ ] При достижении THRESHOLD_1: найти 50 пользователей схожих вкусов (pgvector cosine similarity)
- [ ] Добавить рецензию в их "Рекомендации" раздел
- [ ] Пуш: "[Имя] (не знаком) написал рецензию, которая может тебе понравиться"

### Шаг 4.3 — Слой 2: глобальный жанровый feed
- [ ] При достижении THRESHOLD_2: добавить в раздел "В тренде в [Жанр]"
- [ ] Новый раздел на главном экране: "В тренде"
- [ ] Показывать reviewer'у: "Твой отзыв читают 500+ человек"

### Шаг 4.4 — Discover страница
- [ ] Раздел "Рекомендации для тебя" (слой 1 контент)
- [ ] Раздел "В тренде" по жанрам
- [ ] Раздел "Популярные профили схожих вкусов" (найти людей для подписки)

**Критерий завершения Фазы 4:**
- Рецензия с высоким engagement появляется у незнакомых пользователей по жанру

---

## ФАЗА 5 — Слежение за актёрами/режиссёрами
*Цель: пользователь подписывается на персону и получает уведомления о новых фильмах*

### Шаг 5.1 — Подписка на персону
```sql
CREATE TABLE person_follows (
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    person_id       INT NOT NULL,
    person_type     TEXT CHECK (person_type IN ('actor', 'director', 'author')),
    person_name     TEXT,
    person_image_url TEXT,
    notify_new_film  BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, person_id)
);

CREATE TABLE person_releases_cache (
    person_id       INT PRIMARY KEY,
    known_film_ids  INT[],
    checked_at      TIMESTAMPTZ
);
```

- [ ] На странице актёра/режиссёра — кнопка "Следить за новинками"
- [ ] В профиле — раздел "Любимые актёры/режиссёры" (с иконкой колокольчика)

### Шаг 5.2 — Inngest cron: ежедневная проверка
- [ ] Функция `check-actor-new-releases` (каждый день в 9:00)
- [ ] TMDB API: `/person/{id}/combined_credits`
- [ ] Сравнение с `person_releases_cache`
- [ ] Если новый фильм → создать уведомление всем подписчикам

### Шаг 5.3 — UI уведомления о новинках
- [ ] Карточка: постер нового фильма + имя персоны + дата выхода
- [ ] Кнопка "Сохранить в список" прямо из уведомления

**Критерий завершения Фазы 5:**
- Добавить тестового актёра → через cron → получить уведомление о новом фильме

---

## ФАЗА 6 — Ticketon + AI post-watch
*Цель: купить билет в кино → AI напомнит написать рецензию*

### Шаг 6.1 — Ticketon интеграция
- [ ] Зарегистрироваться на Ticketon, получить API / партнёрский ключ
- [ ] Кнопка "Купить билет" на странице фильма (если фильм сейчас в прокате)
- [ ] Открыть Ticketon WebView (iOS: `SFSafariViewController`, Web: iframe / redirect)
- [ ] Webhook endpoint `/webhooks/ticketon` — принять подтверждение покупки

### Шаг 6.2 — Post-watch Inngest flow
```sql
CREATE TABLE ticket_purchases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id),
    film_id         UUID REFERENCES films(id),
    showtime        TIMESTAMPTZ NOT NULL,
    venue           TEXT,
    ticketon_order_id TEXT UNIQUE,
    purchased_at    TIMESTAMPTZ DEFAULT now(),
    reminder_sent   BOOLEAN DEFAULT FALSE
);
```

- [ ] При получении webhook → создать Inngest event `ticket.purchased`
- [ ] Inngest function `post-watch-followup`: sleep until showtime + runtime + 30min
- [ ] Push: "Ты посмотрел «Название»? Оставь отзыв — друзья увидят!"
- [ ] Через 24ч без рецензии: AI in-app prompt

### Шаг 6.3 — AI чат (базовый)
```sql
CREATE TABLE ai_chat_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id),
    context     JSONB,
    started_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE ai_chat_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES ai_chat_sessions(id),
    role        TEXT CHECK (role IN ('user', 'assistant')),
    content     TEXT,
    model       TEXT,
    tokens_used INT,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE ai_daily_usage (
    user_id     UUID REFERENCES users(id),
    date        DATE DEFAULT CURRENT_DATE,
    requests    INT DEFAULT 0,
    PRIMARY KEY (user_id, date)
);
```

- [ ] Supabase Edge Function `/ai/chat` — прокси к Anthropic API
- [ ] Модель по умолчанию: Claude Haiku 4.5 (дёшево)
- [ ] Rate limit: 5 req/day бесплатно, 200 req/day Premium
- [ ] Prompt cache: system prompt + профиль пользователя (экономия 90%)
- [ ] Routing: простые → Haiku, стандартные → Sonnet 4.6, сложные → Opus 4.7

**Критерий завершения Фазы 6:**
- Купить тестовый билет → через имитацию showtime → получить AI напоминание

---

## ФАЗА 7 — Premium и закрытая бета
*Цель: монетизация + запуск для 200–500 первых пользователей*

### Шаг 7.1 — Система приглашений
```sql
CREATE TABLE invites (
    code        TEXT PRIMARY KEY,
    created_by  UUID REFERENCES users(id),
    used_by     UUID REFERENCES users(id),
    created_at  TIMESTAMPTZ DEFAULT now(),
    used_at     TIMESTAMPTZ
);
```
- [ ] Только по инвайту в Фазе 1
- [ ] Каждый пользователь получает 5 инвайтов

### Шаг 7.2 — Premium подписка
- [ ] Stripe: подписка $5–8/мес (для Web / международные карты)
- [ ] StoreKit 2: In-App Purchase на iOS (Apple берёт 30% → цена $6.99)
- [ ] RevenueCat: единый дашборд для iOS + Stripe
- [ ] CloudPayments / ЮKassa: для СНГ карт
- [ ] Premium benefis: AI 200 req/day, AI автопрофиль, AI weekly digest

### Шаг 7.3 — Мониторинг и безопасность
- [ ] Sentry: настроить алерты на ошибки (iOS + Web)
- [ ] PostHog: воронки (registration → first_review → follow → premium)
- [ ] Better Stack: uptime мониторинг на API endpoints
- [ ] Axiom: централизованные логи Edge Functions
- [ ] Security: все RLS policies проверены, нет open endpoints

### Шаг 7.4 — TestFlight beta
- [ ] Build для TestFlight (App Store Connect)
- [ ] Пригласить 20 alpha-тестеров
- [ ] Собрать feedback через встроенный механизм TestFlight
- [ ] Vercel preview для web-тестеров

**Критерий завершения Фазы 7 = MVP готов к закрытой бете**

---

## Таймлайн (ориентировочно)

| Фаза | Длительность | Ключевой результат |
|---|---|---|
| 0 — Инфраструктура | 2 дня | Depl работает, Supabase подключён |
| 1 — Auth + Onboarding | 5 дней | Регистрация + taste-swiper |
| 2 — Каталог | 7 дней | Поиск фильма → рецензия |
| 3 — Социальный слой | 7 дней | Лента + уведомления + DM |
| 4 — Алгоритм | 7 дней | Вирусное распространение |
| 5 — Actor alerts | 5 дней | Уведомления о новинках |
| 6 — Ticketon + AI | 7 дней | Билеты + AI follow-up |
| 7 — Beta | 7 дней | TestFlight + 200 юзеров |
| **Итого** | **~47 дней** | **Закрытая бета** |

---

## Принципы, которые нельзя нарушать

1. **Дизайн до кода** — три ключевых экрана в Figma сначала (профиль, рецензия, AI-чат)
2. **Native iOS** — никакого React Native
3. **Нет алгоритмической ленты** — только хронология + вирусный алгоритм для discover
4. **Нет рекламы** — монетизация только через Premium
5. **AI — второй слой** — продукт работает полноценно без AI

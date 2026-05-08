# Seed Security Protocol

Обязательное руководство по безопасности для проекта Seed.
Все разработчики и AI-ассистенты обязаны соблюдать эти правила.

---

## 1. Управление секретами

- **`.env.local` в `.gitignore`** — никогда не коммитить реальные ключи
- В репо только `.env.example` с заглушками
- `SUPABASE_SERVICE_ROLE_KEY` — только в серверном коде (Edge Functions, Server Actions). **Никогда в клиентском коде, никогда в `NEXT_PUBLIC_*`**
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — публичный, только для клиентского SDK
- Anthropic API Key — только в Edge Functions, никогда на клиенте
- Upstash, Cloudflare R2, Inngest токены — только в серверном окружении

Проверка утечки: `git grep -r "eyJ\|sb_secret\|sk_live\|rk_live"` — должно быть пусто.

---

## 2. Supabase Row Level Security (RLS)

- **RLS включён на каждой таблице** без исключений
- Создание таблицы без `ALTER TABLE x ENABLE ROW LEVEL SECURITY` — запрещено
- Политики по умолчанию: закрыто для всех, открывать явно
- `service_role` key обходит RLS — использовать только для серверных операций (миграции, webhooks, cron jobs)

Шаблон для каждой новой таблицы:
```sql
ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;
-- Явно определить политики SELECT / INSERT / UPDATE / DELETE
```

---

## 3. Edge Functions

- Валидировать все входные данные через Zod до вызова бизнес-логики
- Error responses без stack-trace, без имён таблиц, без путей:
  ```typescript
  // ✅ Правильно
  return new Response(JSON.stringify({ error: "Internal server error" }), { status: 500 })
  // ❌ Запрещено
  return new Response(error.message, { status: 500 })
  ```
- Аутентификация: проверять JWT через `supabase.auth.getUser()` в каждой защищённой функции
- Rate limiting на AI endpoints: Redis counter `ai:usage:{userId}:{date}`

---

## 4. Аутентификация

- JWT access token: стандартный Supabase TTL (1 час)
- Refresh token: управляется Supabase Auth автоматически
- Apple Sign In / Google OAuth — через Supabase Auth провайдеры, не самописно
- Никакой кастомной крипто или session management

---

## 5. Клиентский код (Next.js / Swift)

- `SUPABASE_SERVICE_ROLE_KEY` — **только в Server Actions и Edge Functions**
- В компонентах (`"use client"`) — только `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- Не логировать токены, ключи, user PII в `console.log`
- CORS: Vercel автоматически ограничивает, для Edge Functions явно указывать origin

---

## 6. Зависимости

- Минимум: каждая новая зависимость обоснована
- `npm audit` перед каждым релизом
- Пиннинг версий в `package.json`

---

## 7. Данные пользователей

- Пароли не хранятся (только OAuth + magic link + OTP)
- Email / phone — только в Supabase Auth, не дублировать в `users` таблице без необходимости
- Soft delete везде (`deleted_at`) — не удалять данные жёстко
- `taste_vectors` — анонимны, не содержат PII

---

*Последнее обновление: 2026-05-08*

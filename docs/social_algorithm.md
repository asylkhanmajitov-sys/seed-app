# Seed — Социальный алгоритм и уведомления

## 1. Вирусный алгоритм распространения контента

Inspired by TikTok's local-first distribution model.

### Как работает

Когда пользователь публикует **рецензию** (оценка + комментарий к фильму/книге):

```
СЛОЙ 0 (мгновенно):
  → Показать в ленте всех подписчиков автора
  → Push-уведомление всем подписчикам: "[Друг] посмотрел «Аватар 3» и оставил отзыв"

СЛОЙ 1 (через 4–12 часов, если score > THRESHOLD_1):
  → Рекомендовать пользователям схожих вкусов, которые НЕ подписаны на автора
  → Охват: followers_count × 5 уникальных пользователей (по жанровому вектору)
  → Показывается в разделе "Интересно тебе" как рекомендация

СЛОЙ 2 (через 12–48 часов, если score > THRESHOLD_2):
  → Попадает в глобальную ленту жанра (раздел "В тренде в [Жанр]")
  → Охват: все пользователи, у которых этот жанр в топ-3 предпочтений
```

### Формула engagement_score

```python
engagement_score = (
    likes       * 1.0 +
    comments    * 3.0 +   # комментарий весит больше лайка
    saves       * 2.0 +   # сохранил — сильный сигнал
    new_follows * 5.0 +   # подписался после прочтения — очень сильный сигнал
    profile_clicks * 0.5
) / max(1, hours_since_post ** 0.5)   # time decay

THRESHOLD_1 = 8    # перейти в слой 1
THRESHOLD_2 = 40   # перейти в слой 2
```

### Хранение в БД

```sql
CREATE TABLE post_engagement (
    review_id       UUID PRIMARY KEY REFERENCES reviews(id),
    likes_count     INT DEFAULT 0,
    comments_count  INT DEFAULT 0,
    saves_count     INT DEFAULT 0,
    follows_from    INT DEFAULT 0,
    profile_clicks  INT DEFAULT 0,
    score           FLOAT DEFAULT 0,
    distribution_layer INT DEFAULT 0,  -- 0, 1, 2
    score_updated_at TIMESTAMPTZ,
    promoted_at     TIMESTAMPTZ
);
```

### Inngest job: пересчёт и промоция

```python
# Запускается каждые 2 часа через Inngest cron
@inngest.create_function(
    fn_id="recalculate-review-scores",
    trigger=inngest.cron_trigger("0 */2 * * *"),
)
async def recalculate_scores(ctx):
    reviews = await db.get_reviews_younger_than_48h(layer__lt=2)
    
    for review in reviews:
        score = calculate_score(review)
        await db.update_score(review.id, score)
        
        if score >= THRESHOLD_2 and review.layer < 2:
            await promote_to_layer2(review)
        elif score >= THRESHOLD_1 and review.layer < 1:
            await promote_to_layer1(review)
```

---

## 2. Система уведомлений

### Типы уведомлений

| Тип | Триггер | Текст |
|---|---|---|
| `friend_reviewed` | Друг оставил рецензию | "[Друг] посмотрел «Название» ⭐️4/5 — читай его отзыв" |
| `friend_liked` | Друг лайкнул твою рецензию | "[Друг] оценил твой отзыв на «Название»" |
| `friend_commented` | Друг прокомментировал твою рецензию | "[Друг]: «[первые 50 символов...]»" |
| `review_trending` | Твоя рецензия вышла в слой 1/2 | "Твой отзыв на «Название» читают 200+ человек" |
| `new_follower` | Кто-то подписался | "[Пользователь] подписался на тебя" |
| `actor_new_film` | Новый фильм с любимым актёром | "[Актёр] снялся в новом фильме «Название»" |
| `director_new_film` | Новый фильм от любимого режиссёра | "[Режиссёр] выпустил «Название»" |
| `post_watch_push` | AI: напоминание после просмотра | "Ты посмотрел «Название»? Расскажи друзьям!" |
| `weekly_digest` | Еженедельный дайджест | "Что посмотрели друзья на этой неделе" |

### Правила anti-spam

```python
# Не более 3 push-уведомлений в час на пользователя
# friend_liked и friend_commented — группируются если < 30 мин:
#   "5 друзей оценили твой отзыв на «Аватар»"
# weekly_digest заменяет накопленные мелкие события за неделю

PUSH_RATE_LIMIT = 3   # в час
GROUP_WINDOW = 30     # минут для группировки однотипных
```

---

## 3. Настройки приватности

### Уровни видимости аккаунта

```
PUBLIC:
  - Профиль виден всем (без авторизации)
  - Рецензии попадают в вирусный алгоритм
  - Можно найти через поиск
  - Open Graph: красивая превью при шеринге в мессенджер

FRIENDS_ONLY:
  - Профиль виден только подписчикам
  - Рецензии видят только подписчики (слой 0, не идёт в слой 1/2)
  - В поиске виден только username
  - Можно скрыть отдельные элементы: saved, ratings, history
```

### Гранулярный контроль (в настройках)

```
☑ Показывать мои просмотры подписчикам
☑ Показывать мои оценки подписчикам
☑ Показывать мои сохранённые подписчикам
☐ Показывать список любимых актёров/режиссёров
☑ Рекомендовать мои рецензии по жанрам (слой 1/2)
```

---

## 4. Система слежения за актёрами/режиссёрами

### Подписка пользователя

```sql
CREATE TABLE person_follows (
    user_id     UUID REFERENCES users(id),
    person_id   INT,               -- TMDB person ID
    person_type TEXT,              -- 'actor', 'director', 'author'
    person_name TEXT,
    notify_new_film BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, person_id)
);

CREATE TABLE person_releases_cache (
    person_id   INT PRIMARY KEY,
    last_film_ids JSONB,           -- массив известных film_id
    checked_at  TIMESTAMPTZ
);
```

### Inngest cron: проверка новых релизов (ежедневно)

```python
@inngest.create_function(
    fn_id="check-actor-new-releases",
    trigger=inngest.cron_trigger("0 9 * * *"),  # каждый день в 9:00
)
async def check_new_releases(ctx):
    # Уникальные person_id, на кого хоть кто-то подписан
    persons = await db.get_all_followed_persons()
    
    for person in persons:
        # TMDB API: /person/{id}/combined_credits
        credits = await tmdb.get_person_credits(person.person_id)
        
        # Только announced/in_production/released за последние 90 дней
        new_films = get_new_since_cache(credits, person.last_film_ids)
        
        if not new_films:
            continue
        
        # Обновить кэш
        await db.update_person_cache(person.person_id, credits)
        
        # Уведомить всех подписчиков
        subscribers = await db.get_person_subscribers(person.person_id)
        for user_id in subscribers:
            await notifications.send(user_id, "actor_new_film", {
                "person_id": person.person_id,
                "person_name": person.person_name,
                "film": new_films[0],
            })
```

---

## 5. Интеграция Ticketon

### Флоу покупки билета

```
1. Пользователь на странице фильма → кнопка "Купить билет"
2. Открывается WebView с Ticketon (Deep Link / SDK)
3. Пользователь выбирает сеанс и оплачивает
4. Ticketon → webhook → Seed API /webhooks/ticketon
5. Seed сохраняет покупку и планирует post-watch reminder
```

```sql
CREATE TABLE ticket_purchases (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id),
    film_id     UUID REFERENCES films(id),
    showtime    TIMESTAMPTZ,
    venue       TEXT,
    ticketon_order_id TEXT,
    purchased_at TIMESTAMPTZ DEFAULT now(),
    reminder_sent BOOLEAN DEFAULT FALSE
);
```

### Inngest: AI follow-up после просмотра

```python
@inngest.create_function(fn_id="post-watch-followup")
async def post_watch_followup(ctx, user_id: str, film_id: str, showtime: datetime):
    film = await db.get_film(film_id)
    
    # Ждём пока фильм закончится (runtime + 30 мин буфер)
    watch_ends_at = showtime + timedelta(minutes=film.runtime + 30)
    await ctx.sleep_until("wait-for-film-end", watch_ends_at)
    
    # Пользователь уже сам написал рецензию?
    if await db.has_review(user_id, film_id):
        return
    
    # Push уведомление
    await push.send(
        user_id=user_id,
        title=f"Ты посмотрел «{film.title}»?",
        body="Оставь оценку и отзыв — друзья увидят что ты думаешь",
        action_url=f"/films/{film_id}/review",
    )
    
    # Через 24ч — in-app AI подсказка если всё ещё нет рецензии
    await ctx.sleep("wait-24h", delay="24h")
    
    if not await db.has_review(user_id, film_id):
        await ai_chat.send_proactive(
            user_id=user_id,
            message=f"Как тебе «{film.title}»? Напиши пару слов — "
                    f"я помогу оформить отзыв и поделюсь с друзьями.",
        )
```

---

## 6. Страница профиля (как в Threads)

### Структура публичного профиля

```
[Аватар] [Имя] @handle
[Биография]
─────────────────────────────
ФИЛЬМЫ    КНИГИ    ACTИVISTY

[Топ-4 фильма]   [Топ-4 книги]
[Любимые режиссёры]
[Любимые актёры]
[Подборки пользователя]
[Последние рецензии]
[Сохранённое] (если public)
```

### Open Graph для шеринга

При шеринге ссылки `seed.app/u/username` в Telegram/WhatsApp:
- Превью: аватар + топ-3 фильма + последняя рецензия
- Красивая карточка с тёмным фоном и акцентом #C47556

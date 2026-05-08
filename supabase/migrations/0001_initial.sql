-- Seed: начальная схема БД
-- Фаза 0, шаг 6

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Пользователи
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

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_public_read"  ON users FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "users_own_update"   ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "users_own_insert"   ON users FOR INSERT WITH CHECK (auth.uid() = id);

-- Taste vectors (pgvector)
CREATE TABLE taste_vectors (
    user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    vector      vector(1024),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE taste_vectors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "taste_own" ON taste_vectors USING (auth.uid() = user_id);

-- Подписки
CREATE TABLE follows (
    follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
    followee_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id)
);

ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "follows_read"   ON follows FOR SELECT USING (TRUE);
CREATE POLICY "follows_insert" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete" ON follows FOR DELETE USING (auth.uid() = follower_id);

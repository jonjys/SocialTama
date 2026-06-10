-- ══════════════════════════════════════════════════════════════
-- KARMA App — Supabase Database Schema
-- Run this in: supabase.com → Your Project → SQL Editor → New Query
-- ══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ──────────────────────────────────────────
-- PROFILES (one row per user)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  pet_emoji TEXT DEFAULT '🐉',
  pet_name TEXT DEFAULT 'Min Pet',
  level INTEGER DEFAULT 1,
  exp INTEGER DEFAULT 0,
  coins INTEGER DEFAULT 500,
  hunger INTEGER DEFAULT 80,
  energy INTEGER DEFAULT 100,
  mood INTEGER DEFAULT 90,
  streak INTEGER DEFAULT 0,
  last_streak_date DATE,
  world TEXT DEFAULT 'cosmic',
  premium BOOLEAN DEFAULT FALSE,
  premium_tier INTEGER DEFAULT 0,
  premium_until BIGINT DEFAULT 0,
  talent_points INTEGER DEFAULT 0,
  talents JSONB DEFAULT '[]'::jsonb,
  talent_lvls JSONB DEFAULT '{}'::jsonb,
  pet_config JSONB DEFAULT '{}'::jsonb,
  world_points INTEGER DEFAULT 0,
  built_zones JSONB DEFAULT '[]'::jsonb,
  action_stat INTEGER DEFAULT 0,
  social_stat INTEGER DEFAULT 0,
  commerce_stat INTEGER DEFAULT 0,
  trust_score INTEGER DEFAULT 42,
  post_count INTEGER DEFAULT 0,
  today_bond JSONB DEFAULT '{"flash":false,"chat":false,"quest":false,"market":false}'::jsonb,
  bond_date TEXT DEFAULT '',
  last_spin TEXT DEFAULT '',
  last_talk_time BIGINT DEFAULT 0,
  last_wp_boost BIGINT DEFAULT 0,
  room_theme TEXT DEFAULT 'cosmic',
  room_deco JSONB DEFAULT '[]'::jsonb,
  diary_entries JSONB DEFAULT '[]'::jsonb,
  gear JSONB DEFAULT '[]'::jsonb,
  equipped_gear TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ──────────────────────────────────────────
-- POSTS (Flash posts)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  username TEXT NOT NULL,
  pet_emoji TEXT DEFAULT '🐉',
  pet_level INTEGER DEFAULT 1,
  caption TEXT DEFAULT '',
  sound TEXT DEFAULT 'Original Sound 🎵',
  tag TEXT DEFAULT '',
  bg TEXT DEFAULT '',
  likes_count INTEGER DEFAULT 0,
  is_live BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ──────────────────────────────────────────
-- POST LIKES
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.post_likes (
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

-- ──────────────────────────────────────────
-- FOLLOWS
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.follows (
  follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id)
);

-- ──────────────────────────────────────────
-- COMMENTS
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  username TEXT NOT NULL,
  pet_emoji TEXT DEFAULT '🐉',
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ──────────────────────────────────────────
-- NOTIFICATIONS
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  from_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  from_username TEXT DEFAULT '',
  from_pet_emoji TEXT DEFAULT '🐾',
  type TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ──────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ──────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Posts
CREATE POLICY "posts_select" ON public.posts FOR SELECT USING (true);
CREATE POLICY "posts_insert" ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "posts_delete" ON public.posts FOR DELETE USING (auth.uid() = user_id);

-- Likes
CREATE POLICY "likes_select" ON public.post_likes FOR SELECT USING (true);
CREATE POLICY "likes_insert" ON public.post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "likes_delete" ON public.post_likes FOR DELETE USING (auth.uid() = user_id);

-- Follows
CREATE POLICY "follows_select" ON public.follows FOR SELECT USING (true);
CREATE POLICY "follows_insert" ON public.follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete" ON public.follows FOR DELETE USING (auth.uid() = follower_id);

-- Comments
CREATE POLICY "comments_select" ON public.comments FOR SELECT USING (true);
CREATE POLICY "comments_insert" ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "comments_delete" ON public.comments FOR DELETE USING (auth.uid() = user_id);

-- Notifications (private)
CREATE POLICY "notifs_select" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "notifs_insert" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "notifs_update" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- ──────────────────────────────────────────
-- FUNCTIONS & TRIGGERS
-- ──────────────────────────────────────────

-- Auto-update updated_at on profiles
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Increment/decrement post likes atomically
CREATE OR REPLACE FUNCTION increment_likes(post_id UUID)
RETURNS void AS $$
BEGIN UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = post_id; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrement_likes(post_id UUID)
RETURNS void AS $$
BEGIN UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = post_id; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────
-- REALTIME (enable on key tables)
-- ──────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ──────────────────────────────────────────
-- INDEXES
-- ──────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON public.follows(following_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_post ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_notifs_user ON public.notifications(user_id, read, created_at DESC);

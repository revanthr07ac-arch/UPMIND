# UPMIND Backend Deployment & Operations Guide

This guide details the deployment of the Supabase backend infrastructure and AI Edge Functions for UPMIND.

---

## 1. Supabase Project Setup

1. Create an account and project on [Supabase](https://supabase.com).
2. Set your database password securely.
3. In **Project Settings > API**, obtain:
   - **Project URL** (e.g. `https://your-ref.supabase.co`)
   - **Anon public key** (safe for client use)
   - **Service role secret** (used ONLY for backend deployments)

---

## 2. Database Migrations Execution

Run the migration scripts in numerical sequence either via the **Supabase Dashboard SQL Editor** or using the **Supabase CLI**.

### Via Supabase CLI:
```bash
# Link to your remote project
supabase link --project-ref your-project-ref

# Apply database migrations
supabase db push
```

### Via Supabase SQL Editor:
Copy and execute each file located in `supabase/migrations/`:
1. `001_initial_schema.sql`
   - Provisions tables: `profiles`, `skills`, `user_skills`, `posts`, `likes`, `comments`, `follows`, `saved_posts`, `learning_requests`, `notifications`, `reports`, `blocks`.
   - Creates indexes on foreign keys, usernames, and timestamp descents.
2. `002_row_level_security.sql`
   - Enables RLS on all 12 tables.
   - Enforces participant privacy for learning requests and notifications.
   - Blocks unauthorized mutation of posts, profiles, and comments.
3. `003_storage_and_triggers.sql`
   - Configures `avatars` and `post_images` storage buckets.
   - Installs triggers for user creation, counters (`followers_count`, `likes_count`, `comments_count`), and in-app notification events.
4. `004_seed_skills.sql`
   - Seeds the catalog with 14 diverse skill categories (Mobile Dev, UI/UX, Programming, Photography, Video Editing, AI, etc.).

---

## 3. Storage Buckets Verification

Verify in **Storage > Buckets** that:
- `avatars`: Public read, 5MB file limit, allowed types: `image/jpeg`, `image/png`, `image/webp`.
- `post_images`: Public read, 10MB file limit, allowed types: `image/jpeg`, `image/png`, `image/webp`.
- RLS policies ensure users can only write to their own folder: `(storage.foldername(name))[1] = auth.uid()::text`.

---

## 4. AI Learning Coach Edge Function Deployment

The AI Coach executes server-side via Supabase Edge Functions using Deno and the Google Gemini API.

### Steps:
1. Obtain an API key from [Google AI Studio](https://aistudio.google.com/).
2. Set the secret in Supabase:
   ```bash
   supabase secrets set GEMINI_API_KEY=your_gemini_api_key_here
   ```
3. Deploy the Edge Function:
   ```bash
   supabase functions deploy learning-coach
   ```
4. Verify deployment:
   ```bash
   curl -i --location --request POST 'https://your-ref.supabase.co/functions/v1/learning-coach' \
     --header 'Authorization: Bearer your-anon-key' \
     --header 'Content-Type: application/json' \
     --data '{"skill":"Flutter","experience_level":"beginner","learning_goal":"Build mobile app"}'
   ```

---

## 5. Security & Row Level Security (RLS) Verification

To verify that RLS is active and preventing unauthorized data access:

1. **Profile Isolation**:
   ```sql
   -- Logged in as User A: cannot update User B
   UPDATE public.profiles SET full_name = 'Hacked' WHERE id = 'user-b-id';
   -- Returns: UPDATE 0 (Blocked by RLS)
   ```
2. **Post Modification**:
   ```sql
   -- Cannot delete posts owned by other members
   DELETE FROM public.posts WHERE author_id <> auth.uid();
   -- Returns: DELETE 0 (Blocked by RLS)
   ```
3. **Private Learning Requests**:
   ```sql
   -- Cannot inspect private requests between other parties
   SELECT * FROM public.learning_requests WHERE learner_id <> auth.uid() AND teacher_id <> auth.uid();
   -- Returns: 0 rows (Blocked by RLS)
   ```

# UPMIND — AI-Powered Mobile Skill-Sharing & Learning Platform

> **Tagline:** Showcase Skills. Share Knowledge. Grow Together.  
> **Platform:** Flutter (Android & iOS) • Android Release APK First Delivery  
> **Backend:** Supabase (Auth, PostgreSQL, Row Level Security, Storage, Edge Functions)  
> **AI:** Google Gemini API via Secure Backend Edge Functions  

---

## 1. Product Vision & Overview

**UPMIND** combines the professional skill portfolios and networking capabilities of LinkedIn with the rich content-sharing and community experience of Instagram.

Its unique differentiating mission is to connect people who can teach a skill with people who want to learn that skill.
- Graphic designers showcase visual portfolios and teach design fundamentals.
- Developers publish code breakdown tutorials and guide aspiring programmers.
- Video editors share pacing techniques and accept structured learning requests.
- Beginners learn a skill and eventually transition into mentors in that skill.
- Every user can simultaneously be a learner in one domain and a teacher in another.

> [!IMPORTANT]
> **Zero Paywalls:** UPMIND is designed to be genuinely useful and empowering without requiring paid subscriptions, premium tiers, or hidden monetization.

---

## 2. Key Features

### 🔐 Authentication & Account Management
- Real Supabase authentication with persistent sessions.
- Sign Up with Full Name, unique Username, Email, and Password validation.
- Sign In, Logout, and Password Reset flows.
- Account deletion with server-side cascading cleanup (meeting Apple App Store & Google Play privacy requirements).

### 👤 Profile & Skill Portfolio
- Customizable profile: Avatar upload, bio, location, experience level badge.
- Dynamic Skills Portfolio: Mark skills as **"Can Teach"** or **"Want to Learn"**.
- Public profile viewer with Follow/Unfollow counters and post history.
- Safety options: Block and Report users.

### 📰 Social Feed & Educational Posts
- Multi-format posts: **Text**, **Image/Portfolio Showcase**, and **Educational Tutorials**.
- Educational Tutorial posts feature dedicated lesson breakdowns and step-by-step guidance.
- Engagements: Likes with animated counters, threaded comments, and bookmarking.
- Pull-to-refresh, paginated scrolling, and shimmer skeleton loading states.

### 🔍 Discover & Mentor Search
- Instant, debounced search across usernames, display names, and skills.
- Category pills: Mobile Development, UI/UX Design, Programming, Video & Audio, Photography, AI & Prompt Engineering, Data Science, etc.
- One-tap **"Request to Learn"** modal connecting learners directly to verified teachers.

### 🤝 Teaching & Learning Requests (Core Differentiator)
- Structured learning workflow: Learner specifies skill and personal goal message.
- Teacher receives incoming requests in their **Learning Hub** with Accept/Decline actions.
- Learners track active, accepted, and completed requests with status badges.
- Strict PostgreSQL RLS policies ensuring request privacy between participants.

### 🤖 AI Learning Coach (Gemini API)
- Primary Feature: **Personalized Learning Roadmap Generator**.
- User inputs: Skill, experience level, specific goal, weekly available hours, and learning pace.
- Securely invokes a Supabase Edge Function (`learning-coach`) communicating with Gemini 1.5 Flash.
- Returns comprehensive multi-stage milestones, weekly curriculum, hands-on exercises, self-assessment concept check questions, and coach success tips.
- Offline-resilient fallback engine ensuring zero downtime even if provider quotas are temporarily exhausted.

### 🔔 In-App Notifications
- Alerts for new followers, post comments, likes, and learning request status updates (new, accepted, declined).
- Mark individual or all notifications as read.
- Tap notifications to navigate directly to relevant profiles, posts, or learning requests.

---

## 3. Technology Stack

| Layer | Technology | Details |
|---|---|---|
| **Client** | Flutter 3.47+ & Dart 3.13+ | Cross-platform Material 3, Dark Navy theme |
| **State Management** | Flutter Riverpod 2.6+ | Declarative, testable, reactive state |
| **Navigation** | GoRouter 14.8+ | Deep-link ready, protected routes & bottom nav |
| **Backend & Database** | Supabase & PostgreSQL 15 | Relational integrity, triggers, counter caches |
| **Security** | Row Level Security (RLS) | Explicit SELECT/INSERT/UPDATE/DELETE policies |
| **Object Storage** | Supabase Storage | Buckets for `avatars` and `post_images` |
| **AI Integration** | Supabase Edge Functions + Gemini | Server-side API key custody (no secrets in APK) |

---

## 4. Project Architecture

The codebase follows a clean, feature-first modular architecture:

```
lib/
├── app/
│   ├── app.dart                   # MaterialApp configuration & dark theme
│   ├── main_scaffold.dart         # 5-tab persistent bottom navigation bar
│   ├── router.dart                # GoRouter route declarations & auth guards
│   └── theme/
│       ├── app_colors.dart        # Dark navy palette & gradient accents
│       ├── app_theme.dart         # Material 3 ThemeData
│       └── app_typography.dart    # Google Fonts typography hierarchy
├── core/
│   ├── config/app_config.dart     # Environment config & validation
│   ├── errors/app_exception.dart  # Typed exceptions
│   ├── network/supabase_client.dart
│   ├── utils/
│   │   ├── date_formatter.dart    # Relative timeAgo formatter
│   │   └── validators.dart        # Email, username, password validators
│   └── widgets/
│       ├── custom_button.dart     # Variants: primary, secondary, outline, destructive
│       ├── custom_card.dart       # Navy card surface with subtle border
│       ├── custom_text_field.dart # Form fields with password toggle
│       ├── empty_state.dart       # Reusable empty placeholder
│       ├── error_state.dart       # Reusable error & retry widget
│       ├── loading_indicator.dart # Spinners and animated shimmer skeletons
│       ├── skill_chip.dart        # Badges for Can Teach / Want to Learn
│       ├── upmind_logo.dart       # Neural-gradient brand logo
│       └── user_avatar.dart       # Cached network avatar with initials
└── features/
    ├── auth/                      # Authentication & Session
    ├── discover/                  # Search & Teacher Discovery
    ├── home/                      # Social Feed & Tutorials
    ├── learning/                  # Learning Requests & AI Learning Coach
    ├── notifications/             # In-App Notifications
    ├── posts/                     # Post Creation, Cards, & Comments
    ├── profiles/                  # User Profile & Portfolio Editing
    ├── settings/                  # Guidelines, Privacy, & Account Deletion
    └── skills/                    # Skill Catalog & User Skills
```

---

## 5. Getting Started & Local Development

### Prerequisites
- **Flutter SDK**: 3.24.0 or higher
- **Android SDK**: API 34/36 with Build-Tools
- **Java JDK**: JDK 17 or higher (`JAVA_HOME` configured)
- **Git**

### Installation
1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd UPMIND
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run code analysis & tests:
   ```bash
   dart format .
   flutter analyze
   flutter test
   ```
4. Run locally (Chrome or connected Android device):
   ```bash
   flutter run
   ```

---

## 6. Supabase Backend Setup

### Step 1: Create a Supabase Project
1. Log in to [Supabase](https://supabase.com) and create a new project.
2. Note your **Project URL** and **anon public key** from `Project Settings > API`.

### Step 2: Apply Database Migrations
In your Supabase SQL Editor, run the migration scripts in numerical sequence:
1. `supabase/migrations/001_initial_schema.sql` (Creates all 12 tables, indexes, constraints)
2. `supabase/migrations/002_row_level_security.sql` (Applies strict RLS policies across all tables)
3. `supabase/migrations/003_storage_and_triggers.sql` (Configures Storage buckets and automated triggers)
4. `supabase/migrations/004_seed_skills.sql` (Seeds initial popular skills catalog)

### Step 3: Configure Storage Buckets
The migrations automatically configure the `avatars` and `post_images` storage buckets with public read access and folder-isolated authenticated write policies (`(storage.foldername(name))[1] = auth.uid()::text`).

---

## 7. AI Learning Coach Configuration

The AI Learning Coach utilizes the Google Gemini API. To ensure enterprise-grade security:
- **Zero Client Secrets**: The Gemini API key is **never** embedded in Flutter client code or APK builds.
- Requests pass through the Supabase Edge Function located at `supabase/functions/learning-coach/index.ts`.

### Deploying the Edge Function:
```bash
# Set your Gemini API key as a secret
supabase secrets set GEMINI_API_KEY=your_gemini_api_key_here

# Deploy the function
supabase functions deploy learning-coach
```

---

## 8. Building the Android Release APK

To produce a production release APK:
```bash
flutter build apk --release --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

The compiled release artifact is generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 9. iOS Preparation & macOS Setup

To build and test for iOS on macOS:
1. Open terminal on macOS:
   ```bash
   cd ios
   pod install
   cd ..
   flutter build ios --release --no-codesign
   ```
2. Open `ios/Runner.xcworkspace` in Xcode.
3. Configure your Apple Developer Team in **Signing & Capabilities**.
4. Set bundle identifier to `com.upmind.upmind`.
5. Run on an iOS Simulator or connected iPhone.

---

## 10. Security & Verification Audit

- [x] **Row Level Security**: Enabled on all 12 database tables.
- [x] **Impersonation Prevention**: Policies enforce `auth.uid() = author_id / user_id`.
- [x] **Participant Privacy**: Learning requests and notifications restricted strictly to participants.
- [x] **Storage Isolation**: Users can only upload and mutate media in their own user directory.
- [x] **Automated Test Suite**: 18 unit, widget, and negative security tests passing.
- [x] **Account Deletion**: Functional in settings with permanent cascading removal of user records.

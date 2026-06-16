import { createBrowserClient } from "@supabase/ssr";

// Browser Supabase client. Uses the publishable/anon key, which is safe to ship
// to the client because every table is protected by Row Level Security
// (see supabase/DATABASE_DESIGN.md).
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

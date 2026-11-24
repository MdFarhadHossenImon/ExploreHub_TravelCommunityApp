// Waylo: ExploreHub's assistant. Answers questions about the app (from the app guide)
// and travel questions, using live place data from the database.
// Needs the ANTHROPIC_API_KEY secret; without it the app answers from its built-in guide.
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";
import { ACTIONS, APP_GUIDE } from "./guide.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const DAILY_LIMIT = 40;
const STOP = new Set(["what", "where", "when", "which", "with", "from", "have", "this", "that", "there", "about", "trip", "travel", "best", "much", "cost", "time", "visit", "going", "want", "show", "tell", "does", "should", "could", "would", "place", "places", "kemne", "jabo", "kivabe", "koto"]);

const SYSTEM = `You are Waylo, the friendly assistant inside ExploreHub, a community app for travelers.
You help with two things:
1. How to use ExploreHub. Use only the app guide below. Never invent features, buttons or screens that the guide does not mention; if something is not in the guide, say the app does not have it yet and suggest Menu > Give feedback.
2. Travel questions: places, routes, best season, budgets, food, culture, packing, safety, visas in general terms. Use the "App data" section when it has the place; otherwise use your general knowledge and say prices and rules can change.

Style:
- Reply in the language of the user's latest message (Bangla script if they write Bangla or Banglish, English otherwise).
- Be short and practical: a few sentences or a short list. No long essays.
- To send the user to a screen, put a marker on its own line: [[open:ID]] with one of these IDs: ${ACTIONS}. To link a place from App data, use [[place:PLACE_ID]]. Use at most 3 markers, only when they help.
- In an emergency, tell them to call the local emergency number first and to use Live location & SOS ([[open:sos]]).
- Never ask for passwords, card numbers or ID numbers.

# App guide
${APP_GUIDE}`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "not_configured", message: "Waylo's AI is not switched on yet." }, 503);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: u } = await sb.auth.getUser();
  if (!u?.user) return json({ error: "auth", message: "Please sign in to chat with Waylo." }, 401);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "bad_request", message: "Invalid request." }, 400); }
  const raw: any[] = Array.isArray(body.messages) ? body.messages.slice(-12) : [];
  const messages = raw
    .filter((m) => (m?.role === "user" || m?.role === "assistant") && typeof m.content === "string" && m.content.trim())
    .map((m) => ({ role: m.role as "user" | "assistant", content: String(m.content).slice(0, 2000) }));
  while (messages.length && messages[0].role !== "user") messages.shift();
  if (!messages.length || messages[messages.length - 1].role !== "user") return json({ error: "bad_request", message: "Ask me something." }, 400);

  const { data: left, error: slotErr } = await sb.rpc("ai_take_slot", { p_kind: "waylo", p_limit: DAILY_LIMIT });
  if (slotErr) return json({ error: "server", message: "Waylo can't answer right now." }, 500);
  if (left === -1) return json({ error: "limit", message: `You've reached today's limit of ${DAILY_LIMIT} questions. Try again tomorrow.` }, 429);

  // App data that matches the question: places, their country info, upcoming festivals, the user's trips.
  const q = messages[messages.length - 1].content;
  const words = [...new Set(q.toLowerCase().match(/[a-z][a-z'-]{3,}/g) ?? [])].filter((w) => !STOP.has(w)).slice(0, 6);
  let places: any[] = [];
  if (words.length) {
    const or = words.flatMap((w) => [`name.ilike.%${w}%`, `location.ilike.%${w}%`, `country.ilike.%${w}%`]).join(",");
    const { data } = await sb.from("places")
      .select("id,name,location,country,category,hub,about,season,last_detail,last_duration,budget_low,budget_high")
      .or(or).order("popularity", { ascending: false, nullsFirst: false }).limit(6);
    places = data ?? [];
  }
  const countries = [...new Set(places.map((p) => p.country))].slice(0, 2);
  const today = new Date().toISOString().slice(0, 10);
  const none = Promise.resolve({ data: [] as any[] });
  const [{ data: info }, { data: fests }, { data: trips }] = await Promise.all([
    countries.length ? sb.from("country_info").select("country,capital,currency,currency_code,emergency,plugs,languages").in("country", countries) : none,
    countries.length ? sb.from("festivals").select("name,country,city,starts,ends,approx").in("country", countries).gte("ends", today).order("starts").limit(6) : none,
    sb.from("trips").select("title,start_date,days,place_id").eq("owner_id", u.user.id).gte("start_date", today).order("start_date").limit(3),
  ]);
  const appData = [
    `Today: ${today}.`,
    places.length ? "Places:\n" + places.map((p) =>
      `- [${p.id}] ${p.name} (${p.location}, ${p.country}), ${p.category}. ${(p.about ?? "").slice(0, 280)} Best season: ${p.season ?? "?"}. Getting there: from ${p.hub}; ${p.last_detail ?? ""} (${p.last_duration ?? "?"}). Daily budget about $${p.budget_low ?? "?"}-${p.budget_high ?? "?"}.`).join("\n") : "",
    info?.length ? "Countries:\n" + info.map((c: any) => `- ${c.country}: capital ${c.capital}, currency ${c.currency} (${c.currency_code}), emergency ${c.emergency}, plugs ${c.plugs}, languages ${c.languages}.`).join("\n") : "",
    fests?.length ? "Upcoming festivals:\n" + fests.map((f: any) => `- ${f.name}, ${f.city ?? f.country}: ${f.starts}${f.ends !== f.starts ? " to " + f.ends : ""}${f.approx ? " (approx.)" : ""}`).join("\n") : "",
    trips?.length ? "The user's upcoming trips:\n" + trips.map((t: any) => `- ${t.title}: ${t.start_date}, ${t.days} days, place ${t.place_id}`).join("\n") : "",
  ].filter(Boolean).join("\n\n");

  const client = new Anthropic({ apiKey });
  try {
    const msg = await client.messages.create({
      model: "claude-haiku-5-5",
      max_tokens: 2000,
      system: [{ type: "text", text: SYSTEM }, { type: "text", text: "# App data (from the ExploreHub database)\n" + appData }],
      messages,
      output_config: { effort: "low" },
    } as any);
    if (msg.stop_reason === "refusal") return json({ reply: "Sorry, I can't help with that one. Ask me about travel or ExploreHub!", remaining: left });
    const text = msg.content.filter((b: any) => b.type === "text").map((b: any) => b.text).join("").trim();
    return json({ reply: text || "…", remaining: left, places: places.map((p) => ({ id: p.id, name: p.name })) });
  } catch (e) {
    console.error("waylo error", e);
    return json({ error: "server", message: "Waylo is busy. Please try again." }, 502);
  }
});

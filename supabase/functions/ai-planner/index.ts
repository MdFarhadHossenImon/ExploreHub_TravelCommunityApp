// AI trip planner: builds a day-by-day itinerary with Claude.
// Needs the ANTHROPIC_API_KEY secret (set by the project owner in Supabase).
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["title", "summary", "currency", "total_estimate", "days", "tips"],
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
    currency: { type: "string" },
    total_estimate: { type: "number" },
    tips: { type: "array", items: { type: "string" } },
    days: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["day", "title", "items", "cost"],
        properties: {
          day: { type: "integer" },
          title: { type: "string" },
          cost: { type: "number" },
          items: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["time", "activity", "note"],
              properties: {
                time: { type: "string" },
                activity: { type: "string" },
                note: { type: "string" },
              },
            },
          },
        },
      },
    },
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return json({ error: "not_configured", message: "AI planner is not set up yet. The app owner needs to add an API key." }, 503);
  }

  const auth = req.headers.get("Authorization") ?? "";
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData } = await sb.auth.getUser();
  if (!userData?.user) return json({ error: "auth", message: "Please sign in." }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "bad_request", message: "Invalid request." }, 400); }
  const destination = String(body.destination ?? "").trim().slice(0, 120);
  const days = Math.min(14, Math.max(1, Number(body.days) || 0));
  const budget = Math.max(0, Number(body.budget) || 0);
  const currency = String(body.currency ?? "BDT").slice(0, 8);
  const style = String(body.style ?? "").slice(0, 200);
  const lang = body.lang === "bn" ? "bn" : "en";
  if (!destination || !days) return json({ error: "bad_request", message: "Destination and days are required." }, 400);

  const { data: left, error: slotErr } = await sb.rpc("ai_planner_take_slot", { p_limit: 5 });
  if (slotErr) return json({ error: "server", message: "Could not start the planner." }, 500);
  if (left === -1) return json({ error: "limit", message: "Daily limit reached (5 plans per day). Try again tomorrow." }, 429);

  const client = new Anthropic({ apiKey });
  const prompt =
    `Plan a ${days}-day trip to ${destination} with a total budget of about ${budget} ${currency} per person` +
    (style ? `. Traveler preferences: ${style}` : "") +
    `. Give a realistic day-by-day itinerary with times, places, local food, transport between stops, and an estimated cost for each day in ${currency}. ` +
    `Keep total_estimate within the budget where possible; if it is not realistic, say so in the summary. Add practical safety and money-saving tips. ` +
    (lang === "bn" ? "Write all text in Bangla (Bengali script)." : "Write all text in English.");

  try {
    const stream = client.messages.stream({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      system: "You are an experienced local travel planner for ExploreHub, a community of travelers. Be concrete and practical.",
      messages: [{ role: "user", content: prompt }],
      output_config: { effort: "medium", format: { type: "json_schema", schema: SCHEMA } },
    } as any);
    const msg = await stream.finalMessage();
    if (msg.stop_reason === "refusal") {
      return json({ error: "refused", message: "The planner could not make a plan for this request." }, 422);
    }
    const text = msg.content.filter((b: any) => b.type === "text").map((b: any) => b.text).join("");
    const plan = JSON.parse(text);
    return json({ plan, remaining: left });
  } catch (e) {
    console.error("planner error", e);
    return json({ error: "server", message: "The planner is busy. Please try again." }, 502);
  }
});

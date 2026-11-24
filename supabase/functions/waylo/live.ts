// Free, keyless live data for Waylo: weather, exchange rates, travel search, app places.
// Used both as tools for the AI and by the free mode (no AI key).
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

const UA = { "User-Agent": "ExploreHubWaylo/1.0 (travel community app)" };

async function getJson(url: string, ms = 8000): Promise<any> {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, { headers: UA, signal: ctl.signal });
    if (!r.ok) throw new Error(`${r.status}`);
    return await r.json();
  } finally {
    clearTimeout(t);
  }
}

export type Spot = { name: string; country?: string; lat: number; lng: number; id?: string };

const STOP = new Set([
  "what", "whats", "where", "when", "which", "with", "from", "have", "this", "that", "there", "about", "trip", "travel", "best", "much", "cost",
  "time", "visit", "going", "want", "show", "tell", "does", "should", "could", "would", "place", "places", "today", "tomorrow", "week", "now",
  "weather", "temperature", "rain", "forecast", "like", "how", "the", "and", "for", "in", "at", "to", "is", "are", "will", "be", "it", "of",
  "kemon", "kemne", "jabo", "kivabe", "koto", "ajke", "kal", "abohawa", "brishti", "hobe", "ki", "er", "e", "te", "please", "info", "about",
  "আবহাওয়া", "বৃষ্টি", "তাপমাত্রা", "আজকে", "আজ", "কাল", "কেমন", "কী", "কি", "হবে", "এর", "এ", "তে", "কোথায়", "কীভাবে", "সম্পর্কে", "বলো", "বলুন",
]);

// Common place names written in Bangla, so "সিলেটের আবহাওয়া" finds Sylhet.
const BN_PLACES: [string, string][] = [
  ["সিলেট", "sylhet"], ["ঢাকা", "dhaka"], ["চট্টগ্রাম", "chittagong"], ["কক্সবাজার", "cox's bazar"], ["কক্স বাজার", "cox's bazar"], ["সাজেক", "sajek"],
  ["বান্দরবান", "bandarban"], ["রাঙ্গামাটি", "rangamati"], ["রাঙামাটি", "rangamati"], ["খাগড়াছড়ি", "khagrachari"], ["শ্রীমঙ্গল", "sreemangal"],
  ["কুয়াকাটা", "kuakata"], ["সুন্দরবন", "sundarbans"], ["সেন্টমার্টিন", "saint martin"], ["সেন্ট মার্টিন", "saint martin"], ["জাফলং", "jaflong"],
  ["রাতারগুল", "ratargul"], ["রাজশাহী", "rajshahi"], ["খুলনা", "khulna"], ["বরিশাল", "barisal"], ["রংপুর", "rangpur"], ["ময়মনসিংহ", "mymensingh"],
  ["কুমিল্লা", "comilla"], ["টাঙ্গুয়ার", "tanguar"], ["নেপাল", "nepal"], ["কাঠমান্ডু", "kathmandu"], ["দার্জিলিং", "darjeeling"], ["কলকাতা", "kolkata"],
  ["ভুটান", "bhutan"], ["মালদ্বীপ", "maldives"], ["ব্যাংকক", "bangkok"], ["থাইল্যান্ড", "thailand"], ["দুবাই", "dubai"], ["মক্কা", "mecca"],
  ["মদিনা", "medina"], ["সিঙ্গাপুর", "singapore"], ["মালয়েশিয়া", "malaysia"], ["কাশ্মীর", "kashmir"], ["ভারত", "india"], ["পাহাড়পুর", "paharpur"],
];

/** The question with Bangla place names replaced by English ones. */
export function toEnglishPlaces(q: string): string {
  for (const [b, e] of BN_PLACES) q = q.split(b).join(` ${e} `);
  return q;
}

export function keywords(q: string): string[] {
  q = toEnglishPlaces(q);
  return [...new Set(q.toLowerCase().split(/[\s,.?!।:;()"'\/-]+/).filter((w) => w.length > 2 && !STOP.has(w) && !/^\d+$/.test(w)))];
}

/** A place from ExploreHub's own list whose name, area or country matches the words. */
export async function appPlaces(sb: SupabaseClient, words: string[], limit = 5): Promise<any[]> {
  const ws = words.filter((w) => /^[a-z][a-z'-]{2,}$/.test(w)).slice(0, 6);
  if (!ws.length) return [];
  const or = ws.flatMap((w) => [`name.ilike.%${w}%`, `location.ilike.%${w}%`]).join(",");
  const { data } = await sb.from("places")
    .select("id,name,location,country,category,hub,about,season,last_detail,last_duration,budget_low,budget_high,lat,lng")
    .or(or).order("popularity", { ascending: false, nullsFirst: false }).limit(30);
  // Rank: words in the name count most; a place must match at least half the words, so "Sajek Valley" is not "Kathmandu Valley".
  const scored = (data ?? []).map((p: any, i: number) => {
    const name = String(p.name).toLowerCase(), loc = String(p.location ?? "").toLowerCase();
    let hit = 0, score = 0;
    for (const w of ws) {
      if (name.includes(w)) { hit++; score += 2; } else if (loc.includes(w)) { hit++; score += 1; }
    }
    return { p, hit, score: score - i * 0.001, inName: ws.some((w) => name.includes(w)) };
  }).filter((x: any) => x.hit * 2 >= ws.length);
  scored.sort((a: any, b: any) => b.score - a.score);
  return scored.slice(0, limit).map((x: any) => Object.assign(x.p, { _inName: x.inName }));
}

/** Coordinates for a place name: ExploreHub's list first, then Open-Meteo's geocoder (Bangladesh first). */
export async function locate(sb: SupabaseClient, text: string): Promise<Spot | null> {
  const words = keywords(text);
  const own = (await appPlaces(sb, words, 1))[0];
  // Only use an app place when the question names it; "Sylhet" alone means the city, not a spot near it.
  if (own?.lat != null && own._inName) return { name: own.name, country: own.country, lat: own.lat, lng: own.lng, id: own.id };
  const tries = [words.join(" "), ...words.filter((w) => /^[a-z]/.test(w) && w.length > 3)].filter(Boolean).slice(0, 4);
  for (const name of tries) {
    for (const cc of ["&countryCode=BD", ""]) {
      try {
        const r = await getJson(`https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&name=${encodeURIComponent(name)}${cc}`, 5000);
        const g = r.results?.[0];
        if (g) return { name: g.name, country: g.country, lat: g.latitude, lng: g.longitude };
      } catch { /* try the next */ }
    }
  }
  return null;
}

const WMO: Record<number, [string, string]> = {
  0: ["clear", "পরিষ্কার"], 1: ["mostly clear", "প্রায় পরিষ্কার"], 2: ["partly cloudy", "আংশিক মেঘলা"], 3: ["cloudy", "মেঘলা"], 45: ["fog", "কুয়াশা"], 48: ["fog", "কুয়াশা"],
  51: ["drizzle", "গুঁড়ি গুঁড়ি বৃষ্টি"], 53: ["drizzle", "গুঁড়ি গুঁড়ি বৃষ্টি"], 55: ["drizzle", "গুঁড়ি গুঁড়ি বৃষ্টি"], 61: ["light rain", "হালকা বৃষ্টি"], 63: ["rain", "বৃষ্টি"],
  65: ["heavy rain", "ভারী বৃষ্টি"], 80: ["showers", "দমকা বৃষ্টি"], 81: ["showers", "দমকা বৃষ্টি"], 82: ["heavy showers", "ভারী বৃষ্টি"], 95: ["thunderstorm", "বজ্রঝড়"],
  96: ["thunderstorm", "বজ্রঝড়"], 99: ["thunderstorm", "বজ্রঝড়"], 71: ["snow", "তুষার"], 73: ["snow", "তুষার"], 75: ["heavy snow", "ভারী তুষার"],
};

/** Current weather and a 7-day forecast, as short lines. */
export async function weather(spot: Spot, bn = false): Promise<string> {
  const r = await getJson(`https://api.open-meteo.com/v1/forecast?latitude=${spot.lat}&longitude=${spot.lng}&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=7`);
  const w = (c: number) => (WMO[c] ?? ["", ""])[bn ? 1 : 0];
  const d = r.daily;
  const lines = d.time.map((t: string, i: number) =>
    `${t}: ${w(d.weather_code[i])}, ${Math.round(d.temperature_2m_min[i])}–${Math.round(d.temperature_2m_max[i])}°C, ${bn ? "বৃষ্টির সম্ভাবনা" : "rain"} ${d.precipitation_probability_max[i] ?? 0}%`);
  const now = r.current ? `${bn ? "এখন" : "Now"}: ${Math.round(r.current.temperature_2m)}°C, ${w(r.current.weather_code)}` : "";
  return [`${spot.name}${spot.country ? ", " + spot.country : ""}`, now, ...lines].filter(Boolean).join("\n");
}

const CUR: Record<string, string> = {
  dollar: "USD", usd: "USD", "ডলার": "USD", taka: "BDT", tk: "BDT", bdt: "BDT", "টাকা": "BDT", euro: "EUR", eur: "EUR", "ইউরো": "EUR",
  rupee: "INR", rupees: "INR", inr: "INR", rupi: "INR", "রুপি": "INR", pound: "GBP", gbp: "GBP", "পাউন্ড": "GBP", riyal: "SAR", sar: "SAR", "রিয়াল": "SAR",
  dirham: "AED", aed: "AED", "দিরহাম": "AED", ringgit: "MYR", myr: "MYR", "রিংগিত": "MYR", baht: "THB", thb: "THB", "বাত": "THB", yen: "JPY", jpy: "JPY",
  "ইয়েন": "JPY", yuan: "CNY", cny: "CNY", won: "KRW", krw: "KRW", sgd: "SGD", rupiah: "IDR", idr: "IDR", npr: "NPR", lkr: "LKR", try: "TRY", lira: "TRY",
  cad: "CAD", aud: "AUD", qar: "QAR", kwd: "KWD", omr: "OMR",
};

/** Currencies named in a question, in order. */
export function currenciesIn(q: string): string[] {
  const out: string[] = [];
  for (const w of q.toLowerCase().split(/[\s,.?!।:;()"'\/-]+/)) {
    const c = CUR[w];
    if (c && !out.includes(c)) out.push(c);
  }
  return out;
}

export async function rate(from: string, to: string, amount = 1): Promise<string> {
  from = from.toUpperCase();
  to = to.toUpperCase();
  const r = await getJson(`https://open.er-api.com/v6/latest/${encodeURIComponent(from)}`);
  const x = r.rates?.[to];
  if (!x) return `No rate for ${from} → ${to}.`;
  const fmt = (n: number) => n.toLocaleString("en-US", { maximumFractionDigits: n < 10 ? 4 : 2 });
  return `${fmt(amount)} ${from} = ${fmt(amount * x)} ${to} (${(r.time_last_update_utc ?? "").slice(5, 16)})`;
}

/** Wikivoyage (travel guide) and Wikipedia summaries for a query. */
export async function travelSearch(query: string, bn = false): Promise<{ title: string; text: string; url: string; source: string }[]> {
  const out: { title: string; text: string; url: string; source: string }[] = [];
  const sites = bn ? [["bn.wikipedia.org", "উইকিপিডিয়া"], ["en.wikivoyage.org", "Wikivoyage"]] : [["en.wikivoyage.org", "Wikivoyage"], ["en.wikipedia.org", "Wikipedia"]];
  await Promise.all(sites.map(async ([host, source]) => {
    try {
      const s = await getJson(`https://${host}/w/api.php?action=query&list=search&format=json&srlimit=1&srsearch=${encodeURIComponent(query)}`, 6000);
      const title = s.query?.search?.[0]?.title;
      if (!title) return;
      const sum = await getJson(`https://${host}/api/rest_v1/page/summary/${encodeURIComponent(title.replace(/ /g, "_"))}`, 6000);
      if (sum.extract) out.push({ title, text: String(sum.extract).slice(0, 900), url: sum.content_urls?.mobile?.page ?? `https://${host}/wiki/${encodeURIComponent(title)}`, source });
    } catch { /* skip this site */ }
  }));
  return out;
}

const WEATHER_RE = /\b(weather|temperature|forecast|rain\w*|hot|cold|abohawa|brishti)\b|আবহাওয়া|বৃষ্টি|তাপমাত্রা|গরম|ঠান্ডা|ঠাণ্ডা|কুয়াশা/i;
const FX_RE = /\b(rate|exchange|convert|currency|dollars?|usd|euros?|rupees?|riyals?|ringgit|baht)\b|ডলার|রেট|মুদ্রা|ইউরো|রুপি|রিয়াল|কনভার্ট/i;

/** Free mode: answer live questions (weather, currency, places) without any AI. Null when there is nothing live to say. */
export async function freeAnswer(sb: SupabaseClient, q: string, bn: boolean): Promise<string | null> {
  const T = (en: string, b: string) => (bn ? b : en);
  if (FX_RE.test(q)) {
    const cs = currenciesIn(q);
    const qd = q.replace(/[০-৯]/g, (d) => String(d.charCodeAt(0) - 0x09e6));
    const amount = Number((qd.match(/\d+(?:[.,]\d+)?/) ?? ["1"])[0].replace(",", "")) || 1;
    const from = cs[0] ?? "USD", to = cs[1] ?? (from === "BDT" ? "USD" : "BDT");
    try {
      return `${T("Today's rate", "আজকের রেট")}: ${await rate(from, to, amount)}\n${T("Source: open.er-api.com. Banks and money changers add their own margin.", "সূত্র: open.er-api.com। ব্যাংক বা মানি এক্সচেঞ্জ নিজেদের মার্জিন যোগ করে।")}`;
    } catch { return null; }
  }
  if (WEATHER_RE.test(q)) {
    const spot = await locate(sb, q);
    if (!spot) return T("Which place? For example: \"weather in Sylhet\".", "কোন জায়গার? যেমন: \"সিলেটের আবহাওয়া\" বা \"Sylhet weather\"।");
    try {
      return `${T("Weather forecast", "আবহাওয়ার পূর্বাভাস")} · ${await weather(spot, bn)}\n${T("Source: Open-Meteo.", "সূত্র: Open-Meteo।")}${spot.id ? `\n[[place:${spot.id}]]` : ""}`;
    } catch { return null; }
  }
  const words = keywords(q);
  if (!words.length) return null;
  const own = await appPlaces(sb, words, 1);
  const hits = await travelSearch(own[0]?.name ?? words.slice(0, 5).join(" "), bn);
  if (!own.length && !hits.length) return null;
  const parts: string[] = [];
  if (own[0]) {
    const p = own[0];
    parts.push(`${p.name}, ${p.location}, ${p.country}\n${T("Best season", "ঘোরার সেরা সময়")}: ${p.season ?? "?"}\n${T("Getting there", "কীভাবে যাবেন")}: ${T("from", "")} ${p.hub}${bn ? " থেকে" : ""}, ${p.last_detail ?? ""} (${p.last_duration ?? "?"})${p.budget_low ? `\n${T("Daily budget", "দৈনিক খরচ")}: ~$${p.budget_low}–${p.budget_high}` : ""}`);
  }
  for (const h of hits.slice(0, own.length ? 1 : 2)) parts.push(`${h.title} (${h.source}): ${h.text}`);
  return parts.join("\n\n") + (own[0] ? `\n[[place:${own[0].id}]]\n[[open:planner]]` : "");
}

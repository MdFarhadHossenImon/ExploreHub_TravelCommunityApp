// Free trip planner: builds a day-by-day itinerary from free, keyless APIs.
//  - Sights: Wikidata SPARQL (places with coordinates near the destination, with Bangla names)
//  - Food: OpenStreetMap Overpass (best effort; skipped when busy)
//  - Weather: Open-Meteo forecast (when the trip starts within 15 days)
//  - Exchange rate: open.er-api.com
// Plus ExploreHub's own places table. Results are cached in planner_cache.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const UA = { "User-Agent": "ExploreHubTripPlanner/1.0 (travel community app)" };

type Sight = { name: string; bn?: string; type: string; desc?: string; descBn?: string; lat: number; lng: number; score: number; own?: boolean };
type Food = { name: string; bn?: string; kind: string; lat: number; lng: number };

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

async function cached<T>(key: string, maxDays: number, fetcher: () => Promise<T | null>): Promise<T | null> {
  const { data } = await admin.from("planner_cache").select("data, fetched_at").eq("key", key).maybeSingle();
  if (data && Date.now() - new Date(data.fetched_at).getTime() < maxDays * 864e5) return data.data as T;
  try {
    const fresh = await fetcher();
    console.log("fetched", key, Array.isArray(fresh) ? fresh.length : fresh);
    if (fresh != null) {
      const { error } = await admin.from("planner_cache").upsert({ key, data: fresh, fetched_at: new Date().toISOString() });
      if (error) console.error("cache write", key, error.message);
    }
    return fresh ?? (data?.data as T) ?? null;
  } catch (e) {
    console.error("fetch failed", key, e);
    return (data?.data as T) ?? null;
  }
}

async function getJson(url: string, ms: number, init: RequestInit = {}) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, { ...init, headers: { ...UA, ...(init.headers ?? {}) }, signal: ctl.signal });
    if (!r.ok) throw new Error(`${r.status} ${url.slice(0, 60)}`);
    return await r.json();
  } finally {
    clearTimeout(t);
  }
}

// Wikidata classes that make good stops, with the interest they belong to.
const TYPES: Record<string, string> = {
  Q570116: "sight", Q2319498: "sight", Q1440300: "sight", Q12280: "sight", Q4989906: "history", Q5003624: "history",
  Q33506: "history", Q207694: "history", Q839954: "history", Q23413: "history", Q16560: "history", Q2065736: "history",
  Q32815: "faith", Q44539: "faith", Q842402: "faith", Q16970: "faith", Q5393308: "faith",
  Q34038: "nature", Q23397: "nature", Q22698: "nature", Q39816: "nature", Q40080: "nature", Q8502: "nature", Q54050: "nature",
  Q1107656: "nature", Q46169: "nature", Q473972: "nature", Q23442: "nature", Q35509: "nature", Q131681: "nature",
};

async function wikidataSights(lat: number, lng: number, radiusKm: number): Promise<Sight[]> {
  const q = `SELECT ?item ?en ?bn ?type ?coord ?sl ?den ?dbn WHERE {
  SERVICE wikibase:around { ?item wdt:P625 ?coord . bd:serviceParam wikibase:center "Point(${lng} ${lat})"^^geo:wktLiteral . bd:serviceParam wikibase:radius "${radiusKm}" . }
  ?item wdt:P31 ?type . VALUES ?type { ${Object.keys(TYPES).map((k) => "wd:" + k).join(" ")} }
  ?item wikibase:sitelinks ?sl .
  ?item rdfs:label ?en FILTER(lang(?en)="en")
  OPTIONAL { ?item rdfs:label ?bn FILTER(lang(?bn)="bn") }
  OPTIONAL { ?item schema:description ?den FILTER(lang(?den)="en") }
  OPTIONAL { ?item schema:description ?dbn FILTER(lang(?dbn)="bn") }
} ORDER BY DESC(?sl) LIMIT 80`;
  const r = await getJson("https://query.wikidata.org/sparql?format=json&query=" + encodeURIComponent(q), 20000, { headers: { Accept: "application/sparql-results+json" } });
  const seen = new Set<string>();
  const out: Sight[] = [];
  for (const b of r.results.bindings) {
    const name = b.en.value as string;
    const key = name.toLowerCase();
    if (seen.has(key) || /^Q\d+$/.test(name)) continue;
    seen.add(key);
    const m = /Point\(([-\d.]+) ([-\d.]+)\)/.exec(b.coord.value);
    if (!m) continue;
    out.push({
      name, bn: b.bn?.value, type: TYPES[b.type.value.split("/").pop()] ?? "sight",
      desc: b.den?.value, descBn: b.dbn?.value, lng: +m[1], lat: +m[2], score: +b.sl.value,
    });
  }
  return out;
}

async function osmFood(lat: number, lng: number): Promise<Food[] | null> {
  const q = `[out:json][timeout:15];nwr(around:5000,${lat},${lng})["amenity"~"^(restaurant|cafe|fast_food)$"]["name"];out center tags 40;`;
  for (const host of ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]) {
    try {
      const r = await getJson(host, 8000, { method: "POST", body: "data=" + encodeURIComponent(q), headers: { "Content-Type": "application/x-www-form-urlencoded" } });
      return (r.elements ?? []).map((e: any) => ({
        name: e.tags.name, bn: e.tags["name:bn"], kind: e.tags.amenity,
        lat: e.lat ?? e.center?.lat, lng: e.lon ?? e.center?.lon,
      })).filter((f: Food) => f.lat && f.lng);
    } catch (e) {
      console.error("overpass", host, String(e));
    }
  }
  return []; // cached briefly so the next plan does not wait on a busy server
}

const km = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => {
  const R = 6371, r = Math.PI / 180;
  const x = Math.sin(((b.lat - a.lat) * r) / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(((b.lng - a.lng) * r) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
};

const WMO: Record<number, [string, string]> = {
  0: ["Clear sky", "পরিষ্কার আকাশ"], 1: ["Mostly clear", "প্রায় পরিষ্কার"], 2: ["Partly cloudy", "আংশিক মেঘলা"], 3: ["Cloudy", "মেঘলা"],
  45: ["Fog", "কুয়াশা"], 48: ["Fog", "কুয়াশা"], 51: ["Drizzle", "গুঁড়ি গুঁড়ি বৃষ্টি"], 53: ["Drizzle", "গুঁড়ি গুঁড়ি বৃষ্টি"], 55: ["Drizzle", "গুঁড়ি গুঁড়ি বৃষ্টি"],
  61: ["Light rain", "হালকা বৃষ্টি"], 63: ["Rain", "বৃষ্টি"], 65: ["Heavy rain", "ভারী বৃষ্টি"], 80: ["Showers", "দমকা বৃষ্টি"], 81: ["Showers", "দমকা বৃষ্টি"],
  82: ["Heavy showers", "ভারী বৃষ্টি"], 95: ["Thunderstorm", "বজ্রঝড়"], 96: ["Thunderstorm", "বজ্রঝড়"], 99: ["Thunderstorm", "বজ্রঝড়"],
  71: ["Snow", "তুষার"], 73: ["Snow", "তুষার"], 75: ["Heavy snow", "ভারী তুষার"],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "bad_request", message: "Invalid request." }, 400); }
  const bn = body.lang === "bn";
  const T = (en: string, b: string) => (bn ? b : en);
  const days = Math.min(14, Math.max(1, Math.round(Number(body.days) || 0)));
  const currency = body.currency === "USD" ? "USD" : "BDT";
  const budget = Math.max(0, Number(body.budget) || 0);
  const interests: string[] = Array.isArray(body.interests) ? body.interests.map(String) : [];
  const start = /^\d{4}-\d{2}-\d{2}$/.test(String(body.start ?? "")) ? new Date(body.start + "T00:00:00Z") : null;

  const { data: place } = await sb.from("places").select("*").eq("id", String(body.place_id ?? "")).maybeSingle();
  if (!place || place.lat == null) return json({ error: "bad_request", message: "Pick a destination." }, 400);
  const base = { lat: place.lat as number, lng: place.lng as number };
  const { data: ci } = await sb.from("country_info").select("*").eq("country", place.country).maybeSingle();

  // Fetch everything in parallel.
  const [wd, food, rate, nearbyOwn, weather] = await Promise.all([
    cached<Sight[]>(`wd:${place.id}`, 30, () => wikidataSights(base.lat, base.lng, 35)),
    cached<Food[]>(`osmfood:${place.id}`, 7, () => osmFood(base.lat, base.lng)),
    currency === "BDT"
      ? cached<number>("fx:USD:BDT", 1, async () => (await getJson("https://open.er-api.com/v6/latest/USD", 8000)).rates?.BDT ?? null)
      : Promise.resolve(1),
    sb.from("places").select("id,name,about,category,lat,lng,popularity").eq("country", place.country)
      .gte("lat", base.lat - 0.6).lte("lat", base.lat + 0.6).gte("lng", base.lng - 0.6).lte("lng", base.lng + 0.6).neq("id", place.id).limit(30)
      .then((r) => r.data ?? []),
    (async () => {
      if (!start) return null;
      const ahead = (start.getTime() - Date.now()) / 864e5;
      if (ahead < -1 || ahead + days > 16) return null;
      const s = start.toISOString().slice(0, 10), e = new Date(start.getTime() + (days - 1) * 864e5).toISOString().slice(0, 10);
      try {
        return await getJson(`https://api.open-meteo.com/v1/forecast?latitude=${base.lat}&longitude=${base.lng}&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&start_date=${s}&end_date=${e}`, 8000);
      } catch { return null; }
    })(),
  ]);
  const fx = currency === "BDT" ? (Number(rate) || 120) : 1;

  // Candidate stops: our own curated places first, then Wikidata, ranked by fame, distance and interests.
  const own: Sight[] = nearbyOwn.filter((p: any) => p.lat != null).map((p: any) => ({
    name: p.name, type: /mountain|hill|lake|beach|waterfall|forest|island|river/i.test(p.category) ? "nature" : "sight",
    desc: (p.about ?? "").split(". ")[0], lat: p.lat, lng: p.lng, score: 40 + (p.popularity ?? 0) / 10, own: true,
  }));
  const mainName = String(place.name).toLowerCase();
  let pool = [...own, ...(wd ?? [])].filter((s) => s.name.toLowerCase() !== mainName && km(base, s) < 60);
  const names = new Set<string>();
  pool = pool.filter((s) => !names.has(s.name.toLowerCase()) && names.add(s.name.toLowerCase()));
  const rank = (s: Sight) => s.score * (interests.length === 0 || interests.includes(s.type) ? 1.6 : 0.6) - km(base, s) * 0.25;
  pool.sort((a, b) => rank(b) - rank(a));
  pool = pool.slice(0, Math.max(3, days * 3));

  // Budget per day in USD and a price level.
  const low = Number(place.budget_low ?? ci?.budget_low ?? 25), high = Number(place.budget_high ?? ci?.budget_high ?? 100);
  const budgetUsd = budget / fx;
  const perDay = budget > 0 ? budgetUsd / days : (low + high) / 3;
  const level = perDay < low ? "tight" : perDay < (low + high) / 2 ? "standard" : "comfort";
  const dayUsd = Math.round(level === "tight" ? Math.max(perDay, low * 0.7) : Math.min(perDay, high));
  const money = (usd: number) => Math.round((usd * fx) / (currency === "BDT" ? 50 : 1)) * (currency === "BDT" ? 50 : 1);

  const label = (s: { name: string; bn?: string }) => (bn && s.bn ? s.bn : s.name);
  const placeName = place.name as string;
  const foodList = (food ?? []).slice();
  const pickFood = (near: { lat: number; lng: number }, kind: string[]) => {
    let best = -1, bd = 1e9;
    foodList.forEach((f, i) => { const d = km(near, f); if (kind.includes(f.kind) && d < bd) { bd = d; best = i; } });
    if (best < 0) return null;
    return foodList.splice(best, 1)[0];
  };
  const meal = (near: { lat: number; lng: number }, time: string, en: string, b: string, kinds = ["restaurant", "fast_food", "cafe"]) => {
    const f = pickFood(near, kinds);
    return f
      ? { time, activity: T(`${en} at ${f.name}`, `${b}: ${label(f)}`), note: T("Picked from OpenStreetMap. Check it is open.", "OpenStreetMap থেকে নেওয়া। খোলা আছে কিনা দেখে নিন।") }
      : { time, activity: T(`${en} at a local eatery`, `${b}: স্থানীয় হোটেল/রেস্তোরাঁয়`), note: T("Ask locals for the busiest place, it is usually the best.", "স্থানীয়দের জিজ্ঞেস করুন, ভিড় বেশি যেখানে সেখানেই সাধারণত ভালো।") };
  };
  const stop = (s: Sight, time: string) => {
    const d = km(base, s);
    const what = bn ? (s.descBn ?? "") : (s.desc ?? "");
    const dist = d < 1 ? T("in town", "শহরের ভেতরেই") : T(`${d.toFixed(0)} km from ${placeName}`, `${placeName} থেকে ${d.toFixed(0)} কিমি`);
    return { time, activity: T(`Visit ${s.name}`, `${label(s)} ঘুরে দেখা`), note: [what, dist].filter(Boolean).join(" · ") };
  };

  // Order the stops so each day stays in one area (nearest neighbour from the base).
  const order: Sight[] = [];
  let cur = base;
  const left = pool.slice();
  while (left.length) {
    let bi = 0;
    left.forEach((s, i) => { if (km(cur, s) < km(cur, left[bi])) bi = i; });
    cur = left[bi];
    order.push(left.splice(bi, 1)[0]);
  }

  const facilities: string[] = place.facilities ?? [];
  const fillers = [
    () => ({ time: "15:30", activity: T(`Slow afternoon around ${placeName}`, `${placeName}-এর আশেপাশে ধীরে-সুস্থে ঘোরা`), note: T("Walk the local market and try street snacks.", "স্থানীয় বাজার ঘুরে দেখুন, রাস্তার খাবার চেখে দেখুন।") }),
    () => ({ time: "06:00", activity: T(`Sunrise at ${placeName}`, `${placeName}-এ সূর্যোদয় দেখা`), note: T("Early light is the best time for photos.", "ছবি তোলার জন্য ভোরের আলো সবচেয়ে ভালো।") }),
    () => ({ time: "10:00", activity: facilities[0] ? T(`${facilities[0]} at ${placeName}`, `${placeName}-এ ${facilities[0]}`) : T("Free morning to rest", "বিশ্রামের জন্য সকালটা ফাঁকা"), note: T("Keep one easy slot so the trip does not feel rushed.", "একটা সময় ফাঁকা রাখুন, যাতে তাড়াহুড়ো না হয়।") }),
  ];

  const dayCost = money(dayUsd);
  const out: any[] = [];
  let k = 0, f = 0;
  for (let d = 1; d <= days; d++) {
    const items: any[] = [];
    let title = "";
    if (d === 1) {
      title = T(`Arrive in ${placeName}`, `${placeName}-এ পৌঁছানো`);
      items.push({ time: "07:00", activity: T(`Travel from ${place.hub} to ${placeName}`, `${place.hub} থেকে ${placeName} যাত্রা`), note: [place.last_detail, place.last_duration ? T(`About ${place.last_duration}`, `প্রায় ${place.last_duration}`) : ""].filter(Boolean).join(" · ") });
      items.push(meal(base, "13:00", "Lunch", "দুপুরের খাবার"));
      items.push({ time: "15:00", activity: T(`Explore ${placeName}`, `${placeName} ঘুরে দেখা`), note: (place.about ?? "").split(". ")[0] });
      items.push(meal(base, "20:00", "Dinner", "রাতের খাবার"));
    } else if (d === days) {
      title = T("Last morning and return", "শেষ সকাল আর ফেরা");
      if (k < order.length) items.push(stop(order[k++], "08:00")); else items.push(fillers[1]());
      items.push(meal(base, "12:00", "Early lunch", "আগেভাগে দুপুরের খাবার"));
      items.push({ time: "13:30", activity: T(`Head back to ${place.hub}`, `${place.hub}-এ ফেরা`), note: T("Leave in daylight, roads can be slow.", "দিনের আলো থাকতে রওনা দিন, রাস্তায় সময় লাগতে পারে।") });
    } else {
      const todays = order.slice(k, k + 3);
      k += todays.length;
      const area = todays[0] ?? base;
      title = todays.length ? T(`${todays[0].name} and around`, `${label(todays[0])} ও আশেপাশে`) : T(`Easy day in ${placeName}`, `${placeName}-এ হালকা দিন`);
      items.push(meal(base, "07:30", "Breakfast", "নাস্তা", ["cafe", "fast_food", "restaurant"]));
      if (todays[0]) items.push(stop(todays[0], "09:00")); else items.push(fillers[(f++) % 3]());
      if (todays[1]) items.push(stop(todays[1], "11:30"));
      items.push(meal(area, "13:30", "Lunch", "দুপুরের খাবার"));
      if (todays[2]) items.push(stop(todays[2], "15:30")); else items.push(fillers[(f++) % 3]());
      items.push(meal(base, "20:00", "Dinner", "রাতের খাবার"));
    }
    let wx = "";
    const w = weather?.daily;
    if (w && w.time?.[d - 1]) {
      const c = WMO[w.weather_code[d - 1]] ?? ["", ""];
      wx = `${bn ? c[1] : c[0]}, ${Math.round(w.temperature_2m_min[d - 1])}–${Math.round(w.temperature_2m_max[d - 1])}°C` +
        (w.precipitation_probability_max?.[d - 1] != null ? T(`, rain ${w.precipitation_probability_max[d - 1]}%`, `, বৃষ্টির সম্ভাবনা ${w.precipitation_probability_max[d - 1]}%`) : "");
    }
    out.push({ day: d, title, cost: dayCost, weather: wx, items });
  }

  const tips: string[] = [];
  if (place.season) tips.push(T(`Best season: ${place.season}.`, `ঘোরার সেরা সময়: ${place.season}।`));
  if (budget > 0 && level === "tight") tips.push(T(`Your budget is tight for ${placeName}. Share rooms and transport with buddies to save.`, `${placeName}-এর জন্য বাজেট একটু কম। বন্ধুদের সাথে রুম আর গাড়ি শেয়ার করলে খরচ কমবে।`));
  const split = (p: number) => money(dayUsd * p);
  tips.push(T(`Daily split: stay ~${split(0.4)}, food ~${split(0.25)}, transport ~${split(0.25)}, tickets ~${split(0.1)} ${currency}.`,
    `প্রতিদিনের হিসাব: থাকা ~${split(0.4)}, খাওয়া ~${split(0.25)}, যাতায়াত ~${split(0.25)}, টিকিট ~${split(0.1)} ${currency}।`));
  if (ci?.emergency) tips.push(T(`Emergency number in ${place.country}: ${ci.emergency}.`, `${place.country}-এ জরুরি নম্বর: ${ci.emergency}।`));
  if (ci?.plugs && place.country !== "Bangladesh") tips.push(T(`Plugs: ${ci.plugs}.`, `প্লাগ: ${ci.plugs}।`));
  if (weather?.daily?.precipitation_probability_max?.some((p: number) => p >= 60)) tips.push(T("Rain is likely on some days. Pack a rain cover and keep indoor options.", "কিছু দিন বৃষ্টি হতে পারে। রেইনকোট নিন আর ঘরের ভেতরের বিকল্প রাখুন।"));
  tips.push(T("Weekends and holidays fill up fast. Book your stay early.", "ছুটির দিনে ভিড় বেশি হয়, থাকার জায়গা আগে বুক করুন।"));

  const total = dayCost * days;
  return json({
    plan: {
      title: T(`${days} days in ${placeName}`, `${placeName}-এ ${days} দিন`),
      summary: T(
        `${out.length}-day plan from ${place.hub}, ${order.length ? `with ${Math.min(order.length, k)} nearby sights` : "at an easy pace"}. Price level: ${level}.`,
        `${place.hub} থেকে ${out.length} দিনের প্ল্যান${order.length ? `, আশেপাশের ${Math.min(order.length, k)}টি জায়গা সহ` : ""}। বাজেট ধরন: ${level === "tight" ? "কম খরচে" : level === "standard" ? "মাঝারি" : "আরামদায়ক"}।`,
      ),
      currency,
      total_estimate: total,
      days: out,
      tips,
      sources: ["Wikidata", "OpenStreetMap", ...(weather ? ["Open-Meteo"] : []), ...(currency === "BDT" ? ["open.er-api.com"] : []), "ExploreHub"],
    },
  });
});

# Source of truth for Waylo's knowledge of the app. Generates:
# Run from the repo root: python3 tool/waylo_guide.py
#  - assets/waylo_guide.json (offline answers in the app)
#  - supabase/functions/waylo/guide.ts (system prompt for the AI)
import json
S = []
def sec(id, kw, en, bn, action=None, title=None, title_bn=None):
    S.append(dict(id=id, kw=kw, en=en, bn=bn, action=action, title=title or id, title_bn=title_bn or title or id))

sec('about', 'explorehub app what is about travelers community features feature key main overview offer list everything এক্সপ্লোরহাব অ্যাপ কী ফিচার সুবিধা কাজ',
 "ExploreHub is a community app only for travelers. Key features:\n- Feed, stories and Watch: share and watch trip photos and videos\n- Explore: find places, see how to reach them, reviews and photos\n- Book hotels, flights, trains, buses and local guides\n- Trips: plan day by day, invite buddies, split costs, packing list\n- Smart trip planner: a free day-by-day plan with weather and costs\n- Same time, same place: meet travelers going on the same dates\n- Travel buddies, messages, groups and meetups\n- Live location & SOS for safety\n- Travel passport, phrasebook and festivals\n- Waylo (me!): app help, weather and today's rates\n- English and বাংলা, and it works offline\nThe bottom bar has Feed, Explore, the + button (new post), Trips and Menu.",
 "ExploreHub শুধু ভ্রমণকারীদের জন্য একটা কমিউনিটি অ্যাপ। মূল ফিচারগুলো:\n- Feed, স্টোরি আর Watch: ট্রিপের ছবি-ভিডিও শেয়ার করা ও দেখা\n- Explore: জায়গা খোঁজা, কীভাবে যাবেন, রিভিউ আর ছবি\n- হোটেল, ফ্লাইট, ট্রেন, বাস আর লোকাল গাইড বুকিং\n- Trips: দিন ধরে প্ল্যান, বাডি ইনভাইট, খরচ ভাগ, প্যাকিং লিস্ট\n- Smart trip planner: আবহাওয়া আর খরচসহ ফ্রি দিনভিত্তিক প্ল্যান\n- Same time, same place: একই তারিখে একই জায়গায় যাচ্ছেন এমন ট্রাভেলার\n- ট্রাভেল বাডি, মেসেজ, গ্রুপ আর মিটআপ\n- নিরাপত্তার জন্য Live location ও SOS\n- ট্রাভেল পাসপোর্ট, ফ্রেজবুক আর উৎসব\n- Waylo (আমি!): অ্যাপের সাহায্য, আবহাওয়া আর আজকের রেট\n- English ও বাংলা, আর ইন্টারনেট ছাড়াও চলে\nনিচের বারে আছে Feed, Explore, + বাটন (নতুন পোস্ট), Trips আর Menu।",
 None, 'What is ExploreHub', 'ExploreHub কী')
sec('post', 'post share photo video upload create story caption tag পোস্ট শেয়ার ছবি ভিডিও আপলোড স্টোরি',
 "Tap the big + button in the middle of the bottom bar. Pick Photo or Video, write a caption, tag a place, then tap Post. Videos show up in Watch too. To share a 24-hour story, use the story circle at the top of the Feed.",
 "নিচের বারের মাঝের বড় + বাটনে চাপুন। Photo বা Video বেছে নিন, ক্যাপশন লিখুন, জায়গা ট্যাগ করুন, তারপর Post চাপুন। ভিডিওগুলো Watch-এও দেখা যায়। ২৪ ঘণ্টার স্টোরি দিতে Feed-এর উপরের স্টোরি সার্কেল ব্যবহার করুন।",
 'new_post', 'Share a post', 'পোস্ট শেয়ার')
sec('watch', 'watch video reels pause sound mute auto scroll 10 seconds ভিডিও ওয়াচ রিল সাউন্ড মিউট অটো স্ক্রল',
 "Watch shows travel videos full screen. Tap a video to pause or play. Double tap the right side to jump 10 seconds forward, the left side to go 10 seconds back. The speaker button turns sound on or off, and videos stay muted once you mute. Turn on Auto scroll at the top right to move to the next video when one ends.",
 "Watch-এ ভ্রমণের ভিডিও পুরো স্ক্রিনে দেখা যায়। ভিডিওতে ট্যাপ করলে pause/play হয়। ডান পাশে ডাবল ট্যাপ করলে ১০ সেকেন্ড সামনে, বাম পাশে করলে ১০ সেকেন্ড পেছনে যায়। স্পিকার বাটনে সাউন্ড চালু/বন্ধ হয়, একবার mute করলে mute-ই থাকে। উপরে ডানে Auto scroll চালু করলে একটা ভিডিও শেষ হলে পরেরটা আসে।",
 'watch', 'Watch videos', 'Watch ভিডিও')
sec('explore', 'explore find place destination search where go beach hill country জায়গা খোঁজা সার্চ কোথায় যাব দর্শনীয়',
 "Open the Explore tab (compass icon) to browse places by category, spin the globe, or use Search at the top to find any place, traveler or post. Open a place to see About, How to go, Reviews, Photos and Videos.",
 "Explore ট্যাবে (কম্পাস আইকন) ক্যাটাগরি ধরে জায়গা দেখুন, গ্লোব ঘোরান, অথবা উপরের Search দিয়ে যেকোনো জায়গা, ট্রাভেলার বা পোস্ট খুঁজুন। কোনো জায়গা খুললে About, How to go, Reviews, Photos আর Videos দেখা যায়।",
 'search', 'Find places', 'জায়গা খোঁজা')
sec('howtogo', 'how to go reach route bus train flight direction travel time cost কীভাবে যাব রুট বাস ট্রেন যাতায়াত ভাড়া',
 "Open the place and tap the How to go tab. It shows the route from the nearest hub, the last stretch (boat, jeep and so on), travel time and a step-by-step route planner from your city. For tickets, use Flight, Train or Bus on the Explore tab.",
 "জায়গাটা খুলে How to go ট্যাবে চাপুন। সেখানে কাছের শহর থেকে রুট, শেষ অংশ (নৌকা, জিপ ইত্যাদি), সময় আর আপনার শহর থেকে ধাপে ধাপে রুট দেখাবে। টিকিটের জন্য Explore ট্যাবের Flight, Train বা Bus ব্যবহার করুন।",
 'search', 'How to reach a place', 'কীভাবে যাবেন')
sec('book', 'book hotel stay room flight train bus ticket booking cancel হোটেল বুক টিকিট বুকিং রুম বাতিল',
 "On the Explore tab, under 'Book everything for your trip', pick Hotel, Flight, Train, Bus or Guide. Your bookings are in Trips > Bookings, where you can see details or cancel.",
 "Explore ট্যাবে 'Book everything for your trip' অংশে Hotel, Flight, Train, Bus বা Guide বেছে নিন। আপনার বুকিংগুলো Trips > Bookings-এ থাকে, সেখান থেকে বিস্তারিত দেখা বা বাতিল করা যায়।",
 'bookings', 'Bookings', 'বুকিং')
sec('trips', 'trip plan itinerary day stops create new trip budget expense packing list invite buddy ট্রিপ প্ল্যান ভ্রমণ পরিকল্পনা খরচ প্যাকিং',
 "Go to Trips (map icon) > Plan a new trip. Pick the place, dates and budget. Inside a trip you can add stops for each day, invite buddies, split expenses and keep a packing list. Trip buddies get a group chat.",
 "Trips (ম্যাপ আইকন) > Plan a new trip-এ যান। জায়গা, তারিখ আর বাজেট দিন। ট্রিপের ভেতরে প্রতিদিনের স্টপ যোগ করা, বাডিদের ইনভাইট করা, খরচ ভাগ করা আর প্যাকিং লিস্ট রাখা যায়। ট্রিপের বাডিদের জন্য গ্রুপ চ্যাটও থাকে।",
 'trips', 'Plan a trip', 'ট্রিপ প্ল্যান')
sec('planner', 'smart planner auto plan generate itinerary free days budget স্মার্ট প্ল্যানার অটো প্ল্যান বানাও বাজেট দিন',
 "Smart trip planner (in Trips and Menu) builds a free day-by-day plan: pick a place, start date, days, budget and what you like. It adds nearby sights, weather and daily costs. Tap 'Save as my trip' to keep and edit it.",
 "Smart trip planner (Trips আর Menu-তে) ফ্রিতে দিন ধরে ধরে প্ল্যান বানায়: জায়গা, শুরুর তারিখ, কত দিন, বাজেট আর পছন্দ দিন। আশেপাশের জায়গা, আবহাওয়া আর প্রতিদিনের খরচ যোগ করে দেয়। 'Save as my trip' চাপলে সেভ হয়, পরে বদলানো যায়।",
 'planner', 'Smart trip planner', 'স্মার্ট ট্রিপ প্ল্যানার')
sec('sametime', 'same time same place who else going travelers match meet হিডেন একই সময় একই জায়গা আর কে যাচ্ছে',
 "When you make a trip, the trip page and the place's About tab show other travelers going to the same place on overlapping dates, so you can send a buddy request. To hide yourself, turn off 'Show me to travelers on the same dates' in the trip.",
 "ট্রিপ বানালে ট্রিপের পেজে আর জায়গার About ট্যাবে দেখাবে আর কারা একই সময়ে একই জায়গায় যাচ্ছে, তাদের বাডি রিকোয়েস্ট পাঠানো যায়। নিজেকে লুকাতে ট্রিপের ভেতরে সুইচটা বন্ধ করুন।",
 'trips', 'Same time, same place', 'একই সময়, একই জায়গা')
sec('buddies', 'buddy friend add follow request travel partner companion বাডি বন্ধু ফলো রিকোয়েস্ট সঙ্গী',
 "Menu > Travel buddies shows requests, your buddies and suggestions. Open any traveler's profile to follow them or send a buddy request. Buddies can see your live location when you share it.",
 "Menu > Travel buddies-এ রিকোয়েস্ট, আপনার বাডি আর সাজেশন থাকে। যেকোনো ট্রাভেলারের প্রোফাইল খুলে ফলো বা বাডি রিকোয়েস্ট পাঠান। লাইভ লোকেশন শেয়ার করলে বাডিরা দেখতে পায়।",
 'buddies', 'Travel buddies', 'ট্রাভেল বাডি')
sec('messages', 'message chat inbox dm group chat send মেসেজ চ্যাট ইনবক্স',
 "Tap the chat bubble at the top or Menu > Messages. Start a new chat with the + button. Long-press your message to delete it for everyone.",
 "উপরের চ্যাট বাবল বা Menu > Messages-এ চাপুন। + বাটন দিয়ে নতুন চ্যাট শুরু করুন। নিজের মেসেজ চেপে ধরে রাখলে সবার জন্য ডিলিট করা যায়।",
 'messages', 'Messages', 'মেসেজ')
sec('groups', 'group community join create private গ্রুপ কমিউনিটি জয়েন',
 "Menu > Groups lets you join travel groups or create your own (public or private) with rules and posts only members see.",
 "Menu > Groups থেকে ট্রাভেল গ্রুপে জয়েন করুন বা নিজের গ্রুপ বানান (পাবলিক বা প্রাইভেট), নিয়মসহ।",
 'groups', 'Groups', 'গ্রুপ')
sec('meetups', 'meetup event host rsvp meet travelers মিটআপ ইভেন্ট দেখা করা',
 "Menu > Meetups lists traveler meetups. Tap one to RSVP, or 'Host a meetup' to make your own with place, time and capacity.",
 "Menu > Meetups-এ ট্রাভেলারদের মিটআপ থাকে। একটায় চাপ দিয়ে RSVP করুন, বা 'Host a meetup' দিয়ে নিজেই বানান।",
 'meetups', 'Meetups', 'মিটআপ')
sec('guides', 'local guide hire guide become guide verified apply গাইড লোকাল গাইড ভাড়া গাইড হতে চাই',
 "Menu > Local guides lists verified guides with price per day, languages and reviews. To become a guide, open that page and apply with your ID; the team reviews it.",
 "Menu > Local guides-এ ভেরিফাইড গাইডদের দিনপ্রতি রেট, ভাষা আর রিভিউ দেখা যায়। গাইড হতে চাইলে ওই পেজ থেকে আইডিসহ আবেদন করুন, টিম যাচাই করবে।",
 'guides', 'Local guides', 'লোকাল গাইড')
sec('sos', 'sos emergency help danger live location share safety police ambulance জরুরি বিপদ সাহায্য লাইভ লোকেশন পুলিশ',
 "Menu > Live location & SOS. Share your live location with buddies for a set time, or hold the SOS button for 2 seconds: all your buddies get an alert with your location, and you see the local emergency number to call. Tap 'I'm safe' when it's over. The Safety center has advisories and emergency numbers.",
 "Menu > Live location & SOS। নির্দিষ্ট সময়ের জন্য বাডিদের সাথে লাইভ লোকেশন শেয়ার করুন, অথবা SOS বাটন ২ সেকেন্ড চেপে ধরুন: সব বাডির কাছে আপনার লোকেশনসহ অ্যালার্ট যাবে, আর স্থানীয় জরুরি নম্বর দেখাবে। বিপদ কাটলে 'I'm safe' চাপুন।",
 'sos', 'Live location & SOS', 'লাইভ লোকেশন ও SOS')
sec('passport', 'passport badges stats countries visited year in travel map stamp পাসপোর্ট ব্যাজ কত দেশ',
 "Menu > Travel passport colors the countries you've been to on a map, shows stats, stamps and 12 badges, and a 'Year in travel' card you can share.",
 "Menu > Travel passport-এ ম্যাপে আপনার ঘোরা দেশগুলো রঙিন দেখায়, সাথে পরিসংখ্যান, স্ট্যাম্প, ১২টা ব্যাজ আর শেয়ার করার মতো 'Year in travel' কার্ড।",
 'passport', 'Travel passport', 'ট্রাভেল পাসপোর্ট')
sec('phrasebook', 'phrasebook language phrase translate speak pronounce local words হ্যালো ভাষা অনুবাদ উচ্চারণ',
 "Menu > Phrasebook has 19 useful phrases in 24 languages with pronunciation; tap the speaker to hear them. A place's essentials card also opens the right language.",
 "Menu > Phrasebook-এ ২৪টা ভাষায় ১৯টা দরকারি বাক্য, উচ্চারণসহ; স্পিকারে চাপলে শুনতে পাবেন।",
 'phrasebook', 'Phrasebook', 'ফ্রেজবুক')
sec('festivals', 'festival event calendar holiday celebration when উৎসব ইভেন্ট ক্যালেন্ডার মেলা',
 "Menu > Festivals & events shows festivals month by month, for Bangladesh and worldwide. A place page also shows its upcoming festivals.",
 "Menu > Festivals & events-এ মাস ধরে বাংলাদেশ আর বিশ্বের উৎসব দেখা যায়। জায়গার পেজেও আসন্ন উৎসব দেখায়।",
 'festivals', 'Festivals & events', 'উৎসব ও ইভেন্ট')
sec('saved', 'save saved bookmark wishlist favourite সেভ বুকমার্ক',
 "Tap the bookmark on a place or post to save it. Find them in Menu > Saved.",
 "জায়গা বা পোস্টের বুকমার্কে চাপলে সেভ হয়। Menu > Saved-এ পাবেন।",
 'saved', 'Saved', 'সেভ করা')
sec('profile', 'profile edit name photo bio settings account delete logout password privacy প্রোফাইল নাম ছবি সেটিংস অ্যাকাউন্ট লগআউট ডিলিট',
 "Tap your card at the top of Menu to see your profile and Edit profile. Menu > Settings & privacy has notifications, language, log out and delete account.",
 "Menu-র উপরে নিজের কার্ডে চাপলে প্রোফাইল আর Edit profile পাবেন। Menu > Settings & privacy-তে নোটিফিকেশন, ভাষা, লগআউট আর অ্যাকাউন্ট ডিলিট আছে।",
 'profile', 'Profile & settings', 'প্রোফাইল ও সেটিংস')
sec('language', 'language bangla bengali english switch change ভাষা বাংলা ইংরেজি',
 "Switch between English and বাংলা from the Language panel in Menu, or in Settings & privacy. The whole app changes at once.",
 "Menu-র Language অংশ বা Settings & privacy থেকে English আর বাংলার মধ্যে বদলান। পুরো অ্যাপ সাথে সাথে বদলে যায়।",
 'profile', 'Language', 'ভাষা')
sec('offline', 'offline no internet without network data saved অফলাইন ইন্টারনেট ছাড়া',
 "ExploreHub keeps a copy of what you've opened. Without internet you can still see your trips, places, posts and bookings; a banner shows you're offline, and it refreshes when you're back online.",
 "ExploreHub আপনার খোলা জিনিসের কপি রাখে। ইন্টারনেট না থাকলেও ট্রিপ, জায়গা, পোস্ট আর বুকিং দেখা যায়; উপরে অফলাইন ব্যানার দেখায়, নেট ফিরলে নিজে থেকেই আপডেট হয়।",
 None, 'Offline mode', 'অফলাইন মোড')
sec('notifications', 'notification alert bell like comment reminder নোটিফিকেশন অ্যালার্ট',
 "The bell at the top shows likes, comments, buddy requests, trip invites and SOS alerts.",
 "উপরের ঘণ্টা আইকনে লাইক, কমেন্ট, বাডি রিকোয়েস্ট, ট্রিপ ইনভাইট আর SOS অ্যালার্ট দেখা যায়।",
 'notifications', 'Notifications', 'নোটিফিকেশন')
sec('report', 'report block user spam abuse bad post রিপোর্ট ব্লক',
 "Tap the ⋯ on a post to report it, or open a profile to block the person. The Safety center also has 'report a user'.",
 "পোস্টের ⋯ চেপে রিপোর্ট করুন, বা প্রোফাইল খুলে ব্লক করুন। Safety center-এও রিপোর্টের অপশন আছে।",
 'safety', 'Report & block', 'রিপোর্ট ও ব্লক')
sec('feedback', 'feedback bug problem suggestion contact support ফিডব্যাক সমস্যা সাপোর্ট',
 "Menu > Give feedback lets you rate the app, report a bug or suggest a feature. The team reads every one.",
 "Menu > Give feedback থেকে অ্যাপ রেট করা, সমস্যা জানানো বা নতুন ফিচার চাওয়া যায়।",
 'feedback', 'Feedback', 'ফিডব্যাক')

ACTIONS = {
 'new_post': 'New post', 'watch': 'Watch', 'search': 'Search', 'bookings': 'Bookings', 'trips': 'Trips',
 'planner': 'Smart trip planner', 'buddies': 'Travel buddies', 'messages': 'Messages', 'groups': 'Groups',
 'meetups': 'Meetups', 'guides': 'Local guides', 'sos': 'Live location & SOS', 'passport': 'Travel passport',
 'phrasebook': 'Phrasebook', 'festivals': 'Festivals & events', 'saved': 'Saved', 'profile': 'Settings & privacy',
 'notifications': 'Notifications', 'safety': 'Safety center', 'feedback': 'Give feedback',
}
json.dump({'sections': S, 'actions': ACTIONS}, open('assets/waylo_guide.json', 'w'), ensure_ascii=False, indent=1)
guide = "\n".join(f"## {s['title']}\n{s['en']}" + (f"\n(open: [[open:{s['action']}]])" if s['action'] else '') for s in S)
acts = ", ".join(f"{k} ({v})" for k, v in ACTIONS.items())
import os
os.makedirs('supabase/functions/waylo', exist_ok=True)
open('supabase/functions/waylo/guide.ts', 'w').write(
 "// Generated from the Waylo guide. Edit the guide source, not this file.\n"
 f"export const APP_GUIDE = {json.dumps(guide, ensure_ascii=False)};\n"
 f"export const ACTIONS = {json.dumps(acts, ensure_ascii=False)};\n")
print(len(S), len(guide))

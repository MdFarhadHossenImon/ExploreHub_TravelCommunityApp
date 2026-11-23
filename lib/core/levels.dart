import 'package:flutter/material.dart';

/// Traveler levels, earned only from posts at real places:
/// every distinct place a traveler has posted from (a listed destination,
/// or a place they tagged with its country) counts once.
class TravelerLevel {
  final String name;
  final String short;
  final IconData icon;
  final Color color;
  final int minPlaces;
  final String rule;
  const TravelerLevel(this.name, this.short, this.icon, this.color, this.minPlaces, this.rule);
}

const travelerLevels = <TravelerLevel>[
  TravelerLevel('Newcomer', 'New', Icons.eco_rounded, Color(0xFF8FB3AC), 0, 'Just starting out. Post from a place to begin.'),
  TravelerLevel('Beginner traveler', 'Beginner', Icons.hiking_rounded, Color(0xFF7CC08D), 10, '10 places visited'),
  TravelerLevel('Explorer', 'Explorer', Icons.explore_rounded, Color(0xFF6FB7E9), 25, '25 places visited'),
  TravelerLevel('Adventurer', 'Adventurer', Icons.terrain_rounded, Color(0xFFB68CF0), 50, '50 places visited'),
  TravelerLevel('Professional traveler', 'Professional', Icons.workspace_premium_rounded, Color(0xFFE9C46A), 100, '100 places visited'),
  TravelerLevel('Pro world traveler', 'Pro', Icons.public_rounded, Color(0xFFE76F51), 100,
      '100 places in at least 25 countries, across all 6 inhabited continents'),
];

/// Continents of countries travelers are likely to post from.
const _continent = <String, String>{
  // Asia
  'Bangladesh': 'Asia', 'India': 'Asia', 'Nepal': 'Asia', 'Bhutan': 'Asia', 'Sri Lanka': 'Asia', 'Maldives': 'Asia',
  'Pakistan': 'Asia', 'Afghanistan': 'Asia', 'China': 'Asia', 'Japan': 'Asia', 'Korea': 'Asia', 'South Korea': 'Asia',
  'North Korea': 'Asia', 'Mongolia': 'Asia', 'Taiwan': 'Asia', 'Hong Kong': 'Asia', 'Thailand': 'Asia', 'Vietnam': 'Asia',
  'Cambodia': 'Asia', 'Laos': 'Asia', 'Myanmar': 'Asia', 'Malaysia': 'Asia', 'Singapore': 'Asia', 'Indonesia': 'Asia',
  'Philippines': 'Asia', 'Brunei': 'Asia', 'Timor-Leste': 'Asia', 'Kazakhstan': 'Asia', 'Uzbekistan': 'Asia',
  'Kyrgyzstan': 'Asia', 'Tajikistan': 'Asia', 'Turkmenistan': 'Asia', 'Iran': 'Asia', 'Iraq': 'Asia', 'Saudi Arabia': 'Asia',
  'United Arab Emirates': 'Asia', 'UAE': 'Asia', 'Qatar': 'Asia', 'Oman': 'Asia', 'Kuwait': 'Asia', 'Bahrain': 'Asia',
  'Jordan': 'Asia', 'Israel': 'Asia', 'Palestine': 'Asia', 'Lebanon': 'Asia', 'Syria': 'Asia', 'Yemen': 'Asia',
  'Turkey': 'Asia', 'Georgia': 'Asia', 'Armenia': 'Asia', 'Azerbaijan': 'Asia',
  // Europe
  'United Kingdom': 'Europe', 'UK': 'Europe', 'Ireland': 'Europe', 'France': 'Europe', 'Germany': 'Europe', 'Italy': 'Europe',
  'Spain': 'Europe', 'Portugal': 'Europe', 'Netherlands': 'Europe', 'Belgium': 'Europe', 'Luxembourg': 'Europe',
  'Switzerland': 'Europe', 'Austria': 'Europe', 'Greece': 'Europe', 'Norway': 'Europe', 'Sweden': 'Europe', 'Finland': 'Europe',
  'Denmark': 'Europe', 'Iceland': 'Europe', 'Poland': 'Europe', 'Czechia': 'Europe', 'Czech Republic': 'Europe',
  'Slovakia': 'Europe', 'Hungary': 'Europe', 'Romania': 'Europe', 'Bulgaria': 'Europe', 'Croatia': 'Europe',
  'Slovenia': 'Europe', 'Serbia': 'Europe', 'Bosnia and Herzegovina': 'Europe', 'Montenegro': 'Europe', 'Albania': 'Europe',
  'North Macedonia': 'Europe', 'Estonia': 'Europe', 'Latvia': 'Europe', 'Lithuania': 'Europe', 'Ukraine': 'Europe',
  'Moldova': 'Europe', 'Belarus': 'Europe', 'Russia': 'Europe', 'Malta': 'Europe', 'Cyprus': 'Europe', 'Monaco': 'Europe',
  // Africa
  'Egypt': 'Africa', 'Morocco': 'Africa', 'Tunisia': 'Africa', 'Algeria': 'Africa', 'Libya': 'Africa', 'Sudan': 'Africa',
  'Ethiopia': 'Africa', 'Kenya': 'Africa', 'Tanzania': 'Africa', 'Uganda': 'Africa', 'Rwanda': 'Africa', 'Nigeria': 'Africa',
  'Ghana': 'Africa', 'Senegal': 'Africa', 'South Africa': 'Africa', 'Namibia': 'Africa', 'Botswana': 'Africa',
  'Zimbabwe': 'Africa', 'Zambia': 'Africa', 'Mozambique': 'Africa', 'Madagascar': 'Africa', 'Mauritius': 'Africa',
  'Seychelles': 'Africa', 'Cameroon': 'Africa', 'Ivory Coast': 'Africa', "Côte d'Ivoire": 'Africa', 'Malawi': 'Africa',
  // North America
  'United States': 'North America', 'USA': 'North America', 'Canada': 'North America', 'Mexico': 'North America',
  'Cuba': 'North America', 'Jamaica': 'North America', 'Dominican Republic': 'North America', 'Bahamas': 'North America',
  'Costa Rica': 'North America', 'Panama': 'North America', 'Guatemala': 'North America', 'Belize': 'North America',
  'Honduras': 'North America', 'Nicaragua': 'North America', 'El Salvador': 'North America', 'Puerto Rico': 'North America',
  // South America
  'Brazil': 'South America', 'Argentina': 'South America', 'Chile': 'South America', 'Peru': 'South America',
  'Bolivia': 'South America', 'Colombia': 'South America', 'Ecuador': 'South America', 'Venezuela': 'South America',
  'Uruguay': 'South America', 'Paraguay': 'South America', 'Guyana': 'South America', 'Suriname': 'South America',
  // Oceania
  'Australia': 'Oceania', 'New Zealand': 'Oceania', 'Fiji': 'Oceania', 'Papua New Guinea': 'Oceania', 'Samoa': 'Oceania',
  'Tonga': 'Oceania', 'Vanuatu': 'Oceania', 'Solomon Islands': 'Oceania', 'French Polynesia': 'Oceania',
};

/// Country names offered when tagging a place that is not in the catalog.
final List<String> knownCountries = (_continent.keys.where((c) => c.length > 3).toList()..sort());

Set<String> continentsOf(Iterable<String> countries) => {for (final c in countries) if (_continent[c] != null) _continent[c]!};

class LevelProgress {
  final TravelerLevel level;
  final TravelerLevel? next;
  final int places, countries, continents;
  /// 0..1 toward the next level.
  final double progress;
  final String nextHint;
  const LevelProgress(this.level, this.next, this.places, this.countries, this.continents, this.progress, this.nextHint);
}

LevelProgress levelFor(int places, List<String> countries) {
  final cont = continentsOf(countries).length;
  final nCountries = countries.toSet().length;
  final world = places >= 100 && nCountries >= 25 && cont >= 6;
  var idx = 0;
  for (var i = 0; i < 5; i++) {
    if (places >= travelerLevels[i].minPlaces) idx = i;
  }
  if (world) idx = 5;
  final level = travelerLevels[idx];
  if (idx == 5) return LevelProgress(level, null, places, nCountries, cont, 1, 'Top level reached');
  if (idx == 4) {
    final p = ((nCountries / 25).clamp(0, 1) + (cont / 6).clamp(0, 1)) / 2;
    final need = <String>[
      if (nCountries < 25) '${25 - nCountries} more ${25 - nCountries == 1 ? 'country' : 'countries'}',
      if (cont < 6) '${6 - cont} more ${6 - cont == 1 ? 'continent' : 'continents'}',
    ];
    return LevelProgress(level, travelerLevels[5], places, nCountries, cont, p.toDouble(), '${need.join(' and ')} to become a Pro world traveler');
  }
  final next = travelerLevels[idx + 1];
  final span = next.minPlaces - level.minPlaces;
  final p = ((places - level.minPlaces) / span).clamp(0, 1).toDouble();
  final left = next.minPlaces - places;
  return LevelProgress(level, next, places, nCountries, cont, p, '$left more ${left == 1 ? 'place' : 'places'} to become ${next.name.startsWith('E') || next.name.startsWith('A') ? 'an' : 'a'} ${next.name}');
}

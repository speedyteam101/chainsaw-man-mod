// Chat filter for BlockOS: hides swear words and personal details (phone numbers, email
// addresses, links, street addresses) by replacing them with #'s, like most kids' games do.
// Used by relay.js on every typed message before it's passed on.
"use strict";

const MAX_LENGTH = 120;

// Word roots that get hidden, matched at the start of words and ignoring common letter swaps
// (0->o, 1/!->i, 3->e, 4/@->a, 5/$->s, 7->t) and repeated letters. Extend as needed.
const BLOCKED = [
  "fuck", "fuk", "fck", "shit", "sht", "bitch", "btch", "bastard", "asshole", "arse", "dick", "cock", "pussy",
  "cunt", "twat", "wank", "prick", "slut", "whore", "hoe", "piss", "damn", "crap", "bollock", "bugger", "douche",
  "jerk off", "retard", "nigg", "fag", "dyke", "tranny", "spic", "chink", "kike", "porn", "sex", "nude", "naked",
  "boob", "tits", "penis", "vagina", "rape", "kill yourself", "kys", "suicide", "nazi", "hitler",
];

const SWAPS = { "0": "o", "1": "i", "!": "i", "3": "e", "4": "a", "@": "a", "5": "s", "$": "s", "7": "t", "+": "t" };

function normalize(s) {
  return s.toLowerCase().replace(/[01!34@5$7+]/g, (c) => SWAPS[c]).replace(/(.)\1+/g, "$1");
}

const BLOCKED_NORM = BLOCKED.map((b) => b.split(" ").map(normalize).join(" "));

function hashes(n) { return "#".repeat(Math.max(3, Math.min(n, 12))); }

function filterText(input) {
  let text = String(input || "").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, MAX_LENGTH);
  if (!text) return "";

  // Personal details.
  text = text
    .replace(/\b[\w.+-]+@[\w-]+(\.[\w-]+)+\b/g, (m) => hashes(m.length))                          // email
    .replace(/\b(?:https?:\/\/|www\.)\S+|\b[\w-]+\.(?:com|net|org|io|gg|co|me|tv|app|xyz|uk|us|sg|au|ca)\b\S*/gi, (m) => hashes(m.length))  // links
    .replace(/(?:\+?\d[\d\s().-]{5,}\d)/g, (m) => (m.replace(/\D/g, "").length >= 6 ? hashes(m.length) : m))  // phone-like numbers
    .replace(/\b\d+\s+\w+\s+(?:street|st|road|rd|avenue|ave|lane|ln|drive|dr|way|court|ct|blvd)\b/gi, (m) => hashes(m.length))
    .replace(/\b(?:snap(?:chat)?|insta(?:gram)?|tiktok|discord|whatsapp|telegram|kik)\b/gi, (m) => hashes(m.length));

  // Swear words: check each word, two-word phrases, and runs of single letters ("f u c k").
  const words = text.split(" ");
  const norm = words.map((w) => normalize(w).replace(/[^a-z]/g, ""));
  const hit = new Array(words.length).fill(false);
  const isBad = (letters) => BLOCKED_NORM.some((bad) => !bad.includes(" ") && (letters.startsWith(bad) || (bad.length >= 4 && letters.includes(bad))));
  for (let i = 0; i < words.length; i++) {
    if (isBad(norm[i])) hit[i] = true;
    if (i + 1 < words.length) {
      const pair = norm[i] + " " + norm[i + 1];
      if (BLOCKED_NORM.some((bad) => bad.includes(" ") && pair.startsWith(bad))) hit[i] = hit[i + 1] = true;
    }
  }
  for (let i = 0; i < words.length; ) {
    let j = i;
    while (j < words.length && norm[j].length === 1) j++;
    if (j - i >= 3 && isBad(normalize(norm.slice(i, j).join("")))) for (let k = i; k < j; k++) hit[k] = true;
    i = j > i ? j : i + 1;
  }
  // Allow ordinary words that only look like a blocked root.
  const ALLOW = /^(class|pass|grass|glass|bass|mass|assist|assign|assume|hello|shell|shitake|scrap|cockpit|peacock|hancock|dickens|sussex|essex|therapist|cumulative|document|hoed|hoes|shoe|shoes)$/;
  return words.map((w, i) => (hit[i] && !ALLOW.test(norm[i]) ? hashes(w.length) : w)).join(" ");
}

module.exports = { filterText, MAX_LENGTH };

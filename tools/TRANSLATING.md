# Translating "Table of Squares"

The app teaches squares of numbers from 10 to 99 (10² … 99²) to school students, mostly 12–16 years old.
Bright, friendly and playful, but not babyish. Address the player informally (like "ты" in Russian, "du" in German, "tu" in French).

Mechanics, so the words make sense:
- **Field**: a 9×10 board of the squares 10…99. Answer a square right on three different days and the cell is "captured" (yours). If you do not practice, a captured cell starts "fading" and you "defend" it by answering again.
- **Race**: 20 squares against a rival. Rivals are your **Ghost** (your own best run) or bots named **Turtle** (slow), **Owl** (smart, about 2 s per answer), **Robot** (never wrong). Translate the animal/robot names as normal words.
- **Duel**: two people on one phone, screen split in half.
- **Cards**: flashcards, flip and say "Know" / "Don't know".
- **Reverse**: you see 576 and pick the number whose square it is (the root).
- **Lessons / tricks**: mental math tricks shown step by step. "Next door" = the trick where 31² is computed from the neighbouring round number 30².
- **Trophies**: achievements.

Rules:
1. Keep every placeholder: `%lld` (integer), `%@` (text). Same count and type. If word order needs a different order, use positional forms `%1$lld`, `%2$lld`.
2. Keep math symbols exactly: `²`, `×`, `−`, digits.
3. **No emoji. No middle dot `·`** anywhere.
4. UI labels must be SHORT: tab titles (Home, Learn, Field, Trophies), buttons (Again, Done, Next, Know, Exit, Practice, Share) and tile titles (Race, Duel, Cards, Reverse) ideally ≤ 12 characters. Pills like "Fading: %lld" must stay compact.
5. "Table of" + "squares" are the two lines of the big home title "Table of / squares" (first line thin, second bold). Split the app name over two lines naturally for your language; the second line should be the strong word. Either line may be empty-ish but not empty, e.g. Japanese "平方数の" / "表".
6. "Table of Squares" (capitalized) is the app name under the icon: short, ideally ≤ 16 characters. Use the natural name of a "table of squares" in your school system.
7. "Starts fading"/"Days until it fades: %lld" etc.: natural, short.
8. "%@ s" is seconds, like "31.4 s"; use your language's short unit for seconds.
9. "%@ squared" is a screen-reader label like "47 squared".
10. The History texts are first person from the developer ("I made the first version in 9th grade, in 2019, when I was 15"). Translate naturally; keep the facts.

Output: `tools/tr/<code>.json`, an object mapping every key from `tools/source.json` to its translation (all keys, including "Table of Squares"). Validate with `python3 tools/check_tr.py <code>` until it prints OK.

## Icon name
"Squares" is the short app name shown under the home screen icon. It must be **at most 12 characters** (iOS cuts longer names), meaning "squares" as in the math topic (nominative plural, capitalized as a title, e.g. ru "Квадраты", de "Quadrate").

# Emoji/Unicode Sanitize Test

## 1. Smileys (erwartet: :-) :-D :'D ;-) :-))

😀 😁 😂 😉 😊

## 2. Emotionen (erwartet: <3 B-) :-P :-( :'()

😍 😎 😜 😢 😭

## 3. Mehr Gesichter (erwartet: :-O :-O (?) :'D :-|)

😮 😱 🤔 🤣 😐

## 4. Objekte (erwartet: (!) (+1) (-1) (*) [>])

🎉 👍 👎 🔥 🚀

## 5. Symbole (erwartet: (!) (*) [L] [doc] [D])

💡 👋 🔒 📝 📁

## 6. BMP-Symbole (erwartet: Haken Haken (X) (!) <3 Stern [*])

✅ ✔ ❌ ⚠ ❤ ✨ ⚙

## 7. Pfeile (nativ oder ASCII-Fallback)

→ ← ↑ ↓ ➡ ⬅ ⬆ ⬇

## 8. Umlaute (muessen korrekt bleiben)

Ärger Öffnung Übung ändern öffnen überall

## 9. Gemischt

Text mit 😀 Emoji 🎉 drin und Ümlauten.

Drei am Stueck: 😀😁😂 Ende.

## 10. Typografie

Gedankenstrich – und — langer.

„Deutsche Anfuehrung" und 'Englische'.

Ellipse…

## 11. Box-Drawing

─│┌┐└┘┼

## 12. Nur ASCII

Hello World 123 !@# keine Sonderzeichen.

## 13. Code-Block mit Emoji

```
puts "Hello 😀 World"
set x [expr {1 + 2}]
```

## 14. Tabelle mit Emoji

| Spalte 1 | Status |
|----------|--------|
| Test A   | ✅     |
| Test B   | ❌     |
| Test C   | 😀     |

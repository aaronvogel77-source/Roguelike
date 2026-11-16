# GAME_DESIGN.md – Roguelike (Arbeitstitel offen)

> Einzige Quelle der Wahrheit für alle Designentscheidungen.
> Wird nach jeder beantworteten Fragerunde aktualisiert.

**Status:** Planung – Phase 5, Runde 3 läuft
**Letzte Aktualisierung:** 2026-11-16

---

## Phase 0 – Vision und Rahmen

### Runde 1 (beantwortet)
- **Grundtyp / Pitch:** Action-Roguelite (eigener Pitch-Satz folgt, sobald Setting steht)
- **Inspirationen:**
  - Hades / Binding of Isaac / Dead Cells – Action-Roguelite-Gefühl, Synergien, Meta-Progression
  - **Balatro** – Taktik und Synergien über Tarotkarten, Joker und Gutscheine; spannendes **Kombinieren von Figuren, Karten o. Ä. zu Synergien** (zentrales Wunsch-Element)
- **Genre-Typ:** Roguelite (permanente Verbesserungen zwischen Runs)
- **Zielgefühl:** Survival & Knappheit **+** Power-Fantasy

### Runde 2 (beantwortet)
- **Hauptfokus:** Komplexe Synergien und ein Build, den man sich **strategisch über mehrere Runden erarbeitet**. Synergien sind der Kern des Spiels, das Kampftempo ordnet sich dem unter.
- **Kampftempo:** → *Später entscheiden* (Phase 2). Ein Action-Gefühl ist gewünscht, aber Build-Strategie hat Vorrang.
- **Spannungsbogen:** Kurve „knapp → explosiv“. Früh im Run fehlt es an allem, ein gelungener Build eskaliert wie bei Balatro.
- **Setting:** Dark Fantasy / Okkult (Tarot, Flüche, Pakte)
- **Run-Länge:** 30–45 Minuten für einen erfolgreichen Run
### Runde 3 (beantwortet)
- **„Mehrere Runden“ bedeutet beides:** Der eigentliche Build entsteht im Run und wächst über Stufen wie die Antes in Balatro. Zwischen den Runs werden neue Karten, Joker und Figuren für den Pool freigeschaltet.
- **Zielgruppe:** Roguelite-Fans, die Tiefe mögen. Ein kurzes Onboarding genügt.
- **Projektrahmen:** ~~Kommerzieller Release~~ → in Runde 4 geändert zu **Hobbyprojekt**
- **Programmiererfahrung:** Keine bzw. sehr wenig. Konzepte werden ausführlich erklärt, der Stack muss einsteigerfreundlich sein.

### Machbarkeits-Hinweis
Ein kommerzieller Release ohne Programmiererfahrung ist ein sehr großes Vorhaben. Grob geschätzt sind es 1.500–3.000+ Arbeitsstunden bis zum Release, dazu kommen Art, Sound und Marketing. Gegenmaßnahmen: zuerst ein kleiner, spielbarer **Vertical Slice** (Kern-Synergie-Loop), Umfang hart begrenzen und früh testen.
### Runde 4 (beantwortet)
- **Projektrahmen (revidiert):** Hobbyprojekt mit etwa **10 Std./Woche**. Eine spätere Veröffentlichung (z. B. itch.io) ist nicht ausgeschlossen, aber kein Ziel.
- **Team:** Komplett allein, auch Grafik und Sound. Konsequenz: Der Grafikstil muss solo machbar sein (Phase 1/12).
- **Umfangs-Strategie:** Zuerst ein Vertical Slice: ein Gebiet, ca. 20 Synergie-Teile, ein Boss. Ausbauen erst, wenn der Kern Spaß macht.
- **Pitch (vorläufig):** „Ein Dark-Fantasy-Roguelite, in dem du okkulte Karten, Joker und Pakte zu immer mächtigeren Synergien kombinierst – vom verzweifelten Mangel zur explosiven Übermacht in 30–45 Minuten.“
  - *Hinweis:* „Karten, Joker, Pakte“ sind **Platzhalter** für die Synergie-Objekte und können später durch bessere Ideen ersetzt werden (→ Phase 8/9).

## Phase 1 – Plattform und Technik

### Runde 1 (beantwortet)
- **Plattformen:** Browser + Mobile (Android/iOS). Desktop wurde nicht gewählt, der Browser läuft aber auch auf dem PC.
- **Grafik:** Wird **mit KI generiert**. Das Tool und die Stilrichtung werden in Runde 2 entschieden.
- **Engine:** Godot 4 + GDScript
- **Eingabe:** Maus + Touchscreen

### Konsequenzen
- **Touch hat kein Hover:** Tooltips (zentral für Synergien) brauchen eine Alternative, z. B. Long-Press oder Tippen → Detail-Panel. Die UI wird **Touch-first** entworfen, die Maus folgt automatisch.
- **Mobile-Bildschirm:** Synergie-Objekte müssen auf ~6-Zoll-Displays lesbar sein. Das begrenzt, wie viele Objekte gleichzeitig sichtbar sein können.
- **Kampftempo (Phase 2):** Präzise Echtzeit-Action à la Hades ist per Touch schwer umzusetzen. Rundenbasierte oder Auto-Kampf-Varianten passen besser zu Touch.
- **Godot-Web-Export:** Funktioniert für 2D gut. Auf Mobile-Browsern müssen Ladezeit und Performance früh getestet werden. Ein späterer nativer Android/iOS-Export ist möglich (iOS erfordert einen Mac).
- **KI-Grafik:** Konsistenz entsteht über Referenzbilder bzw. einen trainierten Stil, nicht über Prompts. Nacharbeit ist einzuplanen, außerdem die Nutzungsrechte des jeweiligen Tools prüfen.

### Runde 2 (beantwortet)
- **Ausrichtung:** Querformat. Am Handy wird beidhändig gespielt, im Browser passt es ideal.
- **Kunststil:** Illustrierter Tarot-Look wie alte Tarot- oder Holzschnitt-Karten mit begrenzter Farbpalette und wenig Animation.
- **KI-Tool:** Wird durch einen Vergleichstest mit 2–3 Tools gewählt (Kandidaten: Scenario, Leonardo.Ai, ggf. ein weiteres). Gleiches Testmotiv, z. B. eine Joker-Karte und ein Monster.
- **Bildaufbau:** Kompaktes, vollständig sichtbares Spielfeld (Raster, z. B. ~7×9), dazu eine Synergie-Leiste. Keine scrollende Kamera.

### Runde 3 (beantwortet)
- **Basisauflösung:** 1280×720 (16:9). Godot skaliert auf jedes Display (Stretch-Modus `canvas_items`, Seitenverhältnis `expand`).
- **KI-Tool-Test:** Nach Abschluss der Planung, wenn die Motive konkret sind. Bis dahin Platzhalter-Grafik.
- **Git:** Claude committet und pusht nach jedem Schritt.
- **Arbeitsteilung:** Claude baut alles. Der Nutzer testet und gibt Feedback und Verbesserungswünsche. Code-Erklärungen gibt es nur auf Wunsch.
  - *Konsequenz:* Jeder Meilenstein muss als **direkt spielbarer Browser-Build** ausgeliefert werden (Godot-Web-Export, z. B. über GitHub Pages), damit ohne Installation getestet werden kann. Details folgen in Phase 15.

## Phase 2 – Kern-Spielschleife und Zeitmodell

### Runde 1 (beantwortet, teilweise widersprüchlich → Klärung in Runde 2)
- **Kern-Loop:** Kampf → Belohnung (1 aus 3 Synergie-Teilen) → regelmäßig Shop → Boss am Ende jeder Stufe
- **Kampftempo:** „Rundenbasiert auf Raster“ gewählt
- **Zeitsystem:** Einfache Züge (eine Aktion pro Zug)
- **Bewegung/Kampf:** „Figuren bewegen sich frei, ohne Raster. Am wichtigsten sind Synergien und Build, Angriffe laufen meist automatisch.“

### Runde 2 (Widerspruch geklärt)
- **Kampfmodell: Auto-Battler.** In der Planungsphase (Shop, Belohnung) stellt der Spieler Figuren, Joker und Karten zusammen und ordnet sie an. Der Kampf läuft danach **automatisch** ab.
  - „Einfache Züge“ bedeutet damit den Rhythmus **Planungsphase → Kampf**, nicht Züge innerhalb des Kampfs.
  - „Frei ohne Raster“ bezieht sich auf die Bewegung im Kampf. Wie die Figuren aufgestellt werden, entscheidet Runde 3.
- **Figuren:** Ein **Team aus Figuren**, die man **leveln und miteinander kombinieren** kann. Die Synergien entstehen zwischen den Figuren und werden durch Joker und Karten verstärkt.
- 📚 Referenzen: Super Auto Pets, Backpack Battles, Teamfight Tactics, Balatro (Synergie-Eskalation)

### Rückwirkung auf Phase 1
- „Kompaktes Spielfeld (Raster ~7×9)“ wird zu einem **kompakten, vollständig sichtbaren Kampffeld**. Die genaue Aufstellungsform wird in Phase 2, Runde 3 entschieden.
- Touch passt sehr gut: Drag & Drop in der Planungsphase, Zuschauen im Kampf.

### Runde 3 (beantwortet)
- **Aufstellung:** **Eine Reihe** mit 5–6 Plätzen. Vorne kämpft zuerst. Positions-Synergien sind möglich, z. B. Nachbar-Buffs oder „wenn die vordere Figur stirbt…“ (Super Auto Pets).
- **Kampfdarstellung:** **Schritt für Schritt.** Angriffe und Effekte laufen nacheinander mit kurzer Animation, jede Synergie-Auslösung ist sichtbar. Tempo-Taste 1×/2×/4×.
- **Niederlage:** **Eine verlorene Schlacht = Tod des Runs** (harter Permadeath).
- **Run-Ziel:** Feste Akte mit je einem Boss. Nach dem finalen Boss ist der Run gewonnen, optional folgt ein Endlos-Modus für die Power-Fantasy.

### ⚠️ Risiko: Permadeath im Auto-Battler
Weil der Kampf automatisch läuft, kann eine einzelne Niederlage als unfair empfunden werden („Ich konnte nichts tun“). Gegenmaßnahmen werden in Runde 4 entschieden, z. B. Gegner-Vorschau.

### Runde 4 (beantwortet)
- **Fairness/Vorschau:** Volle Vorschau auf die Gegner-Teams (Werte und Fähigkeiten). Zusätzlich **Wahl aus 2–3 Gegnern**: schwerer bedeutet mehr Belohnung.
- **Run-Struktur:** **8 Akte à 3 Kämpfe** (Balatro-Antes-Prinzip: klein → groß → Boss), insgesamt 24 Kämpfe.
- **Teamgröße:** Start mit **3 Plätzen**, wachsend bis **6** (kaufbar oder als Belohnung).
- **Kampfende:** Zuglimit + Verderben. Ab Zug X (Vorschlag: 20) nehmen alle Figuren pro Zug wachsenden Schaden („Die Dunkelheit frisst“).

### Pacing-Rechnung (zu prüfen im Prototyp)
- 30–45 Min. ÷ 24 Kämpfe ≈ **75–110 Sek. pro Zyklus** (Gegnerwahl + Planung + Kampf + Belohnung).
- Folge: Ein Kampf sollte bei 1× Tempo **~20–40 Sek.** dauern. Die Animationen müssen knackig sein.
- „Wahl aus 2–3 Gegnern“ verdreifacht grob den Bedarf an Gegner-Teams pro Akt (→ Phase 3/7).

## Phase 3 – Welt und prozedurale Generierung
*Im Auto-Battler ist die „Welt“ die Abfolge der Begegnungen, keine Dungeon-Karte.*

### Runde 1 (beantwortet)
- **Gegner-Generierung:** **Prozedural nach Budget.** Jeder Kampf hat ein Stärke-Budget, und der Generator kauft dafür Gegner-Figuren aus dem Pool des Gebiets und gibt ihnen thematische Synergien. **Bosse sind handgemacht.**
- **Gebiete:** **4 Gebiete à 2 Akte** (Beispiele: Friedhof → Kathedrale → Hexenwald → Abgrund, die Namen sind noch offen). Für den Vertical Slice reicht zunächst ein Gebiet.
- **Zwischen den Kämpfen:**
  - **Okkulte Ereignisse/Pakte:** Text-Ereignisse mit Wahl und Risiko-Tausch, z. B. „Opfere eine Figur für einen mächtigen Pakt“
  - **Gegner überspringen** (Balatro-Blinds-Prinzip): Den Kampf auslassen und eine kleine Belohnung erhalten, aber auf Gold und Erfahrung verzichten
- **Seeds:** Jeder Run hat intern einen Seed (für Reproduzierbarkeit und Bug-Reports). Seed eingeben und teilen kommt später, Daily-Challenge evtl. noch später.

### Runde 2 (beantwortet)
- **Bosse:** **Regel-Bosse** wie die Boss-Blinds in Balatro. Jeder Boss ändert eine Regel (z. B. „Die vorderste Figur ist geblendet“, „Heilung wirkt umgekehrt“). Pro Akt zufällig aus einem Pool, in der Vorschau sichtbar.
- **Ereignisse:** Nach jedem Kampf mit **~30 % Chance**.
- **Überspringen:** **Alles außer dem Endboss** lässt sich überspringen.
  - Normale Kämpfe: kleine Belohnung („Marke“), dafür kein Gold und keine Erfahrung
  - Akt-Bosse: nur gegen einen **hohen Preis** (z. B. Opfer einer Figur). Genaue Kosten → Phase 8/10
- **Gebiete = die 4 Tarot-Farben**, jede mit eigener Mechanik:
  - **Stäbe** (Feuer), **Kelche** (Wasser), **Schwerter** (Luft), **Münzen** (Erde)
  - Reihenfolge und Mechaniken pro Farbe → Phase 7/9

### Bestätigt in Phase 4.1
- **Endboss (Akt 8) aus den Großen Arkana** (z. B. Der Tod, Der Teufel, Der Turm). Besonders stark, wechselt pro Run.
- **Pity-Timer für Ereignisse:** Nach 4 Kämpfen ohne Ereignis kommt garantiert eines.

## Phase 4 – Sicht, Erkundung und Information
*Sichtfeld und Nebel des Krieges entfallen (Auto-Battler). Es geht um den Informationsgrad.*

### Runde 1 (beantwortet)
- **Werte:** Alles **exakt**. Angriff, Leben und alle Effekttexte mit genauen Zahlen, keine versteckten Effekte.
- **Kampfprognose:** **Keine.** Selbst einzuschätzen, ob das Team gewinnt, ist die Kern-Herausforderung. Die volle Gegner-Vorschau gleicht das aus.
- **Nach dem Kampf:** **Schaden-Statistik** (Schaden und Heilung pro Figur). Kein Kampf-Log und kein Replay gewählt.

## Phase 5 – Spielercharakter
*Der Spieler ist der **Okkultist**, der das Team führt. Er kämpft nicht selbst und hat keine eigenen HP (eine Niederlage beendet den Run).*

### Runde 1 (beantwortet)
- **Startwahl:** **Okkultisten-Wahl.** Mehrere Okkultisten mit eigener Grundregel und 1–2 Startfiguren (Balatro-Deck-Prinzip). Neue werden per Meta-Progression freigeschaltet.
- **Ressourcen:** **Gold + Seelen.**
  - Gold: Shop-Währung
  - Seelen: seltene zweite Währung für Pakte und Ereignisse. Quellen und Verwendung → Runde 2
- **Leveln:** **Beides.** Duplikate verschmelzen geben viel Erfahrung, Kämpfe geben wenig.
- **Kombinieren:** **Fusion zu neuer Figur.** Zwei verschiedene Figuren verschmelzen zu einer neuen, stärkeren (z. B. Ritter + Geist = Todesritter).
  - Synergie-Gruppen (Traits) und Positions-Kombos wurden **nicht** ausdrücklich gewählt. Positions-Effekte bleiben über die Reihen-Aufstellung trotzdem möglich (→ Phase 6).

### ⚠️ Umfangs-Hinweis Fusion
Bei *n* Figuren gibt es bis zu n·(n−1)/2 Paare (20 Figuren → 190 Paare). Handgemachte Ergebnisse für alle Paare sind unrealistisch. Die Fusionsregel wird in Runde 2 entschieden.

### Runde 2 (beantwortet)
- **Figuren-Werte:** Nur **Angriff + Leben** (Super-Auto-Pets-Prinzip). Alles Weitere, z. B. Rüstung, kommt über Fähigkeiten.
- **Fusionsregel:** **Erbt beide Fähigkeiten.** Die Fusion behält beide Fähigkeiten und addiert die Werte mit Bonus. Name und Bild entstehen aus Bausteinen („Feuer-“ + „Ritter“).
  - Jedes Paar funktioniert ohne Handarbeit → kein Umfangsproblem
  - Bild: Für KI-Grafik ist eine Kombination aus Rahmen/Farbe und Kernfigur nötig (→ Phase 12)
- **Seelen-Quellen:** Figuren opfern, Akt-Bosse besiegen, Ereignisse, sterbende Figuren im Kampf (kleine Chance)
- **Okkultisten im Vertical Slice:** 2

## Phase 6 – Kampfsystem
_Noch nicht behandelt._

## Phase 7 – Monster und KI
_Noch nicht behandelt._

## Phase 8 – Items, Inventar und Loot
_Noch nicht behandelt._

## Phase 9 – Fähigkeiten, Magie und Spezialsysteme
_Noch nicht behandelt._

## Phase 10 – Progression, Schwierigkeit und Meta
_Noch nicht behandelt._

## Phase 11 – Benutzeroberfläche und Bedienung
_Noch nicht behandelt._

## Phase 12 – Präsentation: Grafik, Audio, Atmosphäre
_Noch nicht behandelt._

## Phase 13 – Speichern, Daten und Persistenz
_Noch nicht behandelt._

## Phase 14 – Architektur und Code-Struktur
_Noch nicht behandelt._

## Phase 15 – Umsetzungsplan und Meilensteine
_Noch nicht behandelt._

---

## Offene Fragen
- Phase 5, Runde 3: Heilung/Tod nach Kampf, Fusionsgrenzen und -kosten, Seelen-Verwendung, Level-Zahlen

## Später entscheiden
- **Seed-Eingabe/Teilen und Daily-Challenge** → nach dem Vertical Slice
- **Art der Synergie-Objekte** (Karten/Joker/Pakte sind Platzhalter) → Phase 8/9

---

## Entscheidungsprotokoll

| Datum | Entscheidung | Begründung | Verworfene Alternativen |
|-------|--------------|------------|-------------------------|
| 2026-11-16 | Projekt gestartet, Design-Dokument angelegt | Strukturierter Frageprozess vor dem ersten Code | – |
| 2026-11-16 | Action-Roguelite mit Balatro-artigem Synergie-System, Roguelite-Meta, Zielgefühl Knappheit + Power-Fantasy | Wunsch nach Hades/Isaac-Feeling plus Kombinier-Tiefe à la Balatro | Klassisches Roguelike, Roguelike mit leichten Freischaltungen |
| 2026-11-16 | Dark-Fantasy/Okkult, Runs 30–45 Min., Kurve knapp → explosiv, Synergien als Kern, Kampftempo vertagt | Synergie- und Build-Tiefe hat Vorrang vor Reflex-Action | Sci-Fi, Postapokalypse, Mythologie; getrennte Ressourcen; Risiko-Tausch |
| 2026-11-16 | Build im Run + Pool-Freischaltungen zwischen Runs; Zielgruppe Roguelite-Fans; kommerzieller Release; Einsteiger in der Programmierung | Vision Balatro/Hades-artig | Nur im Run, nur Meta; Veteranen/Einsteiger als Zielgruppe |
| 2026-11-16 | Hobby statt kommerziell (~10 Std./Woche), solo inkl. Art und Sound, Vertical Slice zuerst, Pitch vorläufig | Realistischer Umfang für einen Einsteiger | Kommerzieller Release; Lernprototyp mit Neustart; volle Durchplanung |
| 2026-11-16 | Browser + Mobile, Godot 4 + GDScript, Maus + Touch, KI-generierte Grafik | Einsteigerfreundlich, leicht teilbar, starke UI für Synergien | Desktop-only, Python, LÖVE, Unity; Gamepad |
| 2026-11-16 | Querformat, Tarot-Illustrationsstil, KI-Tool per Vergleichstest, kompaktes Spielfeld | Lesbarkeit auf Mobile, passt zu Dark Fantasy und Touch-Taktik | Hochformat, responsiv; Pixel-Art, gemalter Stil; scrollende Karte, abstrakte Szene |
| 2026-11-16 | 1280×720, KI-Test nach der Planung, Claude committet, Claude baut und Nutzer testet | Nutzer will testen statt programmieren lernen | 1080p, 360p; sofortiger KI-Test; Lernen am Projekt |
| 2026-11-16 | Auto-Battler mit Team aus levelbaren, kombinierbaren Figuren; Loop Kampf → Belohnung → Shop → Boss | Synergien und Build sind der Kern, Angriffe laufen automatisch | Survivors-Echtzeit, Züge mit freier Position, Raster mit Auto-Angriff; Einzelheld |
| 2026-11-16 | Eine Reihe, Schritt-für-Schritt-Kampf, eine Niederlage = Tod, Akte mit Bossen | Lesbarkeit, Synergien nachvollziehbar, maximaler Druck | Zwei Reihen, freies Feld; Echtzeit-Simulation; Leben-System, übertragene HP |
| 2026-11-16 | Volle Vorschau + Wahl aus 2–3 Gegnern, 8 Akte à 3 Kämpfe, 3→6 Plätze, Zuglimit mit Verderben | Fairness trotz Permadeath, Balatro-Rhythmus, Kurve knapp → explosiv | Nur Boss-Vorschau, Leben-System; 3×5, 4×4; feste Teamgröße; Unentschieden = Niederlage/weiter |
| 2026-11-16 | Gegner prozedural nach Budget, Bosse handgemacht, 4 Gebiete à 2 Akte, Ereignisse/Pakte, Überspringen, interner Seed | Viel Abwechslung bei wenig Handarbeit, Risiko-Tausch passt zum Thema | Handgebaute Teams, Vorlagen; 8 Gebiete, ein Thema; Daily von Anfang an |
| 2026-11-16 | Regel-Bosse, Ereignisse mit ~30 % Chance, Überspringen bis auf den Endboss, Gebiete = 4 Tarot-Farben | Build-Anpassung erzwingen, Risiko-Tausch, Tarot-Thema durchziehen | Boss-Figuren, Kombination; 1× pro Akt, als Option; nur Kampf 1+2 überspringbar; klassischer Abstieg |
| 2026-11-16 | Exakte Werte, keine Prognose, Schaden-Statistik; Endboss aus den Großen Arkana; Pity-Timer nach 4 Kämpfen | Fairness durch Transparenz, Einschätzen als Skill | Versteckte Effekte; grobe/genaue Prognose; Kampf-Log, Replay |
| 2026-11-16 | Okkultisten-Wahl, Gold + Seelen, Leveln durch Verschmelzen + Kampf-Erfahrung, Fusion zu neuen Figuren | Build-Vielfalt ab Start, Pakt-Thema, Kombinieren als Kernfantasie | Fester/zufälliger Start; Zinsen, nur Gold; Traits, Positions-Kombos als Hauptsystem |
| 2026-11-16 | Angriff + Leben, Fusion erbt beide Fähigkeiten, Seelen aus 4 Quellen, 2 Okkultisten im Slice | Lesbarkeit auf Mobile, Fusion ohne Content-Explosion | Tempo/Rüstung als Grundwert; Farbe×Klasse-Tabelle, feste Rezepte |

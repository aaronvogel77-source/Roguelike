# GAME_DESIGN.md – Roguelike (Arbeitstitel offen)

> Einzige Quelle der Wahrheit für alle Designentscheidungen.
> Wird nach jeder beantworteten Fragerunde aktualisiert.

**Status:** Umsetzung – M0–M6 abgeschlossen, Kampfbühne Schritt 1 abgeschlossen. Schritt 2 (eigenes Design je Figur, Fähigkeits-Effekte, Spezialangriff-Szene) gebaut (v0.9.0), Feedback-Runden v0.9.1–v0.9.2 umgesetzt; Fusionsgestalten + reine Meister (v0.10.0) gebaut; M7 Meta/Lager/Grimoire (v0.11.0) gebaut, wartet auf Feedback.
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

### Runde 3 (beantwortet)
- **Nach dem Kampf:** Alle Figuren werden **voll wiederhergestellt**, auch die gefallenen. Die Knappheit entsteht über Gold und Seelen.
- **Fusion (Nutzer-Antwort wörtlich):** „Maximal 3 Fusionen zur besten Fusionsstufe und zu bestimmten besonderen und seltenen Anlässen, die auch geheim freischaltbar sind.“ → präzisiert in Runde 4
- **Seelen-Verwendung:** Fusionen, Pakte, seltene Shop-Angebote
  - Akt-Boss überspringen kostet damit **keine** Seelen. Preis bleibt das **Opfern einer Figur** (Phase 3).
- **Stufen:** 3 Stufen. Stufe 2 bei 3 Erfahrung, Stufe 3 bei 6. Duplikat = +1 Erfahrung, Kampfsieg = +⅓ Erfahrung. Jede Stufe gibt **+1/+1** und verstärkt die Fähigkeit (z. B. +2 → +4 → +6).

### Runde 4 – Fusionssystem (beantwortet)
- **Fusionsstufen pro Figur:** F1 (2 Figuren) → F2 (F1 + Figur) → **F3 = beste Stufe** (4 Figuren in einer). Fusionsstufe und Level-Stufe (1–3) sind getrennte Systeme.
- **Fähigkeiten:** Bei jeder Fusion wählt der Spieler, welche Fähigkeiten bleiben (**max. 3**). Auf **F3** kommt eine besondere **Meisterfähigkeit** dazu.
- **Anlässe (selten):**
  - **Fusions-Altar** (okkultes Ereignis, Kosten in Seelen)
  - **Nach jedem besiegten Akt-Boss**
  - **Besondere Gegenstände** (z. B. „Ritualkerze“, einmalig, aus Shop oder Ereignis)
- **Geheimnisse:**
  - **Geheime Rezepte:** Bestimmte Paare ergeben eine legendäre, handgemachte Figur statt einer normalen Fusion
  - **Geheime Anlässe:** Versteckte seltene Ereignisse (z. B. „Blutmond“) mit besonderen Fusionen
  - **Meta-Freischaltung:** Neue Fusionsmöglichkeiten werden dauerhaft durch Erfolge freigeschaltet (z. B. F3 erst nach dem ersten Sieg)
  - Verträglich mit Phase 4 („alles exakt“): Verborgen ist nur, *wie* man etwas freischaltet. Sobald eine Fusion sichtbar ist, sind ihre Werte exakt.

### M6 – Fusion, Runde 1 (beantwortet 2026-11-17)
- **Werte:** Bewusst **nicht zu stark**, es soll Luft nach oben bleiben → konkrete Formel in Runde 2
- **Stufe:** Eine Fusion startet wieder auf **Stufe 1**
- **Farbe:** Eine Fusion zählt für **alle enthaltenen Farben** (Gebiets-Segen, Farb-Relikte)
- **Umfang:** **Alles in M6**, inklusive geheimer Rezepte und geheimer Anlässe

### M6 – Fusion, Runde 2 (beantwortet 2026-11-17)
- **Werte:** Von Angriff und Leben jeweils der **höhere Wert + 1/1** (Beispiel: 2/2 + 4/3 → 5/4)
- **Leveln nach Neustart:** Nur über **Kampfsiege und den Magier**, keine Duplikate mehr
- **Fusions-Altar:** kostet **F1 2 · F2 3 · F3 4 Seelen**
- **Ritualkerze:** seltene Karte in **Arcana-Packs (ca. 5 % pro Karte)**, manchmal auch im Schwarzmarkt-Mantel

### M6 – Fusion, Runde 3 (beantwortet 2026-11-17)
- **Geheime Rezepte:** **2** im Münzen-Slice (Inhalt folgt)
- **Blutmond** (geheimer Anlass, sehr seltenes Ereignis ca. 3 %): **Doppelte Fusion**, zwei Fusionsschritte auf einmal (z. B. direkt F1 → F3)
- **Meisterfähigkeiten:**
  - Münzen + Münzen – **Goldene Mauer:** Kampfbeginn: alle Verbündeten erhalten Schild 1 pro 5 Gold im Besitz (max. 5)
  - Stäbe + Stäbe – **Feuerspringen:** Stirbt ein brennender Gegner, springt sein Brennen **doppelt** auf den nächsten Gegner über (stärkere Form des Aschepakts)
  - Kelche + Kelche – **Tränenmeer:** Der erste gefallene Verbündete pro Kampf kehrt mit vollem Leben zurück
  - Schwerter + Schwerter – **Durchbohren:** Angriffe durchdringen Schild und verursachen Blutung 2
  - Münzen + Stäbe – **Goldglut:** Kampfbeginn: alle Gegner erhalten Brennen 1 pro 10 Gold im Besitz (max. 3)
  - Münzen + Kelche – **Überfluss:** Heilung über das volle Leben hinaus wird zu Schild
  - Münzen + Schwerter – **Bezahlte Klinge:** +1 Angriff pro 5 Gold im Besitz (max. +5)
  - Stäbe + Kelche – **Dampfwolke:** Kampfbeginn: alle Gegner erhalten Fluch 1 und Brennen 1
  - Stäbe + Schwerter – **Glühhieb:** ×1,5 Angriff gegen brennende Gegner
  - Kelche + Schwerter – **Aderlass:** Der Träger heilt sich um den Blutungs-Schaden, den Gegner erleiden

### M6 – Fusion, Runde 6 (beantwortet 2026-11-17)
- **Geheimes Rezept 1 – Waage des Midas:** König Midas + Goldene Waage → 6/9. Kampfbeginn: Angriff aller Verbündeten ×1,2, dazu ×0,1 pro 10 Gold
- **Geheimes Rezept 2 – König aus Asche und Flut:** Aschekönig + Ertrunkener König → 8/11. Stirbt ein Verbündeter: alle Gegner Brennen 2, der Träger nimmt 50 % von dessen Werten auf
- Rezept-Figuren sind **endgültig** (keine weitere Fusion), dafür etwas stärker (+1/+1 gegenüber dem Vorschlag)
- **Hinweis:** Wählt man am Altar ein Rezept-Paar, leuchtet die Vorschau als „???“. Was entsteht, zeigt sich erst nach der Fusion

### Fusionsgestalten + reine Meister (beantwortet 2026-11-17, freigegeben und umgesetzt in v0.10.0)
- **Teile:** Rumpf, Kopf, Haut, Robe und Umhang kommen von der **Hauptfigur**; Waffe, Schild und Extras (z. B. Kelch, Fackel, Geldbeutel) vom **Partner**. Bei F2/F3 steuern das 3. und 4. Teil weitere Stücke bei (z. B. Umhang bzw. Schild oder Extra)
- **Stufe:** Mit jeder Stufe etwas **größer** und mit stärkerer **Aura** in den Hauptfarben; Schimmer nur bei F3 und Rezepten (wie vereinbart)
- **Farben:** Jedes übernommene Teil **behält seine Originalfarben**; zweifarbige Aura aus den zwei Hauptfarben
- **Reine Fusion** (3+ Figuren derselben Farbe auf F3): leuchtendes **Farbsymbol über dem Kopf** (Münze, Flamme, Kelch, Klinge) und eine **eigene, stärkere Meisterfähigkeit**, die die bisherige reine ersetzt:
  - Münzen – **Goldene Festung:** Kampfbeginn: alle Verbündeten Schild 1 pro 5 Gold (max. 8). Nach dem Kampf +1 Gold pro übrig gebliebenem Schild (max. 3)
  - Stäbe – **Glutkern:** Brennen-Schaden an Gegnern ×2, jedes Brennen-Ticken bei Gegnern heilt diese Figur um 1
  - Kelche – **Ewige Quelle:** Die ersten zwei gefallenen Verbündeten kehren mit vollem Leben zurück, der zweite mit +2/+2
  - Schwerter – **Hinrichtung:** Angriffe durchdringen Schild und verursachen Blutung 3; Gegner unter 30 % Leben sterben sofort
  - Die bisherigen reinen Meister (Goldene Mauer, Feuerspringen, Tränenmeer, Durchbohren) entfallen damit, weil eine F3 mit gleicher Hauptfarbe immer rein ist. Sie bleiben als Ideen für Relikte/Rezepte vorgemerkt

### M6 – Umsetzungsplan (freigegeben und umgesetzt in v0.7.0)
- **Ablauf einer Fusion:** Hauptfigur + Partner aus der Reihe wählen. Die Fusion steht auf dem Platz der Hauptfigur, der Partnerplatz wird frei. Vorschau mit Werten, Fähigkeiten und Kosten, dann eine Bestätigung (unumkehrbar)
- **Fusionsstufe** = Anzahl enthaltener Figuren − 1 (F1 = 2, F2 = 3, F3 = 4). Zwei F1 ergeben direkt F3. Mehr als 4 Figuren geht nicht. Legenden können fusioniert werden
- **Fähigkeiten:** Sind es zusammen mehr als **2**, wählt man 2 aus (nach Feedback von 3 gesenkt). Die Meisterfähigkeit auf F3 kommt zusätzlich dazu
- **Werte:** höherer Angriff und höheres Leben der beiden (ohne Stufenbonus) + 1/1. Start auf Stufe 1, Leveln nur über Kampfsiege und Magier
- **Name (nach Feedback):** Beide Namen verbunden – erster Teil vom (zuletzt fusionierten) Partner, zweiter Teil von der Hauptfigur, z. B. Henker + Bluttrinker → „Blut-Henker“, Funkenträger + König Midas → „Midas-Träger“. Die Karte zeigt die F-Stufe als Abzeichen und leuchtet, F3 in allen enthaltenen Farben
- **Objekte:** Die Hauptfigur behält ihre Ausrüstung und Segen. Die Objekte des Partners gehen verloren (Warnhinweis in der Vorschau)
- **Verkaufswert:** Summe der Verkaufswerte der enthaltenen Figuren
- **Anlässe:**
  - **Fusions-Altar** als neues Ereignis (Kosten nach Zielstufe 2/3/4 Seelen)
  - **Nach jedem Akt-Boss** eine Gratis-Fusion (überspringbar)
  - **Ritualkerze:** Tarot-artige Karte, ca. 5 % pro Arcana-Karte, manchmal im Schwarzmarkt-Mantel
  - **Blutmond:** geheimes Ereignis, ca. 3 % statt eines normalen Ereignisses, gratis doppelte Fusion
- **Meta-Freischaltung** („F3 erst nach dem ersten Sieg“) braucht das Meta-System aus M7 und wird dort angebunden
- **Debug:** Knopf „Fusion“ (Blutmond mit aufgefüllter Reihe inkl. Rezept-Paar); der Altar ist im Ereignis-Durchlauf
- **Bei der Umsetzung festgelegt:** Eine Farbe, die 3- oder 4-mal enthalten ist, zählt als „rein“ (sonst wäre z. B. Münzen + Münzen nur mit 4 gleichen Farben möglich). **Überfluss** wirkt für das ganze Team des Trägers. Fusionen können nicht per Spiegelkammer kopiert und nicht mit Duplikaten verschmolzen werden.

### Figuren & Kampfbühne (Planung 2026-11-17, ersetzt den Kartenkampf und die bisherige M8-Grafikplanung)
Die fünf Designrichtungen (docs/designrichtungen.html) haben nicht gepasst. Gewünscht sind **echte, detaillierte Figuren, die sichtbar gegeneinander kämpfen**.
- **Kamera:** Seitenansicht, eigene Figuren links, Gegner rechts
- **Stil:** Detaillierte **Pixelkunst**, Figurenhöhe **64 Pixel**. Farbstimmung düster, Effekte (Feuer, Gold, Magie) leuchten hell heraus
- **Animation:** Gliederpuppen-Technik (Figur aus Teilen: Kopf, Rumpf, Arme, Waffe, Umhang), Drehungen in groben Stufen, damit Pixel scharf bleiben
- **Bilder-Quelle:** Claude zeichnet alle Figuren zunächst selbst Pixel für Pixel im Code (feste Palette); einzelne Figuren können später durch KI- oder Künstlerbilder ersetzt werden
- **Karten:** Im Shop und in der Planung bleiben Tarot-Karten (mit der Figur als Bild). Im Kampf kämpfen die Figuren auf dem Schlachtfeld
- **Werte im Kampf (nach Feedback):** Angriff (rot) und Leben (grün) als Zahlen unter jeder Figur, dazu ein dünner Lebensbalken; Brennen, Blutung, Fluch und Schild als kleine Symbole mit Stapelzahl über dem Kopf; Details per Antippen
- **Hintergrund:** Pixel-Landschaft mit mehreren Ebenen je Gebiet (Münzen: verfallene Schatzkammer, Goldberge, Kerzen, Staub)
- **Bewegung:** Je nach Waffe – Nahkämpfer laufen zur Mitte und schlagen zu, Fernkämpfer schießen von ihrem Platz. Nur Darstellung: Die Regel „vorderste gegen vorderste“ bleibt
- **Tod:** Je nach Farbe – Münzen zerspringen zu Gold, Stäbe verbrennen, Kelche zerfließen, Schwerter zerbrechen
- **Vielfalt:** Nach Rang gestaffelt – 4 Körper (Bube, Ritter, Königin, König), je Farbe eigene Kleidung und Waffe; Asse und Rezept-Figuren als Sondergestalten
- **Fusion:** Eigene Fusionsgestalt je Farbkombination, aber Teile der enthaltenen Figuren (Waffe, Kopfbedeckung, Umhang) bleiben erkennbar
- **Gegner (überarbeitet):** Eigene Kreaturen, die den Hofkarten nicht ähneln: Bettlergeist (Geist mit Kette), Schuldeneintreiber (buckliger Kobold mit Zylinder und Schuldbuch), Münzwerfer (kleiner Kobold mit Münzsack), Wechsler (schwebende Maske halb Gold halb Schwarz), Gierschlund (Truhen-Mimic), Tresorwächter (Steingolem mit Tresortür), Gieriger Drache, Spiegelmünze (fliegende Münze mit Gesicht); Bosse: Steuereintreiber (Krötenkönig auf Münzsack), Goldene Mauer (lebende Goldmauer)
- **Effekte:** Geschosse und Partikel, Treffer-Wucht (kurzes Einfrieren, Wackeln, Zurückstoßen, Schadenszahlen), Spezialangriff-Szene (Zoom, Porträt, Fähigkeitsname) bei Königen, Legenden, Bossen und Meisterfähigkeiten, Status sichtbar an der Figur (Brennen brennt, Blutung tropft, Fluch als violetter Schleier, Schild als Lichtschale)
- **Tempo:** ×1 / ×2 / ×3 und Überspringen, Einstellung bleibt gespeichert

### Figuren-Stil: Prunk & Reliquie (gewählt 2026-11-17)
- **Material nach Rang:** Bube Eisen, Ritter Stahl, Königin Silber, König Gold, Ass Gold mit Edelsteinen. **Fusion obendrauf:** Vergoldung und Steine je Stufe, F3 leichtes Leuchten. **Schillernd (polychrom) nur bei geheimen Rezept-Figuren** – der Glanz erreicht erst mit Fusion und Rezepten seinen Höhepunkt
- **Funkeln:** Nur F3-Fusionen (leicht) und Rezept-Figuren (deutlich); normale Figuren funkeln nicht
- **Kleidung:** Verzierte Rüstungen und Gewänder mit Filigran; ein Edelstein auf der Brust in der Tarot-Farbe
- **Rang:** zusätzlich über Umhang (Bube keiner bis König bodenlanger Hermelin) und Kronenhöhe
- **Ausrüstung & Segen im Aussehen:** Nur besondere Gegenstände (selten, verflucht, einzigartig) und später besonders starke Segen verändern das Aussehen

### Eigenes Design je Figur und Monster (Feedback 2026-11-17, umzusetzen in Kampfbühne Schritt 2)
- Jede Figur, jedes Monster und jeder Boss bekommt ein **ganz eigenes Design passend zu Name und Fähigkeit**, in den Farben ihrer Tarot-Farbe und mit dem Material ihres Rangs
- Beispiele des Spielers:
  - **Goldgepanzerter:** goldene Rüstung, die **dicker oder dünner wird, je mehr oder weniger Gold** man besitzt (passend zu „Schild pro Gold“)
  - **Henker:** Henkersaxt und schwarze Henkerskappe
  - **König Midas:** goldene Hand und Krone
- Gilt ebenso für Asse, Rezept-Figuren und Fusionsgestalten

### Shop: Tarot-Legung (gewählt 2026-11-17)
- Shop- und Planungsbildschirm im Stil **Tarot-Legung** (docs/shopvorlagen.html, Vorlage 2): Karten auf dunklem Samt, dein Team als Kartenreihe, Angebote als Legung, Packs als verdeckte Karten, Preise als Goldmünzen, Knöpfe als Wachssiegel (Neu würfeln gold, Rückgängig grau, Kampf groß und rot)
- **Verkaufsfeld nur bei Bedarf (wie Balatro):** Es erscheint erst, wenn man eine Figur oder Karte gedrückt hält bzw. zieht oder antippt – **unten rechts über den Siegeln**, nie in der Mitte, wo man Figuren ablegt (sonst verkauft man sie aus Versehen)

## Phase 6 – Kampfsystem

### Runde 1 (beantwortet)
- **Angriffsablauf:** **Vorderste gegen vorderste.** Pro Zug schlagen die beiden vordersten Figuren gleichzeitig zu. Wer stirbt, macht Platz für die nächste (Super-Auto-Pets-Prinzip).
- **Zufall:** Grundsätzlich **kein Zufall** bei Treffern und Schaden. Zufall gibt es nur über:
  - besondere **Fähigkeiten**, die den Angreifer mit **Multiplikatoren oder Boni** begünstigen
  - **negative Effekte** als Ausgleich für starke Gegenstände oder Angriffe (Risiko-Tausch)
  - **Gegenstände:** gleicher Grundtyp, aber je nach **Seltenheit zufällig in Stärke und Spezialeffekten ausgewürfelt** (Affix-Prinzip, → Phase 8)
- **Statuseffekte:** Je Tarot-Farbe einer, also 4 insgesamt: Stäbe = **Brennen**, Kelche = **Fluch**, Schwerter = **Blutung**, Münzen = **Schild**. Genaue Regeln → Runde 2
- **Auslöser (alle vier):**
  - Kampfbeginn / Zugbeginn
  - Bei Angriff / Treffer
  - Bei Tod (eigene oder fremde Figur)
  - Im Shop (Kauf / Verkauf / Level-Up)

### Runde 2 (beantwortet)
- **Schadensformel:** `Schaden = (Angriff + Summe additiver Boni) × Produkt aller Multiplikatoren` (Balatro-Prinzip Chips × Mult)
  - Erst werden alle `+X` addiert, dann alle `×Y` multipliziert, das Ergebnis wird abgerundet. Fluch und andere Mali wirken auf der additiven Ebene.
- **Auslösereihenfolge:** Von vorne nach hinten. Bei gleichzeitigen Auslösern zuerst alle Spieler-Figuren, dann die Gegner.
- **Statusregeln:** Werden im Prototyp festgelegt. Startpunkt-Vorschlag:
  - Brennen: X Schaden zu Zugbeginn, danach −1 Stapel
  - Fluch: −X Angriff, verfliegt nach 3 Zügen
  - Blutung: ~~Jeder Treffer gegen die Figur macht +X Schaden~~ → **geändert nach M2-Feedback:** Zugbeginn X Schaden an der blutenden Figur, egal wo sie steht, Stapel bleiben (kein Abbau)
  - Schild: Blockt die nächsten X Schaden
- **Gleichstand** (beide Teams fallen gleichzeitig): **zählt als Sieg**
  - ⚠️ Risiko: Selbstzerstörungs-Builds könnten gezielt auf ein Unentschieden spielen. Im Prototyp beobachten, ggf. später nachjustieren (z. B. Sieg ohne Gold).

### Präzisierungen M2 (vom Nutzer bestätigt)
- **Ablauf pro Zug:** Brennen tickt → Zugbeginn-Fähigkeiten → Zusammenstoß → „Wenn getroffen“ (getroffene Figuren) → „Nach dem Angriff“ (Angreifer) → Fluch-Countdown → Dunkelheit (ab Zug 15)
- **„Nach dem Angriff“** löst *nach* dem Treffer aus (Bluttrinker kennt so den verursachten Schaden, der Henker den Restwert)
- **„Wenn getroffen“** zählt auch Treffer, die ein Schild komplett abfängt
- **Schild** blockt jeden Schaden außer der Dunkelheit
- **Klare Klinge** löst zu Kampfbeginn *zuletzt* aus (nach den Gegner-Schilden), sonst wäre sie gegen Tresorwächter wirkungslos. Pro entferntem Schildpunkt Blutung 1/2/3.
- **Tod und Wiederkehr:** Eine sterbende Figur löst erst alle Tod-Fähigkeiten aus (Waage, Ertrunkener König, Drache), dann holt der Kelch sie zurück. So füttert sie den König zweimal.
- **Stufen:** jede Stufe über 1 = +1/+1 auf die Grundwerte, Fähigkeitswerte laut Tabelle (Stufe 1/2/3)

### Runde 3 (beantwortet)
- **Zielwahl:** Der normale Angriff trifft immer die vorderste gegnerische Figur. **Andere Ziele nur über Fähigkeiten** (z. B. hinterste oder schwächste Figur). Die hinteren Plätze werden zur Unterstützer- und Sniper-Zone.
- **Verderben:** Zahlen werden im Prototyp festgelegt. Startpunkt: ab Zug 15, verdoppelnder Schaden (1, 2, 4, 8 …) an alle.
- **Zugtempo:** ~1 Sekunde pro Zug bei 1× (Kampf mit 15–25 Zügen ≈ 15–30 Sek.), dazu 2× und 4×.
- **Todesbildschirm:** Letztes eigenes Team + siegreiches Gegner-Team, Run-Statistiken (Akt, Kämpfe, höchster Treffer, Fusionen, Gold/Seelen), verdienter Meta-Fortschritt, Seed.

## Phase 7 – Monster und KI
*Klassische Monster-KI entfällt (Auto-Battler). Es geht um Figuren, Gegner und den Gegner-Generator.*

### Runde 1 (beantwortet)
- **Gegner:** **Eigene Monster je Gebiet** (je Tarot-Farbe eigene Gegner-Figuren mit passenden Effekten). Im Slice ca. 8–10 Gegner-Figuren für ein Gebiet.
- **Spieler-Figuren = Tarot-Hofkarten:**
  - Jede Figur hat eine **Farbe** (Stäbe / Kelche / Schwerter / Münzen) und einen **Rang = Seltenheit**
  - Bube = häufig · Ritter = ungewöhnlich · Königin = selten · König = episch
  - Mehrere Figuren pro Farbe und Rang möglich
  - Große Arkana sind für Endbosse reserviert (Phase 3), evtl. auch für legendäre Fusionen aus geheimen Rezepten
- **Slice-Umfang:** **16 Spieler-Figuren** (4 pro Farbe)
- **Gegner-Generator:** **Thematische Synergien.** Er wählt im Stärke-Budget Figuren, die untereinander synergieren und zum Gebiet passen. Er reagiert nicht auf den Build des Spielers.

### Runde 2 (beantwortet)
- **Slice-Run:** **1 Gebiet = 2 Akte** (6 Kämpfe inkl. 2 Regel-Bossen, ca. 8–12 Min.), danach optional ein Endlos-Modus zum Stärketest
- **Erstes Gebiet:** **Münzen (Erde)**. Status Schild, Thema Gold und Wirtschaft, testet die Shop-Auslöser.
- **Gebiets-Reihenfolge (volles Spiel):** **Zufällig pro Run.** Die Gegner-Stärke skaliert über das Budget, nicht über das Gebiet. Jedes Gebiet braucht damit Gegner für alle Stärkestufen.
- **Figurenliste:** **Gemeinsam Figur für Figur** in eigenen Inhaltsrunden pro Farbe. Zeitpunkt: nach Phase 9, wenn Items, Pakte und Meisterfähigkeiten feststehen.

## Phase 8 – Items, Inventar und Loot

### Runde 1 (beantwortet)
- **Objekt-Kategorien** (ersetzen die Platzhalter „Karten, Joker, Pakte“):
  1. **Relikte:** passive Effekte, Joker-artig
  2. **Ausrüstung an Figuren:** zufällig ausgewürfelt je nach Seltenheit
  3. **Tarot-Karten:** Verbrauchsgegenstände mit Einmal-Effekt (z. B. „Segen“)
  4. **Pakte:** dauerhafte Run-Effekte mit Stärke und Nachteil, bezahlt mit Seelen
- **Seltenheit (Ausrüstung):** 4 Stufen
  - Gewöhnlich: Grundwert
  - Magisch: +1 Effekt
  - Selten: +2 Effekte
  - Verflucht/Legendär: +3 starke Effekte, aber **1 Nachteil**
- **Slots pro Figur (Nutzer-Antwort):** „1 Slot pro Figur und max. 1 wirkendes Relikt oder Verbrauchsgegenstand wie Segen o. Ä.“
  - Jede Figur hat also **1 Ausrüstungs-Slot + 1 Segen-Slot** (Relikt *oder* Verbrauchseffekt). Globale Slots → Runde 2
- **Reserve:** **Keine.** Nur Figuren in der Kampfreihe zählen.
  - Konsequenz: Fusionspartner und Duplikate müssen in der Reihe stehen oder direkt beim Kauf verschmelzen. Planung ist bewusst knapp.

### Runde 2 (beantwortet)
- **Relikte:** **Beides.** Pro Figur 1 Segen-Slot, dazu **3 globale Relikt-Slots** für Joker-artige Team-Effekte.
- **Shop nach jedem Kampf:** **3 Figuren + 2 Objekte** (Ausrüstung, Relikt oder Tarot-Karte)
  - Neu würfeln: 5 Gold, +1 Gold je weiterem Neuwürfeln im selben Shop; Überspringen-Marke „Freies Würfeln“: 2× gratis im nächsten Shop; später sollen Relikte das Würfeln verbilligen
  - Seltene Angebote kosten **Seelen** statt Gold
- **Gold-Wirtschaft (Startpunkt für den Prototyp):**
  - Startgold: ~~10~~ → **8** (M3-Feedback)
  - Einkommen pro Kampf: 5 + Schwierigkeitsbonus der gewählten Gegner (0 / 2 / 4)
  - **Zinsen:** +1 Gold pro 5 gesparte Gold, max. +5 pro Runde
  - Figur kaufen: ~~3~~ → **nach Rang: Bube 3 · Ritter 4 · Königin 6 · König 8** (M4-Feedback) · Verkaufen: ~~1 (+1 pro Stufe)~~ → **halber Rangpreis (abgerundet) + 1 je Stufe über 1** · Objekte: 3–8 je nach Seltenheit
  - Übersprungene Kämpfe geben kein Gold (Phase 3)
- **Tarot-Karten:** **2 Kartenplätze**, um Karten aufzuheben. Einsatz jederzeit in der Planungsphase.

## Phase 9 – Fähigkeiten, Magie und Spezialsysteme

### Runde 1 (beantwortet)
- **Okkultist:** Nur eine **passive Grundregel** pro Okkultist, keine aktive Fähigkeit (Balatro-Deck-Prinzip).
- **Meisterfähigkeit (F3):** **Nach Farbkombination** der fusionierten Figuren.
  - Regel (bestätigt in Phase 10.1): Die **zwei häufigsten Farben** der 4 enthaltenen Figuren bestimmen die Kombination. 4 reine (z. B. Münzen + Münzen) + 6 gemischte (z. B. Stäbe + Kelche = „Dampf“) = **10 Meisterfähigkeiten**.
  - Gleichstand bei der Häufigkeit: Die Farbe der zuerst fusionierten Figur zählt.
- **Gebiets-Segen:** Im Gebiet einer Farbe erhalten Figuren derselben Farbe einen kleinen Bonus (z. B. Münz-Gebiet: Münz-Figuren +1 Schild zu Kampfbeginn).
- **Pakte:** Max. **3 gleichzeitig**.

## Phase 10 – Progression, Schwierigkeit und Meta

### Runde 1 (beantwortet)
- **Meta-Progression:** **Freischaltungen + kleine Upgrades.**
  - Hauptsächlich werden neue Okkultisten, Figuren, Relikte und Fusionsmöglichkeiten für den Pool freigeschaltet (inkl. geheimer Freischaltungen, Phase 5)
  - Dazu wenige kleine permanente Upgrades (z. B. +2 Startgold), gekauft mit übrigen Seelen
- **Schwierigkeit:** **Stufen nach Sieg** (Balatro-Stakes / Slay-the-Spire-Ascension). Jeder Sieg schaltet die nächste Stufe mit einer zusätzlichen Erschwernis frei.
- **Gegner-Skalierung:** **Exponentiell.** Startformel: `Budget(Akt) = Basis × 1,5^(Akt − 1)`, innerhalb eines Akts klein < groß < Boss. Feinschliff im Prototyp.
- **Meisterfähigkeit-Regel** aus Phase 9 bestätigt.

### Runde 2 (beantwortet)
- **Freischalten:** **Durch Herausforderungen.** Jede Freischaltung hat eine Bedingung (z. B. „Gewinne mit einer F3-Fusion“), teils geheim.
- **Score:** **Lokale Bestwerte** (höchster Treffer, weitester Endlos-Akt, schnellster Sieg usw.). Kein Server.
- **Sammelbuch („Grimoire“):** Enthält alle entdeckten Figuren, Relikte, Meisterfähigkeiten und geheimen Rezepte. Unentdecktes erscheint als „???“.
- **Save-Scumming:** **Verhindert.** Autosave nach jeder Aktion, kein manuelles Laden.

### M7 – Meta, Lager und Grimoire (beantwortet 2026-11-17, freigegeben und umgesetzt in v0.11.0)
- **Meta-Währung „Seelenglut“:** entsteht aus den **am Run-Ende übrigen Seelen** (Sieg oder Niederlage) mit **abnehmender Staffel**: die ersten 5 Seelen zählen voll, die nächsten 5 zur Hälfte, jede weitere ein Viertel, **max. 12 Seelenglut pro Run** (gegen endlose Seelen in langen/Endlos-Runs). Dilemma: Seelen im Run ausgeben oder fürs Lager sparen
- **Lager = Krypta-Gewölbe** mit Truhen (Packs), Altar (Upgrades), Bildnissen (Okkultisten) und Spiegel (Optik)
- **Themen-Truhen** (je 3 Inhalte, Preis **8**): Figuren-Truhe (Asse, Figuren-Skins), Relikt-Truhe (gesperrte Relikte, Tarot, Pakte), Ereignis-Truhe (gesperrte Ereignisse). **Duplikate** geben einen Teil des Preises als Seelenglut zurück
- **Startpool:** Kern frei (16 Hofkarten, Grundausrüstung, Grund-Relikte/-Tarot/-Pakte/-Ereignisse). **Gesperrt** bis zum Fund in einer Truhe: die 4 Asse, 4 der 8 Relikte, 2 der 6 Tarot, 4 der 8 Pakte, 3 der 9 Ereignisse. Freigeschaltete Asse erscheinen wie bisher selten in Arcana-Packs und im Shop
- **Upgrades am Altar** (Preise „mittel“: Stufen 25 / 50 / 90, alle zusammen ca. 390 Seelenglut ≈ 60 Runs): +1 Startgold (3 Stufen), erstes Neuwürfeln je Shop −1 Gold (2), Start-Seele (2), bessere Arcana-Packs im Run (2)
- **Okkultisten:** Start mit **„Der Novize“** (keine Sonderregel, zufälliger Bube, 8 Gold). **Beide Wege** zum Freischalten: Wucherer durch „Besiege den Akt-1-Boss“ **oder** für 40 Seelenglut, Fechtmeisterin durch „Gewinne einen Run“ **oder** für 80
- **Herausforderungen und Lager getrennt:** Herausforderungen schalten Großes frei (Okkultisten, später Schwierigkeitsstufen, geheime Rezepte), das Lager Pool-Inhalte, Upgrades und Optik
- **Optik im Spiegel** (direkt kaufbar): Kartenrücken, Bühnen-Hintergründe, Aura-Farben für Fusionen, besondere Figuren-Skins; Ausrüstungs-Skins vorgemerkt für später. M7 liefert das System plus eine kleine Startauswahl je Art
- **Außerdem in M7:** Hauptmenü (Fortsetzen / Neuer Run mit Okkultisten-Wahl / Lager / Grimoire / Optionen), **Autosave** nach jeder Aktion (kein manuelles Laden), **Grimoire** mit allem Entdeckten („???“ für Unentdecktes). Export-Code und Bestwerte später

### Legendäre Skins (beantwortet 2026-11-17, Plan wartet auf Freigabe)
- **Anspruch:** Skins müssen richtig besonders sein: komplett neue Teile (Helm, Krone, Rüstung, Waffe) **plus animierte Effekte**
- **Seltenheitsstufen:** Selten (neue Teile/Farben), Episch (+ leuchtende Teile), **Legendär** (+ animierte Effekte, eigener Spezialangriff); höher = teurer und seltener in Truhen
- **4 Themen-Linien**, zuerst je **ein Vorzeige-Skin** (alle legendär, je **250 Seelenglut**, in der Figuren-Truhe sehr selten: 1 % pro Karte):
  - Höllenfeuer – **Höllenhenker:** Stachelhelm mit glühenden Zacken, brennende Axt, Lava-Risse, Funkenregen beim Hieb
  - Frost & Geister – **Frostkönig** (Ertrunkener König): Eiszacken-Krone, gefrorener Dreizack, Eisatem, Schneeflocken
  - Leere & Sterne – **Sternenrichter** (Richter): schwarze Robe voller Sterne, schwebende Runen, violett glühender Zweihänder
  - Gold & Heiligenschein – **Sonnenkönig Midas:** Strahlenkrone, Lichtflügel, polierte Prunkrüstung, goldene Funken
- **Legendär im Kampf:** Dauer-Effekt, eigene Waffenspur und Trefferfunken, eigene Todesanimation, eigene Spezial-Szene (Name/Farbe)
- **Sichtbar** im Kampf und auf den Karten (Shop/Reihe) mit leuchtendem Rahmen in Seltenheitsfarbe
- **Vorschau** (Bild + animierte GIFs) vor dem Einbau; die bisherigen 4 einfachen Skins werden ersetzt

### Kartendesign nach Seltenheit (beantwortet 2026-11-17, freigegeben und umgesetzt in v0.22.0)
- **Auf der Karte nur noch:** Name, Angriff & Leben (gelb bei Verstärkung), Stufe als **römische Ziffer** (I–III, kleines Siegel), Ausrüstungs-/Segen-Symbole. Rang-, Farb- und Gegnersymbole stehen **nur noch im Info-Fenster**
- **Eigene Karten – Rahmen-Material nach Rang:** Bube Holz, Ritter Eisen, Königin Silber mit Eck-Ornamenten, König Gold mit Edelsteinen, Legende Gold mit leuchtenden Edelsteinen und Schimmer
- **Hintergrund:** Pergament in der Tarot-Farbe getönt (Münzen grünlich, Stäbe rötlich, Kelche bläulich, Schwerter violett), Motive nach Rang gestaffelt: Bube Wasserzeichen des Farbsymbols, Ritter + Ornament-Bordüre, Königin + Rankenmuster, König + Strahlenkranz hinter der Figur, Legende + Sternenhimmel und Strahlen
- **Gegnerkarten – verfluchte Gegenstücke:** dunkles, rissiges Pergament, Rahmen nach Kosten gestaffelt (rostiges Eisen → mit Dornen → Knochen und Blutrot), Bosse mit Totenköpfen und glühenden Augen
- **Fusionen:** verflochtener Rahmen aus den Materialien/Farben der enthaltenen Figuren, F-Stufe als Siegel, ab F3 leuchtend
- Legendäre Skins behalten ihren leuchtenden Rahmen in der Themenfarbe

### Balancing-Runde 2 – Münzen, Farb-Builds, härterer Anfang, Belohnungen (beantwortet 2026-11-17, freigegeben und umgesetzt in v0.26.0)
- **Münzfiguren:** König Midas ×(1 + Gold/10) / /7 / /5 (vorher /20 /15 /10); Münzknecht behält Schild 2/4/6 und bringt nach jedem Sieg +1 / +1 / +2 Gold; Goldene Waage gibt zusätzlich zu Kampfbeginn der hintersten Figur ×(1 + 0,05 je 5 Gold) Angriff
- **Farbboni (je Figur der Farbe in der Reihe, im Team-Info sichtbar):**
  - Münzen: Zins-Obergrenze +1 je Münzfigur
  - Schwerter: zu Kampfbeginn 1 Blutung auf jeden Gegner je 2 Schwertfiguren
  - Kelche: jede Kelchfigur +2 Leben je Kelchfigur im Team
  - Stäbe: zu Kampfbeginn 1 Brennen auf den vordersten Gegner je Stabfigur
- **Härterer Anfang:** Startgold 8 → 6; reicht das laut Bots nicht, Gegner in Akt 1 etwas stärker
- **Boss-Sieg – Schatzkammer:** zusätzlich zur bisherigen Belohnung 1 von 3 Schätzen wählen: ein Relikt, ein Ass-Pack mit garantierter Legende oder +12 Gold, mit eigener Animation
- **Relikte** nur noch aus der Schatzkammer oder sehr selten (5 %) als Zusatzwahl in Arkana-Packs; das Relikt-Pack im Shop entfällt
- **Pakte seltener:** Seelen-Pack 7 statt 4 Seelen, das Opferaltar-Ereignis (zwei Figuren opfern → 1 von 3 Pakten; in der Frage „Der Teufel“ genannt) erscheint halb so oft; max. 3 Pakte bleibt
- **Schwere Gegnerbanden:** mittel +3 Gold (vorher +2), schwer +5 Gold (vorher +4) und ein Gratis-Beutepack (Ausrüstung oder Arkana)
- **Schwache Buben stärker:** Messdiener 1/3 → 1/4, Heilung 2/3/4; Funkenträger 2/2 → 2/3
- **Starke Karten gedämpft:** Klinge der Klarheit 4/4 → 4/3, Richter 5/5 → 5/4, Ertrunkener König Aufnahme 30/60/100 % → 25/50/80 %
- **Nicht gewählt:** Neu würfeln günstiger, Zins je 4 Gold
- Danach Messung mit den 6 Bots (je 150 Runs) und Vergleich mit v0.25.0
- **Umsetzungsdetails v0.26.0:** Startgold bei allen Okkultisten −2 (Novize 6, Wucherer 4, Fechter 6). Startgold allein reichte laut Bots nicht → Gegnerbudgets Akt 1 klein 1,5 → 2,6, groß 3,0 → 4,6, Boss-Gefolge Akt 1 1,0 → 1,5; Akt-Wachstum 3,2 → 3,4; Gefolge Akt-2-Boss 6 → 13 (die Schatzkammer macht Akt 2 sonst zu leicht). Das Ass-Pack zieht aus allen Assen, auch aus noch nicht im Lager freigeschalteten. Relikt beim Schwarzmarkt (gegen Gold) und beim Duell-Sieg bleiben als seltene Quellen; Relikt-Packs gibt es nicht mehr. Beutepack: Ausrüstung oder Arkana, normal groß, gratis, golden leuchtend im nächsten Shop. Die Kelch-, Schwert- und Stab-Boni stehen im Info-Fenster der Figur, alle aktiven Boni als Zeile unter der eigenen Reihe
- **Messung v0.26.0 (150 Runs je Bot):** Siegquote Verschwender 18 %, Farbspezialist 12 %, Sparer 11 %, Taktiker 11 %, Fusionist 9 %, Leveler 5 % (v0.25.0: 1–12 %). Stationen: A1 K1 77 % (vorher 92 %), A1 K2 72 % (81 %), A1 Boss 35 % (16 %), A2 K1 95 %, A2 K2 82 %, A2 Boss 75 % (59 %). König Midas am Run-Ende 71 % Siegquote (vorher 10 %)

### Neue Gegner und negative Ereignisse (beantwortet 2026-11-17, Pixel-Vorschau freigegeben, umgesetzt in v0.28.0)
- **Anlass:** Nur 8 normale Gegner (max. Kosten 3) – in Akt 2 ist die Reihe voll, mehr Budget macht Akt 2 nicht schwerer (Duell-Matrix, Auto-Tuning)
- **8 neue Gegner** mit eigenem Pixel-Art:
  - Akt 1 (billig): **Fluchweber** (hinten, Kampfbeginn: Fluch 1 auf die vorderste Spielerfigur), **Kerzenträger** (hinten, heilt jede Runde den vordersten Gegner)
  - Akt 2 (Elite, Kosten 4–6, erst ab Akt 2): **Salzgolem** (immun gegen Brennen), **Bannprior** (hinten, Spielerfiguren können nicht geheilt werden), **Schildbrecher** (Kampfbeginn: zerstört alle Spieler-Schilde), **Wundversiegler** (entfernt jede Runde Blutung von seinem Team), **Tresorkardinal** (hinten, gibt allen Gegnern Schild), **Uhrwerk-Wächter** (+2 Angriff jede Runde)
  - Rollen: Konter je Farb-Build, Unterstützer hinten, Bedrohung mit Uhr, Flüche
- **4 negative Ereignisse, jeweils mit Ausweg**, selten (etwa in jedem 3. Run eines, nie direkt vor einem Boss):
  - **Steuerrazzia:** 30 % Gold abgeben oder gegen die Steuertruppe kämpfen
  - **Seuche:** eine Figur −2 Leben bis Aktende oder 5 Gold / 1 Seele zahlen
  - **Hinterhalt:** sofort ein Kampf ohne Einkauf oder fliehen und die hinterste Figur verlieren
  - **Fluchnebel:** alle Figuren im nächsten Kampf verflucht oder eine Tarotkarte / 6 Gold opfern
- **Ablauf:** erst Pixel-Vorschau der 8 Gegner, nach Freigabe Einbau, Balancing mit den neuen Werkzeugen, Deploy
- **Werte v0.28.0:** Fluchweber 1/3 (Kosten 1, Fluch 1/1/2), Kerzenträger 1/5 (Kosten 2, Heilung 1/2/3), Salzgolem 4/14 (Kosten 4), Bannprior 3/9 (Kosten 4), Schildbrecher 6/8 (Kosten 4, wirkt nach allen Schild-Effekten), Wundversiegler 3/10 (Kosten 4, entfernt 2/4/6 Blutung je Verbündetem), Tresorkardinal 2/12 (Kosten 5, Schild 3/4/5 für alle), Uhrwerk-Wächter 4/12 (Kosten 5, +2/+2/+3 Angriff je Runde); Elite-Karten mit dem Rahmen der höchsten Stufe, im Info-Fenster „Elite (ab Akt 2)“
- **Ereignisse v0.28.0:** Chance 13 % nach jedem Kampf, der nicht direkt vor einem Boss liegt, höchstens eins pro Run, zusätzlich zu den normalen Ereignissen; kein „Weitergehen“ ohne Wahl. Steuerrazzia: 30 % Gold (aufgerundet) oder Kampf gegen eine mittlere gierige Bande (Sieg +3 Gold, Niederlage: vorderste Figur fällt). Seuche: 5 Gold, 1 Seele oder zufällige Figur −2 Leben bis Aktende. Hinterhalt: Kampf gegen eine mittlere Bande der aktuellen Station (Sieg +3 Gold) oder Flucht ohne die hinterste Figur. Fluchnebel: 6 Gold, die zuletzt erhaltene Tarotkarte oder Fluch 2 auf alle Figuren im nächsten Kampf

### Sound, Musik und Hinweise beim ersten Mal (beantwortet 2026-11-17)
- **Quelle:** freie CC0-Bibliotheken von OpenGameArt (Kenney-Pakete und weitere CC0-Pakete), Lizenzen in `docs/AUDIO_CREDITS.md`; kenney.nl selbst blockt automatische Abrufe, die Kenney-Pakete kommen über OpenGameArt
- **Musik:** Kombination aus düster (Orgel, Glocken, Tempel) und Chiptune 8/16 Bit: Menü „Cathedral“ (Umplix), Planung „Dark Shrine Loop“ (qubodup/yd), Lager „Dark Bishop“, Kampf „8-Bit Slay the Evil“ (HydroGene), Boss „8-Bit Danger Strong Boss“ (HydroGene)
- **Effekte:** Karten (Legen, Ziehen, Packs, Mischen), Münzen, Treffer, Schild-Block, Brennen, Blutung, Fluch, Heilung, Tod, Wiederbelebung, Stufenaufstieg, Fusion, Schatzkammer, Glocken für seltene Funde, Sieg/Niederlage, Knöpfe
- **Regler:** Musik und Effekte getrennt plus Stumm-Knopf im Menü, gespeichert
- **Hinweise beim ersten Mal:** Pergament-Zettel mit Pfeil neben dem neuen Element, 1–2 Sätze, „Verstanden“; jeder Hinweis nur einmal, im Menü zurücksetzbar und ganz abschaltbar
- **Aschepakt:** Brennen ×1,75 (zwischen ×2 und ×1,5)

### Kartenfarbe nach Familie (beantwortet 2026-11-17, umgesetzt in v0.30.0)
- **Figurenkarten (Vorderseite):** Hintergrund und Rahmen in der Familienfarbe – Münzen Grün, Stäbe Rot-Orange, Kelche Blau, Schwerter Violett (wie bisher bei Farbboni, Edelsteinen, Gewändern)
- **Rang/Seltenheit** bleibt sichtbar über Glanz, Funkeln, Polychrom und Rahmenschmuck (Edelsteine, Ornamente), nicht mehr über die Grundfarbe
- **Familiensymbol neu gezeichnet:** Münze mit Pentakel, Stab mit Flamme, Kelch, Schwert – kräftig in Familienfarbe mit heller Kontur, groß als Wasserzeichen hinter der Figur und klein in einer Ecke; Vorschau vor dem Einbau
- Verdeckte Rückseiten in Packs bleiben nach Seltenheit leuchtend

### Übersicht und Intuition (beantwortet 2026-11-17, paketweise mit Vorschau)
Gewählt aus 26 Vorschlägen (nicht gewählt: 11 Auto-Aufstellen, 15 Kampf-Protokoll, 20–22 Hilfen):
- **Paket 1 – Planung neu:** (1) drei Zonen: Gegner oben, eigene Reihe groß in der Mitte, Shop unten, Relikte/Tarot/Pakte in einer einklappbaren Seitenleiste · (3) Ressourcenleiste mit Symbolen (Gold, Zinsen, Seelen, Plätze; Glut nur im Menü) · (5) Fähigkeits-Kurzsymbol mit Zahl auf jeder Figurenkarte · (6) Stufen-Punkte statt „EP 0/3“ · (7) „+1“-Markierung für Shop-Karten, die aufleveln würden · (10) Ablagezonen leuchten beim Ziehen (grün verschmilzt, gold frei, rot geht nicht)
- **Paket 2 – Entscheidungshilfen:** (2) Siegchance vor dem Kampf (hoch/knapp/gering) · (8) Farbbonus-Vorschau beim Ziehen · (9) Werte-Änderungen mit Pfeilen und Quelle · (12) Kampf-Warnung bei freien Plätzen/Gold
- **Paket 3 – Kampfanzeige:** (16) Pause und Schritt für Schritt · (17) größere Schadenszahlen und Status-Symbole · (18) Kampf-Auswertung am Ende
- **Paket 4 – Gestaltung:** (23) festes Farbsystem · (24) neues Info-Fenster · (25) weniger Text auf dem Hauptbildschirm, Symbole mit Info · (4) Phasen-Titelkarten
- **Paket 5 – Einstieg und Feinschliff:** (19) geführter erster Run · (13) größere Tippflächen, Debug nur in der Testversion · (14) ein Bedienprinzip überall · (26) Handy-Layout prüfen
- Jedes Paket mit Bildschirmfoto-Vorschau und OK vor dem Deploy

## Phase 11 – Benutzeroberfläche und Bedienung

### Runde 1 (beantwortet)
- **Kampf-Layout:** **Links vs. rechts.** Das eigene Team steht links, die Gegner rechts, die vordersten Figuren treffen sich in der Mitte.
- **Details:** **Tippen → Detail-Panel** am Rand (Werte, Effekte, Ausrüstung, Segen). Am PC zusätzlich Hover.
- **Bedienung:** **Drag & Drop + Tipp-Alternative** (antippen, dann Ziel antippen) für Kaufen, Umordnen, Ausrüsten, Fusionieren und Verkaufen.
- **Einstieg:** **Hinweise beim ersten Mal**, wenn ein System erstmals auftaucht (erster Shop, erste Fusion, erster Pakt usw.). Kein Zwangs-Tutorial.

### Runde 2 (beantwortet)
- **Schutz vor Fehlern:**
  - **Rückgängig-Knopf** für Shop-Aktionen (Kaufen, Umordnen, Ausrüsten), solange der Kampf nicht gestartet ist
  - Neu würfeln ist **nicht** rückgängig zu machen, sonst ließen sich Angebote ausspielen
  - **Bestätigungsabfrage** bei unumkehrbaren Aktionen: Verkauf von Figuren ab Stufe 2 oder mit Fusion, Opfern, Pakte, Fusion
- **Kampf-Feedback:** **Klar + saftig.** Die auslösende Figur leuchtet auf, ein Pfeil zeigt zum Ziel, Zahlen fliegen hoch, Multiplikatoren erscheinen groß in Rot, große Treffer lassen den Bildschirm wackeln (Balatro-Feeling).
- **Barrierefreiheit:**
  - Farbenblind-Modus: Tarot-Farben zusätzlich mit Symbolen (Stab, Kelch, Schwert, Münze). Symbole von Anfang an einplanen.
  - Einstellbare Textgröße
  - „Weniger Bewegung“: Wackeln und Blitze abschaltbar
- **Hauptmenü:** Minimal: Fortsetzen / Neuer Run (Okkultisten-Wahl + Stufe) / Grimoire / Bestwerte / Optionen

## Phase 12 – Präsentation: Grafik, Audio, Atmosphäre

### Runde 1 (beantwortet)
- **Farbpalette (Nutzer-Wunsch):** Eine **Mischung** aus dunkel/gold, Vintage-Tarot und Neon. Klar erkennbare **Details und Verzierungen**. **Neonfarben heben Mächtigkeit und Seltenheit hervor**, damit Stärke und Seltenheit sofort erkennbar sind.
  - Umsetzung (bestätigt in Runde 2): Die Basis ist gedeckt (dunkler Grund, Pergament, Gold-Ornamente). **Neon-Leuchten** steigt mit Seltenheit, Stufe und Fusionsstufe.
- **Audio:** Soundeffekte aus lizenzfreien Bibliotheken (z. B. Kenney, freesound CC0), **Musik per KI-Generator**. Lizenzen dokumentieren.
- **Textton:** **Ernst mit trockenem Humor** (Darkest Dungeon mit Augenzwinkern)
- **Sprachen:** **Deutsch** zuerst. Alle Texte von Anfang an in einer Übersetzungsdatei (Godot-Lokalisierung), Englisch später ohne Umbau.

### Runde 2 (beantwortet)
- **Seltenheits-Optik (bestätigt):**

  | Rang | Rahmen | Leuchten |
  |------|--------|----------|
  | Bube (häufig) | schlichter Holzschnitt | keines |
  | Ritter (ungewöhnlich) | Silber | dezenter Neon-Rand in der Farbfarbe |
  | Königin (selten) | Gold mit Ornamenten | kräftiges Neon |
  | König (episch) | verziertes Gold | pulsierendes Neon + Partikel |

  - Jede **Fusionsstufe (F1–F3)** fügt einen Ornament-Ring hinzu. **F3** leuchtet mehrfarbig nach den beteiligten Farben.
  - Das System gilt analog für Ausrüstung und Relikte (Gewöhnlich → Magisch → Selten → Verflucht/Legendär).
- **Spielname:** später entscheiden (Kandidaten: *Arcana Profana*, *Hofstaat der Asche*, *Die Verfluchte Hand*)
- **Musik:** Ein Thema pro Gebiet (4) + Boss-Thema + Shop- und Menümusik
- **Animation:** **Statische Bilder + Code-Effekte** (Wackeln, Stoßen, Aufblitzen, Zerfallen). Keine Frame-Animationen.

## Phase 13 – Speichern, Daten und Persistenz

### Runde 1 (beantwortet)
- **Speichern:** Autosave nach jeder Aktion, kein manuelles Laden (Phase 10)
- **Speicherort:** **Lokal** (Browser-Speicher bzw. Gerät über Godot `user://`) + **Export/Import-Code** für den Meta-Fortschritt (Backup, Gerätewechsel). Kein Server.
- **Format:** **JSON mit Versionsnummer.** Bei Updates werden alte Stände automatisch migriert.
- **Determinismus:** **Ja.** Ein Master-Seed pro Run mit **getrennten Zufallsströmen** (Shop, Gegner-Generator, Ereignisse, Gegenstands-Würfe, Kampf-Fähigkeiten). Bugs sind exakt reproduzierbar, Seed-Teilen und Daily sind später möglich.
- **Langzeit-Statistiken:**
  - Runs / Siege / Siegquote je Okkultist und Schwierigkeitsstufe
  - Figuren-Statistik (meistgekauft, Siegquote je Figur und Fusion)
  - Rekorde (höchster Treffer, längster Run, meiste Seelen …)

## Phase 14 – Architektur und Code-Struktur

### Runde 1 (beantwortet)
- **Inhalts-Format:** Nutzer: „Ich ändere nur in Zusammenarbeit mit dir, also was für dich am besten ist.“ → Claude schlägt **JSON** vor, Bestätigung in Runde 2.
- **Effekt-System:** **Baukasten + Sonderskripte.** Normale Fähigkeiten bestehen aus Bausteinen (Auslöser + Ziel + Wirkung [+ Bedingung]). Meisterfähigkeiten, Regel-Bosse und geheime Rezepte dürfen eigenen Code haben.
- **Kampf-Simulation:** **Ja.** Spiellogik ist strikt von der Darstellung getrennt (headless lauffähig), damit sich tausende Kämpfe für das Balancing simulieren lassen.
- **Debug-Menü (versteckt, nur im Test-Build):** Gold/Seelen geben, Figur/Objekt spawnen, zu Akt/Boss springen, Seed anzeigen/setzen.

### Runde 2 (beantwortet)
- **Inhalts-Format:** **JSON** für alle Inhalte (Figuren, Gegner, Objekte, Pakte, Bosse, Ereignisse) im Ordner `data/`, mit automatischer Schema-Prüfung.
- **Architektur-Paket (bestätigt):**
  1. Zustandsmaschine: Menü → Okkultisten-Wahl → Gegnerwahl → Planung → Kampf → Belohnung → Shop → Tod/Sieg
  2. Spieler-Aktionen als Command-Objekte (für Rückgängig und Autosave)
  3. Event-Bus für Auslöser (Kampfbeginn, Treffer, Tod, Shop …)
  4. Figuren als Datenobjekte, Komposition statt Vererbung
  5. Master-Seed mit getrennten RNG-Strömen
  6. Automatische Tests mit GUT (Formeln, Effekte, Fusionen, Generator)
- **Code-Sprache:** **Alles Englisch** (Bezeichner und Kommentare). Spieltexte über die Übersetzungsdatei (Deutsch zuerst).
- **Test-Builds:** **GitHub Pages**, automatisch per GitHub Actions. Godot-Web-Export ohne Threads (Pages sendet keine COOP/COEP-Header). Pages muss im Repo einmalig aktiviert werden, bei privatem Repo ggf. ein kostenpflichtiger Plan nötig.

## Phase 15 – Umsetzungsplan und Meilensteine

### Runde 1 (beantwortet)
Reihenfolge **bestätigt**. Jeder Meilenstein endet mit einem spielbaren Browser-Link (GitHub Pages), einem Commit und einer Feedback-Runde.

| # | Meilenstein | Testbar |
|---|---|---|
| M0 | Grundgerüst: Godot-Projekt, Web-Export, GitHub-Pages-Pipeline | Link öffnet sich am Handy im Querformat |
| M1 | Kampf-Kern: 2 Reihen, vorderste gegen vorderste, Schritt-Animation, 1×/2×/4×, Sieg/Niederlage, headless Simulation + Tests | Ein Kampf läuft nachvollziehbar |
| M2 | Fähigkeiten-Baukasten: alle Auslöser, 4 Status, `(Angriff + Boni) × Mult`, ~6 Test-Figuren, saftiges Feedback | Synergie-Ketten feuern |
| M3 | Run-Schleife: Gegnerwahl mit Vorschau, Shop 3+2, Neuwürfeln, Gold + Zinsen, Duplikate leveln, Plätze 3→6, Rückgängig, 2 Akte, Tod/Sieg | Kompletter Mini-Run |
| M4 | Echte Inhalte: 16 Figuren, Münzen-Gegner, Budget-Generator, 2 Regel-Bosse, Gebiets-Segen | Slice mit echtem Inhalt |
| M5 | Objekte: Ausrüstung mit Seltenheit, Relikte (global + Segen), Tarot-Karten, Seelen, Pakte, Ereignisse + Pity-Timer, Überspringen | Volle Build-Tiefe |
| M6 | Fusion: F1–F3, Fähigkeitswahl, Meisterfähigkeiten, Altar / nach Boss / Ritualkerze | Das Herzstück |
| M7 | 2 Okkultisten, Meta: Freischaltungen, Upgrades, Grimoire, Statistiken, Autosave + Export-Code | Fortschritt über Runs |
| M8 | Präsentation: KI-Tool-Test, echte Grafik, Leucht-System, Sound/Musik, Barrierefreiheit, Erst-Hinweise | Sieht aus wie das Spiel |
| M9 | Balancing per Simulation, Endlos-Modus → **Vertical Slice fertig** | Feedback: Macht es Spaß? |

**Nach dem Slice:** Gebiete 2–4, 8 Akte, Endboss aus den Großen Arkana, Schwierigkeitsstufen, geheime Rezepte, Englisch, Seed-Teilen.

- **Figurenrunden:** **Vor dem Start von M0** werden alle 16 Figuren gemeinsam Figur für Figur entworfen (eine Runde pro Tarot-Farbe), dazu die Münzen-Gegner.
- **Zusammenfassung:** Vom Nutzer übersprungen („direkt starten“). Sie steht unten im Dokument.

### Detailentscheidungen vor M3
- **Plätze:** +1 Platz gratis nach jedem besiegten Akt-Boss. ~~Zusätzlich im Shop kaufbar für 6 → 8 → 10 Gold.~~ **Nach v0.4.2-Feedback: nur noch durch Boss-Siege (Umsetzung mit M5).** Maximum 6.
- **Belohnung nach Sieg:** Gratis **1 aus 3** wählen (bis M5 nur Figuren, danach auch Objekte). Wer überspringt oder keinen Platz hat, bekommt **+2 Gold**.
- **Ränge im Shop (Bube / Ritter / Königin / König):** Akt 1: 68 / 25 / 5 / 2 % · Akt 2: 50 / 32 / 14 / 4 % · Akt 3–4: 40 / 33 / 20 / 7 % · Akt 5+: 30 / 33 / 25 / 12 %
- **Start bis M7 (ohne Okkultisten):** ein zufälliger Bube + **8 Gold** (nach M3-Feedback von 10 gesenkt)
- **Ablauf eines Kampfzyklus:** Gegnerwahl (volle Vorschau) → Planung/Shop (der gewählte Gegner bleibt sichtbar) → Kampf → Belohnung → nächste Gegnerwahl
- **Erfahrung intern in Dritteln:** Duplikat = 3, Kampfsieg = 1, Stufe 2 ab 9, Stufe 3 ab 18 (entspricht 3 bzw. 6 Erfahrung)
- **Gegner-Budgets (vorläufig, per Bot-Simulation):** Akt 1 = klein 1,5 / groß 3 / Boss 4, ×1,5 pro Akt; Leicht ×0,75, Mittel ×1, Schwer ×1,35. Ein blinder Bot gewinnt ~27–36 % der Slice-Runs. Feinschliff in M4/M9.
- **Duplikate:** Wird eine gekaufte Figur auf eine gleiche Figur gelegt, verschmilzt sie. Auf einen freien Platz gelegt, entsteht eine zweite eigenständige Kopie.

---

## Inhalte – Figuren (Vertical Slice)
*Basislinie: Kaufpreis 3 Gold für alle. Stufen geben +1/+1 und verstärken die Fähigkeit (Stufe 1/2/3). Ränge bestimmen, wie oft eine Figur im Shop erscheint.*

### Münzen (Erde) – Thema Schild, Gold, Wirtschaft
| Rang | Name | A/L | Fähigkeit (Stufe 1 / 2 / 3) |
|---|---|---|---|
| Bube | **Münzknecht** | 1/4 | *Kampfbeginn:* erhält Schild 2 / 4 / 6; *nach jedem Sieg:* +1 / +1 / +2 Gold (v0.26.0) |
| Ritter | **Goldgepanzerter** | 3/4 | *Kampfbeginn:* erhält Schild 1 pro 4 / 3 / 2 Gold im Besitz (nach Feedback statt Leben) |
| Königin | **Goldene Waage** | 3/4 | *Bei Tod einer eigenen Figur:* **hinterste** eigene Figur erhält ×1,2 / ×1,35 / ×1,5 Angriff (Mult, stapelt) – geändert nach M5a-Feedback, vorher vorderste; *Kampfbeginn:* hinterste Figur ×(1 + 0,05 je 5 Gold) (v0.26.0) |
| König | **König Midas** | 4/6 | *Kampfbeginn:* erhält ×(1 + Gold/10) / ×(1 + Gold/7) / ×(1 + Gold/5) Angriff (Mult) – v0.26.0, vorher /20 /15 /10 |

*Profil:* Ein starker Spar-Build (Goldgepanzerter + Midas) steht gegen das Kaufen. Schild kommt vom Buben und (goldabhängig) vom Goldgepanzerten. Die Waage bringt Multiplikatoren für Opfer-Builds und verbindet sich mit Kelchen (Opfer).

### Stäbe (Feuer) – Thema Brennen, Aggression
| Rang | Name | A/L | Fähigkeit (Stufe 1 / 2 / 3) |
|---|---|---|---|
| Bube | **Funkenträger** | 2/2 | *Bei Angriff:* Ziel erhält Brennen 2 / 3 / 4 (nach Feedback verstärkt) |
| Ritter | **Wutentbrannter** | 4/3 | *Wenn getroffen:* Der Angreifer erhält Brennen 1 / 2 / 3 (nach Feedback statt Angriff) |
| Königin | **Herrin der Glut** | 3/5 | *Aura (dauerhaft):* Brennen-Schaden an Gegnern ×1,5 / ×2 / ×2,5 (Mult) |
| König | **Aschekönig** | 6/4 | *Nach dem Angriff:* Ziel erhält Brennen 3. *Bei Tod eines Gegners:* dessen Brennen springt auf den nächsten Gegner, König erhält ×1,1 / ×1,2 / ×1,3 Angriff (Mult, stapelt) |

*Profil:* Brennen-Motor (Bube → Königin → König) plus ein eskalierender Frontkämpfer.
*Technik-Hinweis:* „Aura“ ist ein Dauer-Modifikator (keiner der vier Auslöser). Der Baukasten bekommt dafür den Typ `aura`.

### Kelche (Wasser) – Thema Fluch, Heilung, Opfer
| Rang | Name | A/L | Fähigkeit (Stufe 1 / 2 / 3) |
|---|---|---|---|
| Bube | **Messdiener** | 1/3 | *Zugbeginn:* heilt die Figur vor sich um 1 / 2 / 3 |
| Ritter | **Bluttrinker** | 3/4 | *Bei Angriff:* heilt sich um 50 % / 75 % / 100 % des verursachten Schadens |
| Königin | **Kelch der Wiederkehr** | 1/5 | *Bei Tod einer eigenen Figur:* einmal pro Kampf kehrt diese mit 1 / 2 / 3 Leben zurück |
| König | **Der Ertrunkene König** | 4/8 | *Bei Tod einer eigenen Figur:* erhält **30 / 60 / 100 %** von deren Angriff **und** Leben für den Kampf (abgeschwächt nach M4-Feedback, vorher ×0,5/0,75/1 Angriff + volles Leben) |

*Profil:* Ein Sustain- und Opfer-Team. Wiederkehr + Ertrunkener König: Die zurückgekehrte Figur stirbt ein zweites Mal und füttert den König doppelt.
⚠️ *Lücke:* Keine Spieler-Figur nutzt den Kelch-Status **Fluch**. Fluch kommt vorerst über Gegner, Ausrüstung und Relikte (prüfen in Inhaltsrunde 5 / M5).

### Schwerter (Luft) – Thema Blutung, Präzision
| Rang | Name | A/L | Fähigkeit (Stufe 1 / 2 / 3) |
|---|---|---|---|
| Bube | **Klingenlehrling** | 2/2 | *Bei Angriff:* Ziel erhält Blutung 1 / 2 / 3 |
| Ritter | **Henker** | 4/3 | *Bei Angriff:* Ziel mit ≤ 3 / 4 / 5 Leben (nach dem Treffer) stirbt sofort |
| Königin | **Klare Klinge** | 4/4 | *Kampfbeginn:* entfernt alle Schilde der Gegner, pro entferntem Schild-Stapel Blutung 1 / 2 / 3 auf diese Figur |
| König | **Der Richter** | 5/5 | *Bei Angriff:* löst die Blutung des Ziels sofort als Schaden aus, ×2 / ×3 / ×4 |

*Profil:* Blutung aufbauen (Bube, Königin) und mit dem Richter auslösen. Der Henker räumt Reste ab. Die Klare Klinge kontert Münzen-Schild-Teams (gut gegen Gebiet 1).
*Offen für den Prototyp:* Die genaue Richter-Formel. Vorschlag: Sofortschaden = Blutung-Stapel × 2 / 3 / 4, die Blutung bleibt bestehen.

### Münzen-Gegner (Gebiet 1)
*Budget-Kosten = Wert für den Gegner-Generator. Gegner leveln über das Budget (höhere Akte → Stufe 2/3).*

| Kosten | Name | A/L | Fähigkeit |
|---|---|---|---|
| 1 | **Bettlergeist** | 1/3 | *Bei Treffer (wird getroffen):* stiehlt dem Spieler 1 Gold (max. 3 pro Kampf) |
| 1 | **Schuldeneintreiber** | 2/3 | *Kampfbeginn:* +1 / 2 / 3 Angriff je volle 10 Gold des Spielers (geändert nach M3-Feedback) |
| 2 | **Der Wechsler** | 3/4 | *Kampfbeginn:* tauscht Angriff und Leben der vordersten Spieler-Figur |
| 2 | **Gierschlund** | 4/4 | *Bei Angriff:* hat das Ziel Schild, frisst er ihn und heilt sich um dessen Wert |
| 2 | **Tresorwächter** | 2/8 | *Kampfbeginn:* Schild 3. *Bei Treffer:* Schild +1 |
| 2 | **Münzwerfer** | 2/3 | *Zugbeginn:* 1 Schaden an die hinterste Spieler-Figur |
| 3 | **Gieriger Drache** | 6/6 | *Bei Tod einer Spieler-Figur:* +1/+1 (stapelt) |
| 3 | **Spiegelmünze** | 3/5 | *Kampfbeginn:* kopiert die Fähigkeit der vordersten Spieler-Figur |

*Profil:* Diese Gegner greifen Gold und Schild an, also genau die Stärken der Münz-Figuren. Es gibt einen echten Tank (Tresorwächter), einen Sniper gegen die hintere Reihe (Münzwerfer), einen Konter gegen Opfer-Builds (Drache) und einen Wildcard-Gegner (Spiegelmünze, in der Vorschau sichtbar).
⚠️ *Fluch-Lücke bleibt:* Weder Spieler noch Münzen-Gegner nutzen Fluch → über Ausrüstung/Relikte in M5 abdecken.

### Gegner-Themen (M4, Vorschlag von Claude)
Der Gegner-Generator wählt pro Gegner-Team ein Thema des Gebiets. Gegner mit diesem Thema werden 3× so oft gezogen. Die Aufstellung folgt der Rolle: vorne → beliebig → hinten (bei Gleichstand mehr Leben nach vorne).

| Thema | Name im Spiel | Gegner |
|---|---|---|
| greed | Gierige Bande | Bettlergeist, Schuldeneintreiber, Gieriger Drache |
| vault | Tresorwache | Tresorwächter, Gierschlund, Spiegelmünze |
| trickster | Gaukler | Der Wechsler, Münzwerfer, Spiegelmünze |

Rollen: vorne = Schuldeneintreiber, Gierschlund, Tresorwächter · hinten = Münzwerfer, Gieriger Drache · beliebig = Rest

### Objekte (M5a, Set-Vorschläge von Claude, vom Nutzer bestätigt)
**Ausrüstung** (1 pro Figur) – Grundtyp + zufällige Zusatzeffekte je Seltenheit:

| Grundtyp | Grundwirkung |
|---|---|
| Klinge | +2 Angriff |
| Schildbuckel | Kampfbeginn: Schild 3 |
| Amulett | +3 Leben |
| Fackel | Nach dem Angriff: Ziel erhält Brennen 1 |
| Dolch | Nach dem Angriff: Ziel erhält Blutung 1 |
| Geldkatze | Kampfbeginn: +1 Angriff je 10 Gold |

- Seltenheit: Gewöhnlich (nur Grundwirkung) · Magisch (+1 Zusatz) · Selten (+2) · Verflucht (~~+3~~ **+2** und 1 Nachteil)
- **Nach M5b-Feedback abgeschwächt:** Seltenheits-Quoten Akt 1 85/13/2/0 %, Akt 2 75/19/5/1 %, Akt 3+ 65/24/8/3 %; kleinere Zusatzwerte (+1 Angriff, +1–2 Leben, Schild 1, ×1,1); größere Packs verbessern die Seltenheit nicht
- **Max. 2 Objekte pro Figur** (Ausrüstung, Segen, jede Kraft-Karte). Später: besondere Gegenstände/Relikte wie „negative Joker“ erlauben einen 3. Platz.
- Neue Ausrüstung auf eine ausgerüstete Figur → Vergleichsfenster (Tauschen / Altes behalten)
- Zusatz-Pool: +1–2 Angriff · +2–3 Leben · Kampfbeginn Schild 1–2 · Zugbeginn Heilung 1 · Wenn getroffen +1 Angriff · Bei Tod +2 Gold · ×1,1–1,2 Angriff (ab Selten) · Ziel Brennen 1 · Ziel Blutung 1
- Nachteil-Pool: −2 Leben · Kampfbeginn Fluch 1 auf sich · Kampfbeginn Brennen 1 auf sich · −1 Gold nach jedem Kampf

**Relikte** (3 globale Plätze): Kriegskasse (Münz-Figuren +1 Angriff) · Ewige Glut (eigenes Brennen +1 Stapel) · Blutkelch (Kelch-Figuren heilen zu Zugbeginn 1) · Wetzstein (Blutung der Schwert-Figuren +1 Stapel) · Vorhut-Banner (vorderste Figur ×1,5 Angriff) · Totenglocke (stirbt eine eigene Figur: alle anderen +1 Angriff) · Bettelschale (nach jedem Sieg +1 Gold) · Hofstaat (je Königin/König/Legendäre: alle Figuren +1 Leben)

**Tarot-Karten** (2 Kartenplätze, Einmalnutzung, Ziel ist immer eine eigene Figur): Die Kraft (dauerhaft +2/+2) · Der Magier (+1 Erfahrung) · Der Stern (Segen: Kampfbeginn Schild 3) · Die Sonne (Segen: ×1,25 Angriff) · Der Gehängte (Figur opfern → voller Kaufpreis als Gold) · Das Rad des Schicksals (Figur wechselt zufällig die Tarot-Farbe). Ein Segen belegt den Segen-Platz der Figur, ein neuer ersetzt den alten.

**Packs statt Direktkauf (Nutzer-Idee, Balatro-Prinzip):** Objekte sind nicht direkt kaufbar, nur über Packs. Figuren gibt es nur direkt im Shop.
- Shop: 3 Figuren (Direktkauf) + 2 Packs
- **Schmiede-Pack** 4 Gold (3 Ausrüstungen, wähle 1) · **Arkana-Pack** 4 Gold (3 Tarot, wähle 1; jede Karte mit 1 % Chance stattdessen eine legendäre Figur, Mega 2 %) · **Reliquien-Pack** 6 Gold (2 Relikte, wähle 1). ~~Hofstaat-Pack~~ gestrichen (M5a-Feedback).
- Beim Öffnen eines Packs und auf dem Belohnungsbildschirm kann man eigene Figuren verschmelzen (aufeinanderziehen) und verkaufen.
- Groß-Variante: +2 Gold, +1 Karte, bessere Seltenheit · Mega-Variante (selten): +4 Gold, 5 Karten, wähle 2

**Legendäre Figuren (nur aus Arcana-Packs, 1 % pro Karte, Mega 2 %; Hinweis „Legendär!“ mit polychromem Glanz; getrennt von Fusionsrezepten; Debug-Knopf zum gezielten Ziehen):**

| Ass | Name | A/L | Fähigkeit |
|---|---|---|---|
| Münzen | **Goldene Quelle** | 4/10 | Kampfbeginn: Alle Figuren erhalten Schild = Zinsen × 2 |
| Stäbe | **Flammenkrone** | 7/7 | Nach dem Angriff: Alle Gegner erhalten Brennen 1 |
| Kelche | **Tränenquelle** | 4/12 | Stirbt eine eigene Figur: Sie kehrt mit halbem Leben zurück (**1×** pro Kampf, nach Feedback von 2× gesenkt) |
| Schwerter | **Klinge der Wahrheit** | 7/7 | Angriffe ignorieren Schild; nach dem Angriff verdoppelt sie die Blutung des Ziels |

**Wirtschaft (v0.4.2-Feedback):** Grundeinkommen 5 → **4**. Plätze nicht mehr kaufbar.

### M5b – Seelen, Pakte, Ereignisse, Überspringen (Set von Claude, mit Nutzer-Änderungen bestätigt)
**Seelen (nach M5b-Feedback knapper):** Boss besiegt +2 · Figur opfern (Opferaltar) Rangwert + Stufe · eigene Figur stirbt im Kampf: 5 % Chance +1 · Seelen-Marke +2. Verwendung **nur** Pakte (Seelen-Pack **4 Seelen**) und ab M6 Fusion (plus einzelne Ereignisse). Pakte sind nicht verkaufbar.

**Pakte** (max. 3; **Seelen-Pack** 3 Seelen, 2 Pakte, wähle 1) – stark und run-prägend, Nachteile nach Feedback abgeschwächt:

| Pakt | Stärke | Nachteil |
|---|---|---|
| Blutpakt | Alle Figuren ×1,5 Angriff | Kampfbeginn: jede verliert 10 % Leben |
| Goldener Schwur | Zinsen bis +10, Gold-Effekte zählen doppeltes Gold | Neuwürfeln +1 |
| Aschepakt | Brennen-Schaden ×2, brennende Gegner geben Brennen beim Tod weiter | Vorderste Figur brennt zu Kampfbeginn (1) |
| Klingenschwur | Blutung deiner Figuren doppelt so viele Stapel | Heilung bei dir −25 % |
| Totenpakt | Stirbt eigene Figur: alle anderen ×1,1 Angriff (stapelt) | −1 Gold nach jedem Sieg |
| Wiederkehr-Pakt | Die ersten 2 gefallenen Figuren pro Kampf kehren mit halbem Leben zurück | Zinsen max. +3 |
| Pakt der Vorhut | Vorderste Figur ×2 Angriff und erhält alle Schilde des Teams | Hinterste Figur −1 Angriff |
| Seelenhunger | Pro getötetem Gegner: deine Figuren +1/+1 bis Kampfende, 25 % Chance +1 Seele | Seelen-Pack +1 |

**Ereignisse** (nach Feedback: höchstens **1 pro Akt**, 50 % Chance nach jedem gewonnenen Kampf, keine Garantie):

| Ereignis | Wahlen |
|---|---|
| Opferaltar | Figur opfern → Seelen · zwei Figuren opfern → Pakt nach Wahl gratis · gehen |
| Schwarzmarkt | Relikt für 4 Gold · Mega-Pack für 6 Gold · Königin/König zum halben Preis · gehen |
| Verfluchter Brunnen | 3 / 6 / 10 Gold → Magische / Seltene / besonders starke Ausrüstung · trinken: Figur dauerhaft +3/+3, aber verflucht (Kampfbeginn Fluch 2) |
| Wahrsagerin | 1 von 3 Tarot gratis · nächste Boss-Regel entfällt · 1 Seele → Mega-Arcana-Pack |
| Grabräuber | +8 Gold + Relikt, aber hinterste Figur verloren · +3 Gold |
| Spiegelkammer | Figur duplizieren (Stufe 1) für 2 Seelen · eine Figur gratis +1 Erfahrung |
| Duell | Sofortkampf gegen Elite: Sieg → Relikt + 2 Seelen, Niederlage → vorderste Figur verloren (kein Run-Ende) · ablehnen |
| Seelenhändler | 1 Seele ↔ 5 Gold (beliebig oft) · Pakt zurückgeben (+2 Seelen) |

**Überspringen:** Normale Kämpfe → **Marke** (in der Gegnerwahl vorher sichtbar): gratis Mega-Pack im nächsten Shop · +2 Seelen · 2 garantierte Ritter im nächsten Shop (nach Feedback: Königinnen/Könige zu stark) · alle Figuren +1 Erfahrung. Kein Gold, keine Erfahrung, kein Ereignis. Akt-Boss überspringen: eine Figur opfern, kein Platz, keine Seelen. Der letzte Boss des Slice ist nicht überspringbar.

### Regel-Bosse (Vertical Slice)
**Geändert nach M4-Feedback:** Bosse sind jetzt **Regel + echte Boss-Figur** (Phase-3-Entscheidung „Regel-Bosse“ erweitert zu „Beides kombiniert“). Die Boss-Figur ist 2–3 Kartenplätze breit, steht vorne, und ihr Gefolge füllt die restlichen Plätze.

| Akt | Name | Regel | Boss-Figur (gewählt → aktuell nach Simulation) |
|---|---|---|---|
| 1 | **Der Steuereintreiber** | Im Kampf gilt dein Gold als 0 (Fähigkeiten sehen 0, Diebstahl trifft echtes Gold) | „Pfänder“, 2 breit. *Nach dem Angriff:* stiehlt 1 Gold und erhält +X Angriff (max. 3× pro Kampf). Gewählt 6/14, +2 → **aktuell 3/12, +1** |
| 2 | **Die Goldene Mauer** | Das Gegner-Team hat 7 Plätze (Boss belegt 3) | „Bollwerk“, 3 breit. *Wenn getroffen:* Schild +X. Gewählt 4/30, +2 → **aktuell 3/20, +1** |

- **Ablauf:** Der Boss wird nicht gewählt. Nach der letzten Belohnung des Akts geht es direkt in den Boss-Shop, dann in den Kampf (Überspringen folgt mit M5).
- **Ankündigung:** Zu Kampfbeginn fährt ein Streifen über den ganzen Bildschirm (Name + Regel).
- **Boss-Budget fürs Gefolge:** gewählt ×1,5 → aktuell Akt 1 = 2 (×1,5 pro Akt). Die Boss-Figur selbst ist sehr stark, weil sie im Vorne-gegen-Vorne Runde für Runde eine Figur erledigt.
- ⚠️ **Simulation:** Mit den gewählten Werten (6/14 bzw. 4/30, Gefolge ×1,5) gewann der Bot 0 % der Runs. Mit den aktuellen Werten scheitern noch ~85 % der Bot-Runs, die den Akt-1-Boss erreichen. Menschliche Spieler sollten deutlich besser sein. Feinschliff nach Spieltests.

### Okkultisten (Vertical Slice)
| Name | Grundregel | Startfigur |
|---|---|---|
| **Der Wucherer** | Zinsen max. +7 statt +5, aber nur 6 Startgold statt 10 | Münzknecht |
| **Die Fechtmeisterin** | Start mit 4 statt 3 Plätzen, dafür keine Zinsen | Klingenlehrling |

*Profil:* Wirtschaft gegen Tempo. Die zwei Okkultisten ziehen das Zins-Dilemma in entgegengesetzte Richtungen.

---

## Kompakte Zusammenfassung
**Dark-Fantasy-Auto-Battler-Roguelite (Browser + Mobile, Querformat, Godot 4).** Als Okkultist stellst du ein Team aus bis zu 6 Tarot-Hofkarten-Figuren (Bube bis König, 4 Farben) in einer Reihe auf. Kämpfe laufen automatisch und deterministisch Schritt für Schritt ab (vorderste gegen vorderste, `(Angriff + Boni) × Mult`). Zwischen den Kämpfen: Gegnerwahl mit voller Vorschau, Shop (Gold + Zinsen), Ausrüstung mit gewürfelter Seltenheit, globale Relikte, Tarot-Karten, Seelen-Pakte, okkulte Ereignisse. Höhepunkt ist die **Fusion** (F1–F3, Meisterfähigkeit nach Farbkombination, geheime Rezepte). 8 Akte à 3 Kämpfe in 4 zufällig gereihten Tarot-Gebieten, Regel-Bosse, Endboss aus den Großen Arkana. **Eine Niederlage beendet den Run.** Ein Run dauert 30–45 Min. Meta: Freischaltungen über Herausforderungen, kleine Upgrades, Grimoire, Schwierigkeitsstufen. Optik: KI-generierter Tarot-Holzschnitt-Stil, Neon-Leuchten zeigt Seltenheit. Erstes Ziel: Vertical Slice im Münzen-Gebiet (2 Akte, 16 Figuren, 2 Okkultisten).

---

## Offene Fragen
- **M5 aufgeteilt:** M5a = Ausrüstung, Relikte, Tarot, Packs, Legendäre + Feedback unten · M5b = Seelen, Pakte, Ereignisse, Überspringen
- M5b-Feedback einholen, dann M6 (Fusion). **Mit M5a umgesetzt (Feedback zu v0.4.2):**
  - Umordnen: Wird eine Figur **zwischen** zwei Karten gezogen, wird sie dort eingeschoben (die anderen rücken). Nur wenn sie klar **auf** eine Karte gezogen wird, tauschen die beiden.
  - Plätze **nur noch durch Boss-Siege**, nicht mehr kaufbar
  - **Weniger Gold:** Grundeinkommen 5 → 4
- Balancing-Notiz (M9): Der Ertrunkene König gewinnt in der Zufallssimulation > 90 %
- Zum Prüfen in M5: Fluch-Lücke (kein Spieler/Gegner nutzt Fluch) über Ausrüstung/Relikte schließen

## Später entscheiden
- **Für den Inhaltsausbau nach dem Slice vorgemerkt (M5a-Feedback):** legendäre Ausrüstung, legendäre Reliquien, mehr Multiplikator-Relikte und -Fähigkeiten für das Endgame, ausgearbeitete Synergien, Blutpack (kostet Leben einer Figur statt Gold)
- **Seelen-Pack** (Pakte gegen Seelen) → M5b
- **Relikt „Heiligenschein“:** gibt einer Figur einen 2. Segen-Platz (Inhaltsausbau). Tarot-Regel bleibt: Kraft und Magier stapeln, Segen max. 1 pro Figur.
- **Schwierigkeit** erst nachjustieren, wenn alle Systeme (Relikte, Pakte, Fusion …) drin sind; gefühlt evtl. eine Nuance leichter
- **Spielname** (Kandidaten: Arcana Profana, Hofstaat der Asche, Die Verfluchte Hand)
- **Genaue Statusregeln und Zahlen** → Prototyp (Startpunkt steht in Phase 6)
- **Verderben-Zahlen** → Prototyp (Startpunkt: ab Zug 15, verdoppelnd)
- **Die 10 Meisterfähigkeiten** inhaltlich → Inhaltsrunden
- **Meta-Währung & Lager (Idee des Spielers, für M7):** Eine Währung, die man in Runs verdient und im **Lager** ausgibt, um dort Packs u. Ä. zu öffnen und dauerhaften Fortschritt für die nächsten Runs zu bekommen
- **Liste geheimer Rezepte und Anlässe** → Inhaltsphase
- **Seed-Eingabe/Teilen und Daily-Challenge** → nach dem Vertical Slice

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
| 2026-11-16 | Volle Wiederherstellung nach dem Kampf, Seelen für Fusion/Pakte/Shop, Boss-Überspringen kostet eine Figur, 3 Stufen mit +1/+1 und stärkerer Fähigkeit | Fair trotz Permadeath, klare Level-Ups | Gestorbene weg/verwundet; 5 Stufen, zweite Fähigkeit |
| 2026-11-16 | Fusion: 3 Stufen pro Figur, max. 3 Fähigkeiten + Meisterfähigkeit auf F3, Anlässe Altar/nach Boss/Item, geheime Rezepte/Anlässe/Meta-Freischaltung | Fusion als seltener Höhepunkt, Entdeckerfreude | Max. 3 pro Run; alle Fähigkeiten behalten, nur 2 |
| 2026-11-16 | Vorderste gegen vorderste, kein Grundzufall (nur über Fähigkeiten/Items), 4 Status je Tarot-Farbe, 4 Auslöser-Familien | Planbarkeit bei Permadeath, Zufall als bewusster Tausch | Alle greifen an, abwechselnd; Krits, Schadensspanne; keine/viele Status |
| 2026-11-16 | (Angriff + Boni) × Mult, Auslösung von vorne nach hinten, Statusregeln im Prototyp, Gleichstand = Sieg | Explosive Kurve à la Balatro, nachvollziehbare Reihenfolge | Nur additiv, seltene Mults; höchster Angriff zuerst, abwechselnd; Gleichstand = Niederlage/keine Belohnung |
| 2026-11-16 | Andere Ziele nur über Fähigkeiten, ~1 s pro Zug, Todesbildschirm mit Team/Statistik/Meta/Seed, Verderben im Prototyp | Pacing 24 Kämpfe in 30–45 Min., Lernen aus Niederlagen | Fernkämpfer-Klasse; 2 s, adaptiv |
| 2026-11-16 | Eigene Monster je Gebiet, Spieler-Figuren als Tarot-Hofkarten (Rang = Seltenheit), 16 Figuren im Slice, Generator mit thematischen Synergien | Starkes Thema, klare Seltenheit, durchdachte Gegner | Gleicher Pool, Mix; 56 Karten, freie Figuren; 12/24 Figuren; Konter-/Zufallsteams |
| 2026-11-16 | Slice = Münzen-Gebiet, 2 Akte; Gebiete zufällig gereiht; Figuren gemeinsam einzeln entwerfen | Wirtschafts-Synergien früh testen, maximale Mitsprache | 4 Akte, 8 Akte; feste/wählbare Reihenfolge; Vorschlag durch Claude |
| 2026-11-16 | 4 Objekt-Kategorien (Relikte, Ausrüstung, Tarot-Verbrauch, Pakte), 4 Seltenheitsstufen mit Nachteil, 1 Ausrüstung + 1 Segen-Slot pro Figur, keine Reserve | Balatro-Synergien plus Diablo-Würfelreiz, Knappheit | Nur Wertespannen, freie Affixe; 2 Slots; Reserve 3/6+ |
| 2026-11-16 | 3 globale Relikt-Slots + Segen-Slot pro Figur, Shop 3+2 mit Reroll, Gold mit Zinsen, 2 Tarot-Plätze | Balatro-Spar-Dilemma, Knappheit ohne Hortung | Nur an Figuren/nur global; getrennte/wachsende Shops; ohne Zinsen; sofort einsetzen |
| 2026-11-16 | Passive Okkultisten-Regel, Meisterfähigkeit nach Farbkombination, Gebiets-Segen, max. 3 Pakte | Entdeckerfreude bei Fusion, Anpassung an Gebiete | Aktive Rituale; dominante Farbe/Zufall; Umweltregel/nur Thema; unbegrenzte Pakte, 1 pro Gebiet |
| 2026-11-16 | Freischaltungen + kleine Upgrades, Schwierigkeitsstufen nach Sieg, exponentielle Gegner-Kurve, Meisterfähigkeit-Regel bestätigt | Langzeitmotivation ohne Balance-Bruch, Kurve knapp → explosiv | Nur Freischaltungen, großer Upgrade-Baum; wählbare/feste Schwierigkeit; lineare Kurve |
| 2026-11-16 | Freischaltung durch Herausforderungen, lokale Bestwerte, Grimoire mit Fusionen, Save-Scum verhindert | Ziele über Runs hinweg, Permadeath mit Gewicht | Erfahrungs-Freischaltung; Online-Rangliste; kein/einfaches Sammelbuch |
| 2026-11-16 | Links vs. rechts, Tippen → Detail-Panel, Drag & Drop + Tippen, Hinweise beim ersten Mal | Querformat nutzen, ein Bedienkonzept für Touch und Maus | Oben/unten; Long-Press; nur D&D/nur Tippen; geführter Run, kein Tutorial |
| 2026-11-16 | Rückgängig für den Shop + Abfragen bei unumkehrbaren Aktionen, saftiges Kampf-Feedback, 3 Barrierefreiheits-Optionen, minimales Menü | Permadeath ohne Fehlklick-Frust, explosive Power-Fantasy | Abfrage beim Kampfstart; schlichtes Feedback; Hub-Menü |
| 2026-11-16 | Gedeckte Basis + Neon nach Seltenheit/Macht, freie SFX + KI-Musik, ernst mit trockenem Humor, Deutsch + Englisch vorbereitet | Stärke auf einen Blick lesbar, solo machbar | Reine Paletten; alles KI/Audio später; poetisch/humorvoll; nur DE/EN |
| 2026-11-16 | Seltenheits-Leuchtsystem bestätigt, Musik pro Gebiet + Boss, statische Bilder + Code-Effekte, Name später | Stärke sofort lesbar, KI-Grafik-tauglich | Adaptive Musik, Hauptthema; Frame-Animationen |
| 2026-11-16 | Lokal + Export-Code, versioniertes JSON, deterministisch mit getrennten RNG-Strömen, 3 Statistik-Bereiche | Kein Server nötig, Bugs reproduzierbar | Nur lokal, Cloud; binär; einfacher Zufall; Run-Verlauf |
| 2026-11-16 | Baukasten-Effekte + Sonderskripte, headless Kampf-Simulation, Debug-Menü mit 4 Werkzeugen | Fusionen kombinieren sauber, Balancing per Simulation | Ein Skript pro Fähigkeit, reiner Baukasten; Simulation später |
| 2026-11-16 | JSON-Inhalte, Architektur-Paket (FSM, Commands, Event-Bus, Komposition, RNG-Ströme, GUT), Code komplett Englisch, GitHub Pages | Robust, testbar, Builds per Link spielbar | Tabellen, Godot-Ressourcen; deutsche Kommentare; itch.io |
| 2026-11-16 | Meilensteinplan M0–M9 bestätigt, Figuren vor dem Start entwerfen | Mechanik vor Inhalt vor Optik | Fusion früher, Grafik früher; Figuren parallel oder vor M4 |
| 2026-11-16 | Münzen: Münzknecht, Goldgepanzerter, Goldene Waage, König Midas | Spar-Build vs. Kaufen, Mult über Opfer | Pfandleiher, Zinseintreiber; Schildträger, Söldner; Schatzmeisterin, Herrin der Zinsen; Bankier, Goldener Koloss |
| 2026-11-16 | Stäbe: Funkenträger, Wutentbrannter, Herrin der Glut, Aschekönig | Brennen-Motor + Eskalation | Fackelknecht, Aschejunge; Brandreiter, Flammenwächter; Phönixin, Feuerpredigerin; Brandstifter, Flammenkönig |
| 2026-11-16 | Kelche: Messdiener, Bluttrinker, Kelch der Wiederkehr, Ertrunkener König | Sustain- und Opfer-Synergien | Fluchjunge, Opferlamm; Verfluchter Ritter, Seelenfänger; Hohepriesterin, Fluchweberin; Opferkönig, König der Flüche |
| 2026-11-16 | Schwerter: Klingenlehrling, Henker, Klare Klinge, Der Richter – alle 16 Spieler-Figuren stehen | Blutung aufbauen/auslösen, Konter gegen Schild | Messerwerfer, Duellant; Schattenklinge, Sturmklinge; Witwe der Klingen, Windtochter; Tausend Schnitte, Schwertkönig |
| 2026-11-16 | Gegner, Bosse und Okkultisten werden vor M0 gemeinsam einzeln entworfen. Gegner 1–4: Bettlergeist, Schuldeneintreiber, Wechsler, Gierschlund | Maximale Mitsprache | Set-Vorschlag durch Claude; Inhalte erst vor dem jeweiligen Meilenstein |
| 2026-11-16 | Gegner 5–8: Tresorwächter, Münzwerfer, Gieriger Drache, Spiegelmünze | Tank, Sniper, Opfer-Konter, Wildcard | Bankhalter, Kultist; Pfandmeister, Fluchpfennig; Golem, Steuerherr; Kassiererin, Bankrotteur |
| 2026-11-16 | Bosse: Steuereintreiber (Akt 1), Goldene Mauer (Akt 2). Okkultisten: Wucherer, Fechtmeisterin | Wirtschaft vs. Tempo, Konter gegen Spar-Builds | Geblendeter, Stummer; Eiserner Tresor, Umkehrer, Gleichgewicht; Aschenhexe, Totengräber |
| 2026-11-16 | M0: Godot 4.6.3, GL Compatibility, Web-Export ohne Threads, Pages-Workflow | Stabile Version, läuft in jedem Mobile-Browser | Godot 4.7 (sehr neu) |
| 2026-11-16 | Repo öffentlich, GitHub Pages über Actions aktiv | Kostenlose Test-Links per Handy | GitHub Pro, itch.io |
| 2026-11-16 | M0 abgenommen (läuft auf dem Handy). M1: deterministischer Kampf-Simulator, Kampfbildschirm mit 1×/2×/4×, 15 GUT-Tests (GUT 9.6.1 passend zu Godot 4.6), Simulationswerkzeug `tools/simulate.gd` | Logik headless testbar, Balancing per Simulation | GUT 9.7.1 (benötigt Godot 4.7) |
| 2026-11-16 | M1 abgenommen. M2: Fähigkeiten-Baukasten (24 Fähigkeiten, 4 Status, Multiplikatoren, Stufen), Detail-Panel per Tippen, 40 Tests | Alle Slice-Inhalte kämpfen mit echten Regeln | – |
| 2026-11-16 | M2-Feedback: Status als gezeichnete Embleme, Fähigkeiten fliegen als Emblem zum Ziel bzw. leuchten als Lichtkranz auf der eigenen Karte, Schwerter beim Zusammenstoß, Blutung = Dauerschaden für jede Figur (Stapel bleiben). Tempo und Regel-Präzisierungen bestätigt | Bessere Lesbarkeit, Blutung auch für hintere Figuren relevant | Kürzel; Blutung nur als Trefferbonus |
| 2026-11-16 | v0.2.2: größere Status-Embleme auf dunklem Untergrund, Spielfeld skaliert auf breiten Handys bis ×1,3, sichtbare Versionsnummer, `?seed=` in der Adresse spielt einen bestimmten Kampf nach, Cache-Busting beim Deploy | Nutzer sah Embleme nicht (zu klein und/oder alte Version im Browser-Cache) | – |
| 2026-11-16 | M2 abgenommen. M3-Details: Plätze nach Boss + kaufbar (6/8/10), Belohnung 1 aus 3 oder +2 Gold, Rang-Quoten mit 2 % König in Akt 1, Start mit zufälligem Buben + 10 Gold | Spar-Dilemma, frühe Glücksmomente | Nur kaufbar/nur Boss; nur Gold; keine Könige in Akt 1; leere Reihe |
| 2026-11-16 | M3: RunState (Gold, Zinsen, Shop, Neuwürfeln, Plätze, Leveln, Belohnung, Rückgängig), Budget-Gegnergenerator, Bildschirme Gegnerwahl/Planung/Belohnung/Run-Ende, Tippen + Drag & Drop, 63 Tests | Erster komplett spielbarer Mini-Run | – |
| 2026-11-16 | M3-Feedback: Schuldeneintreiber +1 Angriff je 10 Gold (einmalig zu Kampfbeginn), Startgold 8, Angriff rot / Leben grün, Verkaufsfeld statt Button (ziehen oder antippen), farbige Schlüsselwörter in allen Beschreibungen, Zwischenbildschirm beim Verschmelzen (EP-Balken, bei Stufenaufstieg Werte alt → neu). Bedienung, Schwierigkeit und Informationen bestätigt | Lesbarkeit, weniger Gold am Anfang | Zugbeginn-Varianten; Einkommen 4; Zinsen erst ab Akt 2 |
| 2026-11-16 | Symbole für Rang (Kappe/Helm/Krone), Farbe (Münze/Stab/Kelch/Schwert) und Stufe (Winkel) im Detail-Panel und auf Karten; Angriff als roter Zackenstern, Leben als grünes Herz mit Zahl in der Mitte. M3 abgenommen | Platzhalter-Symbole, werden in M8 verfeinert | – |
| 2026-11-16 | M4: thematische Gegner-Teams (3 Themen, Rollen-Aufstellung), Regel-Bosse Steuereintreiber (Gold im Kampf = 0, echtes Gold bleibt) und Goldene Mauer (7 Gegner-Plätze), Gebiets-Segen Münzen (+1 Schild für Münz-Figuren), Anzeige in Gegnerwahl/Planung/Kampf, Debug-Werkzeuge per `?debug=1` | Slice-Inhalte vollständig spielbar | – |
| 2026-11-16 | M4-Feedback: Boss ohne Gegnerwahl direkt nach dem Shop, Ankündigungs-Streifen zu Kampfbeginn, echte Boss-Figuren (2–3 Plätze breit), kein Verschmelzen auf Max. Stufe; Boss-Werte per Simulation stark abgeschwächt (Nutzerwahl war zu stark) | Bosse spürbar, aber schaffbar | Reine Regel-Bosse; Boss-Karte nur als Darstellung; Ankündigung beim Shop |
| 2026-11-16 | M4-Feedback 2: größere Karten/Schriften (Spielfeld skaliert nach Inhalt bis ×1,7), Gebiets-Einführung vor Gebietsbeginn, Glanz-Effekt für Königinnen/Könige ("Selten!"/"Episch!"), Verkaufen auf dem Belohnungsbildschirm, nachträgliches Verschmelzen durch Ziehen, Rangpreise 3/4/6/8, Verkauf = halber Preis + Stufe, Ertrunkener König 30/60/100 %, Steuereintreiber 12 Leben, fehlende Glyphen ersetzt, Schlüsselwörter nur als ganze Wörter. Boss-Grafik folgt in M8 | Lesbarkeit, Belohnungsgefühl, Balance | – |
| 2026-11-16 | v0.4.2-Feedback (Umsetzung mit M5): Einschieben zwischen Karten statt nur Tauschen, Plätze nur durch Bosse, weniger Gold. Rest bestätigt | Run war noch zu leicht, zu viel Gold für Verkaufen und Verschmelzen | Plätze kaufbar |
| 2026-11-16 | M5 in M5a/M5b geteilt; Objekt-Sets bestätigt; Objekte nur über Packs (Balatro), Figuren direkt; 4 legendäre Asse nur aus Packs (selten, Debug-Knopf), getrennt von Fusionsrezepten; Einkommen 4 | Glücksspiel-Reiz, seltene Highlights, knappere Wirtschaft | Direktkauf von Objekten; Legendäre = Fusionsrezepte |
| 2026-11-16 | M5a gebaut (v0.5.0): Packs (4 Typen × 3 Größen) mit Öffnen-Bildschirm, Ausrüstung mit Affixen, 8 Relikte, 6 Tarot-Karten, 4 legendäre Asse, Relikt-/Tarot-Leiste, Einschieben zwischen Karten, Plätze nur durch Bosse, Einkommen 4, Debug „Legendär-Pack“; 104 Tests | – | – |
| 2026-11-16 | M5a-Feedback: Hofstaat-Pack gestrichen, Legendäre nur in Arcana-Packs (1 %), polychromer Glanz + „Legendär!“, Verschmelzen/Verkaufen bei Belohnung und Pack-Öffnen, Blutungs-Tick mit aufsteigendem Tropfen. Blutung bleibt dauerhaft (Klarstellung) | Figuren nur gezielt im Shop, Legendäre als echtes Highlight | Hofstaat-Pack, Verfluchtes Pack, Omen-Pack |
| 2026-11-16 | v0.5.2: Goldene Waage → hinterste Figur, Relikt-/Tarot-Einflüsse als Symbole auf der Karte + goldene Werte bei Bonus + Liste im Detail-Panel, Brennen zählt sichtbar herunter („Brennen 3 -> 2“), Kampf-Tempo ×0,8. Brennen-Regel und Tarot-Stapeln bleiben | Nachvollziehbarkeit | Brennen dauerhaft; nichts/alles stapelt |
| 2026-11-16 | M5b-Inhalte: 8 starke Pakte mit milden Nachteilen, 8 Ereignisse (~40 %, Pity 3), stärkere Überspringen-Marken; Seelen-Quellen bestätigt | Pakte und Ereignisse sollen run-prägend sein | 4 schwächere Pakte, 6 schwächere Ereignisse, „2× gratis würfeln“ |
| 2026-11-16 | M5b gebaut (v0.6.0): Seelen (Boss, Opfer, Tod, Seelenhunger), 8 Pakte inkl. Seelen-Pack im Shop, Pakt-Leiste, 8 Ereignisse (40 %, Pity 3, eigener Bildschirm, Duell-Kampf), Überspringen mit Marken, Boss-Überspringen per Opfer, Debug „Ereignis“/„+5 Seelen“; 129 Tests | – | – |
| 2026-11-16 | M5b-Feedback (v0.6.1): Gegneroptionen mit unterschiedlichen Gegnern, Magier-Erfahrungsbildschirm, Schwarzmarkt als Händler-Mantel mit Fächern, Ausrüstung schwächer und klarer beschriftet (Grundwirkung/Zusatz/Nachteil), Vergleich beim Ausrüsten, Tarot rückgängig, Neu würfeln nur Figuren, Tränenquelle 1×, Relikt-Symbole auf Karten entfernt, Kampf-Tempo ruhiger, Drag & Drop aus Packs/Markt, Spiegelkammer repariert, max. 2 Objekte pro Figur, Seelen knapper, Rad bleibt, Pakte nicht verkaufbar, keine weiteren Seelen-Käufe | Lesbarkeit, Balance gegen Stapeln | Seelen-Ritual, Seelen-Würfeln, Pakte auflösen |
| 2026-11-17 | v0.6.2: Alle Ereignisse als eigene Szene (Themenfarbe, großes Emblem, ein Fach pro Angebot mit Beschreibung, Kosten, Wählen-Knopf; Duell zeigt das Champion-Team). Verfluchter Brunnen hielt sich nicht an die Seltenheit (10 Gold gab 3 Zusätze) → jetzt 3 Gold magisch, 6 Gold selten, 10 Gold Wahl 1 aus 3 seltenen. Ausrüstung allgemein: Zusätze wiederholen sich nicht und doppeln nie die Grundwirkung (Fackel ohne Extra-Brand); Test prüft alle Seltenheitsregeln | Feedback: Ereignisse besser darstellen, seltene Fackel mit 3 Zusätzen | – |
| 2026-11-17 | v0.6.3: Neue Seltenheit **Einzigartig** (nur Verfluchter Brunnen, 10 Gold, 2,5 % Chance, dass eine der 3 Auswahlen einzigartig ist): Grundwirkung + 2 Zusätze + 1 einzigartiger Effekt, türkis-silberne Farbe, Strahlenglanz, Tag „Einzigartig!“. **Geheim:** Weder der Brunnen noch eine Beschreibung erwähnt die Chance. Pool: Phönixfeder (stirbt der Träger: 1× pro Kampf zurück mit halbem Leben), Blutdurst (heilt 50 % des verursachten Schadens), Kriegsherr (×1,5 Angriff), Seelenernte (Kill durch Angriff des Trägers: 15 % +1 Seele). Debug-Knopf „Unikat“ | Spieler-Wunsch: seltener besonderer Effekt beim Brunnen | 5/10/15 % Chance, Regenbogen-Glanz, Effekt ersetzt Zusatz |
| 2026-11-17 | v0.6.4: Einzigartige Gegenstände bleiben eine geheime Belohnung (kein Hinweis im Brunnen). Ausrüstungs-Texte kürzer: Karte zeigt nur den Seltenheits-Namen, „Basis“ statt „Grundwirkung“, kurze Effekttexte („Nach Angriff: Brennen 1“), Unikat-Zeile „Einzigartig: Name – Wirkung“ | Feedback: geheim halten, kürzer, Unikat trotzdem erklären | – |
| 2026-11-17 | v0.6.5: Überspringen-Marke gibt 2 garantierte Ritter statt Königinnen/Könige; Rad des Schicksals wieder mit knapper Beschreibung; Goldgepanzerter erhält zu Kampfbeginn Schild 1 pro 4/3/2 Gold statt Leben | Feedback: Marke zu stark, Text zu lang, Rüstung passt besser | Marke mit Rittern oder Königinnen |
| 2026-11-17 | M6 Runde 1: Fusionswerte zurückhaltend, Neustart auf Stufe 1, Fusion zählt für alle enthaltenen Farben, geheime Rezepte und Anlässe direkt in M6 | Luft nach oben, Mischteams stärken | Summe + Bonus; höchste Stufe übernehmen; Geheimes erst mit M7 |
| 2026-11-17 | M6 Runde 2: Fusion = Höchstwerte + 1/1, Leveln nur über Kampfsiege/Magier, Altar 2/3/4 Seelen, Ritualkerze selten in Arcana-Packs (+ Schwarzmarkt) | Zurückhaltende Werte, Seelen knapp | Hauptfigur + halber Partner; Duplikate; 1/2/3 oder fix 3; nur Schwarzmarkt/Ereignisse |
| 2026-11-17 | M6 Runde 3: 2 geheime Rezepte, Blutmond = doppelte Fusion, Meister Münzen+Münzen Goldene Mauer, Stäbe+Stäbe Feuerspringen | Entdeckerfreude, Spar-Build-Krönung, Feuer-Kettenreaktion | 1/4 Rezepte; Blutmond ohne Fähigkeitsgrenze/behält Stufe; Zinsmacht, Kriegskasse; Ewiges Feuer, Feuersturm |
| 2026-11-17 | M6 Runde 4: Kelch+Kelch Tränenmeer, Schwert+Schwert Durchbohren, Münz+Stab Goldglut, Münz+Kelch Überfluss | Klare Identität je Kombination | Lebensquell, Seelenschlucker; Blutbad, Richtschwert; Brennende Münzen, Feuersold; Totengeld, Kirchenzehnt |
| 2026-11-17 | M6 Runde 5: Münz+Schwert Bezahlte Klinge, Stab+Kelch Dampfwolke, Stab+Schwert Glühhieb, Kelch+Schwert Aderlass – alle 10 Meisterfähigkeiten stehen | – | Kopfgeld, Schuldschnitt; Heißer Quell, Siedepunkt; Schmiedefeuer, Brandwunde; Opferklinge, Blutrausch |
| 2026-11-17 | M6 Runde 6: Rezepte Waage des Midas und König aus Asche und Flut, endgültig, Hinweis „???“ am Altar; Umsetzungsplan M6 erstellt | Entdeckerfreude mit sanftem Hinweis | Goldener Koloss, Schatzwächter; Wiedergänger, Vampirfürst; Rezept als F1; Wahrsagerin/kein Hinweis |
| 2026-11-17 | M6 umgesetzt (v0.7.0): Fusion F1–F3 mit Fähigkeitswahl, 10 Meisterfähigkeiten, 2 geheime Rezepte, Fusions-Altar, Gratis-Fusion nach Akt-Boss, Ritualkerze (Arcana-Packs, Schwarzmarkt), Blutmond; reine Kombination ab 3 gleichen Farben; Überfluss teamweit | Plan freigegeben | – |
| 2026-11-17 | v0.7.1: Fusionsname aus beiden Namen (Partner-Teil + Hauptfigur-Teil), max. 2 behaltene Fähigkeiten, Ereignisse höchstens 1 pro Akt (50 % nach jedem Kampf, keine Garantie mehr) | Feedback: Namen, zu viele Fähigkeiten, Ereignisse zu häufig | Titel nach Farben, Fantasienamen; 20 % ohne Garantie, fest 1 pro Akt |
| 2026-11-17 | Fünf Designrichtungen ausgearbeitet (docs/designrichtungen.html): 1 Das Alte Blatt (Holzschnitt, umgekehrte Karten), 2 Neon-Séance (CRT, Ekstase-Mult), 3 Lebendes Grimoire (Buch, Siegel-Schrift), 4 Totentanz-Theater (Marionetten, Rampenlicht + 1 Eingriff), 5 Astrolabium (Sternenring, Konstellationen + Planetenstunde) | Auf Wunsch zur Auswahl vor M7/M8; nichts davon gebaut | – |
| 2026-11-17 | Figuren & Kampfbühne: Seitenansicht, 64-px-Pixelkunst von Claude im Code (später ersetzbar), Gliederpuppen-Animation, Karten nur in Shop/Planung, minimale Werteanzeige, Pixel-Landschaften, Bewegung je Waffe, Tod je Farbe, Körper nach Rang, Fusionsgestalt mit erkennbaren Teilen, Gegner als Kreaturen mit riesigen Bossen, düster mit leuchtenden Effekten, Tempo ×1/×2/×3 + Überspringen | Spieler will echte Figuren statt Karten; ersetzt KI-Holzschnitt-Planung | 5 Designrichtungen; Isometrie/Frontal; handgemalt/3D/Comic; Einzelbild-Animation; KI-Bilder vom Spieler, Asset-Pakete |
| 2026-11-17 | Fünf Pixel-Stilproben (docs/stilproben.html, animiert): 1 Heraldik (Wappenrock, Rang per Kopfbedeckung, Seltenheit als Borte), 2 Okkulter Orden (Roben, Rang = kreisende Siegel, Seltenheit = Bannkreis, Nebel-Aura), 3 Söldner (Rang = Rüstung, Seltenheit an der Waffe), 4 Prunk & Reliquie (Seltenheit = Material, Rang = Umhang/Krone, Glitzer), 5 Schattengestalten (Silhouette mit Lichtkante, Rang = schwebende Karte, Seltenheit = Heiligenschein, Rauch) | Auswahl vor Schritt 1 der Kampfbühne | – |
| 2026-11-17 | Stil Prunk & Reliquie gewählt: Material nach Rang, Fusion obendrauf, Schillern nur bei Rezepten, Funkeln nur F3/Rezepte, nur besondere Gegenstände verändern das Aussehen | Seltenheit soll erst mit Fusion/Rezepten den Höhepunkt erreichen | Heraldik, Okkulter Orden, Söldner, Schattengestalten; Material nur nach Stufe/Fusion; Ausrüstung immer sichtbar |
| 2026-11-17 | Kampfbühne Schritt 1 (v0.8.0): Seitenansicht-Pixelbühne (300×130, scharf hochskaliert) in der Schatzkammer mit Kerzen und Staub; alle Figuren und Gegner als Gliederpuppen im Stil Prunk & Reliquie (Material nach Rang, Edelstein nach Farbe, Waffe nach Farbe/Rang), Gegner als verderbte Bronze-Gestalten bzw. Geister, Bosse riesig; Nahkämpfer laufen zur Mitte, Fernkämpfer werfen; Treffer-Blitz und Rückstoß; Status am Körper (Feuer, Blut, Fluchschleier, Schildschale); Tod je Farbe; Reihen rücken nach; dünne Lebensbalken, Details per Antippen; Tempo 1×/2×/3× gespeichert + Überspringen; Testarena per ?arena=1 | Schritt 1 des Plans | – |
| 2026-11-17 | v0.8.1: Angriff/Leben als Zahlen unter den Figuren, Status-Symbole mit Stapelzahl, Wiederbelebung (zusammensacken, Lichtstrahl, Aufstehen), Gegner als eigene Kreaturen, breite Kreaturen bekommen mehr Platz | Feedback zu Schritt 1 | – |
| 2026-11-17 | Fünf Shop-Vorlagen (docs/shopvorlagen.html): 1 Händlertisch (Messingschilder, Wachssiegel-Kampf, Verkaufsfeuer), 2 Tarot-Legung (Karten auf Samt, Wachssiegel), 3 Schatzkammer-Regal (Nischen, Pixel-Steinknöpfe), 4 Reliquienschrein (Spitzbögen, Fensterrose als Kampf-Knopf), 5 Klar & Kompakt (Felder, große flache Knöpfe) | Auswahl für die Shop-Überarbeitung | – |
| 2026-11-17 | Eigenes Design je Figur/Monster passend zu Name und Fähigkeit (Goldgepanzerter-Rüstung wächst mit Gold, Henker mit Axt und Kappe, Midas mit goldener Hand); Meta-Währung + Lager vorgemerkt für M7; Shop-Stil Tarot-Legung gewählt, Verkaufsfeld nur beim Gedrückthalten | Spieler-Feedback | Händlertisch, Schatzkammer-Regal, Reliquienschrein, Klar & Kompakt |
| 2026-11-17 | v0.8.2: Shop im Stil Tarot-Legung umgesetzt: Samt-Hintergrund, Karten als Pergament-Tarotkarten mit animierter Pixel-Figur (Gegner auf dunklem Tuch), Preise als Gold-/Seelenmünzen über den Karten, Packs als verdeckte Karten, Wachssiegel-Knöpfe (Neu würfeln gold, Rückgängig grau, Kampf groß rot); Verkaufsfeld erscheint nur beim Ziehen/Gedrückthalten oder bei Auswahl einer Figur bzw. eines Relikts | Shop-Wahl des Spielers | – |
| 2026-11-17 | v0.8.3: Positiv beeinflusste Angriffs-/Lebenswerte gelb (Kampf und Karten); Figuren in Ereignissen verschiebbar, außer beim Grabräuber (nimmt die hinterste Figur); Preis-Münzen liegen nicht mehr über Infofenstern; Verkaufsfeld unten rechts; Gegneroptionen nach echter Stärke geordnet (schwerste = Schwer, Schwer bevorzugt teure Gegner); weniger Königinnen/Könige im Shop (Akt 1: 76/20/3/1 %); Wutentbrannter: wenn getroffen erhält der Angreifer Brennen 1/2/3; erstes Boss-Gefolge kleiner (Budget 1) | Spieler-Feedback | – |
| 2026-11-17 | v0.8.4: Ereignis-Bildschirme teilen die Höhe zwischen Szene und eigener Reihe (Figuren deutlich größer), größere Schrift in den Angeboten; Karten insgesamt größer (112×164, größere Namen, Werte und Symbole); Ausrüstung und Segen im Kampf per Antippen sichtbar; „Nach dem Angriff“-Fähigkeiten wirken auch, wenn der Angreifer im selben Schlagabtausch fällt (gleichzeitige Treffer); Funkenträger Brennen 2/3/4 | Spieler-Feedback | Funkenträger mit mehr Leben |
| 2026-11-17 | Kampfbühne Schritt 2 (v0.9.0): Eigenes Design für alle 16 Hofkarten, 4 Asse und 2 Rezept-Figuren (z. B. Münzknecht mit Lederweste und Geldbeutel, Goldgepanzerter mit Goldrüstung, die mit dem Gold von schlank bis massiv mit Stacheln wächst, König Midas mit goldenem Gewand, goldener Hand und Goldapfel, Funkenträger mit Kapuze und Fackel, Wutentbrannter mit Flammenhaar und Keule, Herrin der Glut mit Flammenkrone und Glutstab, Aschekönig mit Aschekrone und Flammenschwert, Messdiener in Leinen mit Weihrauchfass, Bluttrinker bleich mit Kelch und Vampirkragen, Kelch der Wiederkehr mit Schleier, Ertrunkener König mit Seetangkrone und Dreizack, Klingenlehrling mit Stirnband und Wurfmessern, Henker mit schwarzer Kapuze und Axt, Klare Klinge mit Federhut und Rapier, Richter mit Perücke und Zweihänder; Asse als Geister ihrer Farbe mit Heiligenschein); Fähigkeits-Effekte als Pixel-Geschosse und Funken in der Farbe der Wirkung; Spezialangriff-Szene (Abdunkeln, Kamera-Zoom, Name groß) für Könige, Asse, Rezept-Figuren, Bosse und Meisterfähigkeiten, einmal pro Figur und Kampf; Vorschau-Werkzeug tools/render_figures.gd | Schritt 2 | – |
| 2026-11-17 | v0.9.1: Neu würfeln kostet 5 Gold (+1 je Wurf), neue Überspringen-Marke „2× gratis neu würfeln“, Relikte zum Verbilligen vorgemerkt; eigene Truppe in Gegnerauswahl und Run-Ende zeigt beim Antippen alle Infos (Ausrüstung, Segen, Fusion, Relikt-Wirkungen); Oberkategorien überall in fester Farbe (Ausrüstung hellstahl, Segen gold, Tarot violett, Relikt türkis, Pakt rot, Fähigkeit bernstein) mit Kategorie-Schild auf Objektkarten und farbigen Labels im Info-Fenster; Seltenheit als Farbe des Ausrüstungs-Symbols auf der Karte und farbiger Seltenheitsname | Spieler-Feedback | Reroll 3 Gold; Seltenheit als Sterne |
| 2026-11-17 | v0.9.2: Aschekönig verursacht selbst Brandschaden: „Nach dem Angriff: Ziel erhält Brennen 3“ (fest, zusätzlich zu Brennen-Weitergabe und Angriffs-Multiplikator) | Spieler-Feedback | Brennen nach Stufe 2/3/4 |
| 2026-11-17 | Fusionsgestalten: Körper von der Hauptfigur + Waffe/Extras vom Partner, Größe + Aura je Stufe, Teile behalten Farben; reine Fusion mit Farbsymbol und eigener Meisterfähigkeit (Goldene Festung, Glutkern, Ewige Quelle, Hinrichtung), ersetzt die alten reinen Meister | Spieler-Wahl | Hälften, Chimäre; nur Aura, Insignien; Mischpalette, Meisterfarbe; Königsschatz, Münzregen, Feuersturm, Phönixflamme, Flut der Gnade, Seelenkelch, Klingenwirbel, Blutrausch |
| 2026-11-17 | v0.10.0 umgesetzt: Fusionsgestalten (Körper der Hauptfigur, Waffe/Schild/Schmuck des Partners in dessen Metall und Edelstein, Umhang des 3. Teils in dessen Farbe, Schild/Schmuck des 4. Teils), pro Stufe größer, Aura aus aufsteigenden Funken in den zwei Hauptfarben plus Bodenschein, reines Farbsymbol über dem Kopf; 4 neue reine Meisterfähigkeiten; Arena (?arena=1) zeigt zufällige Fusionen; Vorschau-Werkzeug tools/render_fusions.gd | Plan freigegeben | – |
| 2026-11-17 | Feedback v0.10.0: Fusionsgestalten fürs Erste gut, Feinschliff (z. B. mehr Partner-Teile wie Kopfbedeckung/Haut) kommt später | Spieler-Feedback | – |
| 2026-11-17 | M7-Planung: Seelenglut aus übrigen Seelen (abnehmende Staffel, max. 12/Run), Krypta-Lager mit Themen-Truhen (8), Upgrades 25/50/90, Okkultisten per Herausforderung oder Kauf, Novize als Start, Kern frei/Seltenes gesperrt, Duplikate → Seelenglut, Optik inkl. Skins, Hauptmenü + Autosave + Grimoire | Spieler-Wahl | Währung aus Run-Fortschritt; Kurs pro Akt; Misch-Pack; keine Duplikate; alles frei/stark gesperrt; zäher/sehr zäher Grind; Wagen/Bibliothek |
| 2026-11-17 | M7 umgesetzt (v0.11.0): Hauptmenü (Fortsetzen / Neuer Run / Krypta-Lager / Grimoire), Okkultisten-Wahl (Novize, Wucherer, Fechtmeisterin), Autosave nach jeder Aktion in user://run.save, Meta-Speicher user://meta.json, Seelenglut am Run-Ende mit Staffel, Krypta-Lager (Truhen, Altar, Bildnisse, Spiegel) vor dem Pixel-Gewölbe, Grimoire mit 7 Reitern und ???, Optik: 3 Kartenrücken, 3 Hintergründe (Schatzgewölbe, Zerfallene Kathedrale, Mondfriedhof), 3 Aura-Stile, 4 Figuren-Skins; Menü-Knopf ≡ im Run; Debug „+50 Seelenglut“ im Menü | Plan freigegeben | – |
| 2026-11-17 | Skins neu: Seltenheitsstufen, 4 legendäre Vorzeige-Skins (Höllenhenker, Frostkönig, Sternenrichter, Sonnenkönig Midas) je 100 Seelenglut mit Dauer-Effekt, eigener Waffenspur/Treffern, eigenem Tod und eigener Spezial-Szene, sichtbar in Kampf und auf Karten, Vorschau vor Einbau | Feedback: Skins zu unauffällig | Nur Teile / nur Effekte; alle legendär; nur Herausforderungen; 8/16 Skins; 40/60 Seelenglut |
| 2026-11-17 | v0.12.0 (Vorschau): 4 legendäre Skins gebaut – Höllenhenker (Stachelhelm mit Lava-Zacken, Lava-Risse, Höllenaxt, Flammen + Glut), Frostkönig (Eiskrone, Eisdreizack, Schneeflocken, Frostatem), Sternenrichter (Sternenkapuze, Sternenrobe, Leerenklinge, kreisende Runen), Sonnenkönig Midas (Strahlenkrone, Lichtflügel, Prunkrüstung, Sonnenzepter, Strahlenkranz); je eigene Hieb-Spur, eigener Tod, eigene Spezial-Szene; Kartenrahmen in Themenfarbe; ersetzen die 4 einfachen Skins; Vorschau-Arena ?arena=1&skins=1 | Plan freigegeben | – |
| 2026-11-17 | v0.12.1 (Feedback): Gegnerwahl mit festen Stärke-Abständen (Mittel ≥ 1,3 × Leicht, Schwer ≥ 1,3 × Mittel, Schwer immer mind. 2 Gegner); Grimoire als Bildkarten (Figuren/Gegner animiert, Objekte als Karten, Meister mit Farbsymbolen), Antippen zeigt Beschreibung, mit ?debug=1 komplett sichtbar; Seelenglut-Anzeige in der Run-Leiste und „+50 Glut“-Testknopf im Run; Waffen werden hinter dem Kopf gezeichnet und leicht nach vorn geneigt, damit sie keine Gesichter verdecken; Menü-Knopf im Run | Spieler-Feedback | Schwer = mehr Gegner; Elite-Gegner; Buchseiten |
| 2026-11-17 | v0.12.2: Debug-Werkzeuge passten nicht mehr in die obere Leiste – jetzt ein „Debug“-Knopf oben rechts, der die Werkzeuge als Spalte aufklappt (bleibt offen, schließt im Kampf) | Spieler-Feedback | – |
| 2026-11-17 | v0.13.0: Objekt-Plätze pro Figur (Ausrüstung, Segen, Kraft-Tarot frei gemischt) wachsen: neue Figur 1 Platz, ab Stufe 3 2 Plätze, jede Fusionsstufe +1, max. 3 (Ereignis-Boni obendrauf); Anzeige „Objekt-Plätze x / y“ nur im Info-Fenster; Objekte des Partners gehen bei Fusion weiter verloren | Feedback: alles auf eine Figur zu stark | Feste Platz-Typen; Plätze nach Rang; Schloss-Symbole auf Karten; Objekte bei Fusion auswählen |
| 2026-11-17 | v0.14.0: Pack-Animationen – Pack wackelt, reißt mit Blitz auf, Karten fliegen verdeckt heraus, leuchten/zittern in Seltenheitsfarbe (legendär regenbogen), Antippen dreht um (Funken, ab Episch Blitz + Wackeln), „Alle aufdecken“; gilt für Shop-/Ereignis-Packs im Run und Truhen im Lager (Funde mit „neu!“/„doppelt“); legendäre Skins: schwarzer Bildschirm, Lichtsäule in Themenfarbe, Funkenexplosion, Themen-Wetter (Feuerregen, Schneesturm, Sternenfeld, Goldregen), große Figur führt Spezialangriff vor, „LEGENDÄR“ + Name + Spezialname; Kauf-Feier („Freigeschaltet!“ mit Strahlen) für Altar, Spiegel und Okkultisten (größer) | Spieler-Wahl | Automatisch aufdecken; Truhe mit Deckel; keine Andeutung; Wackeln |
| 2026-11-17 | v0.14.1: Legendäre Skins aus der Figuren-Truhe zeigen die große Enthüllung jetzt immer – auch wenn der Skin schon besessen wird (dann mit „doppelt, +2 Seelenglut“); Test für die Enthüllung aus Truhen | Feedback: Spezialeffekt in Figuren-Truhen fehlte | – |
| 2026-11-17 | v0.14.2: Legendäre Skins seltener – in der Figuren-Truhe 1 % pro Karte (vorher 5 %), im Spiegel 250 Seelenglut (vorher 100) | Feedback: 5 % zu oft | 2 %, 0,5 % |
| 2026-11-17 | Projekt-Skills in .claude/skills angelegt: deploy (Tests, Version, Log, Push, Actions verfolgen), browser-check (lokaler Build, Playwright-Sequenzen, bekannte Tipp-Koordinaten), new-content (Checkliste für Figuren, Gegner, Objekte, Meister, Skins); Sicherheitsprüfung: keine Zugangsdaten, nur lesender GitHub-API-Zugriff, lokaler Server nur auf 127.0.0.1, keine Downloads, nicht im Spiel-Build enthalten | Wiederkehrende Abläufe festhalten | Fremde Skills aus öffentlichen Sammlungen |
| 2026-11-17 | v0.15.0: Pixel-Art-Stil-Skill (.claude/skills/pixel-art) mit 11 Stilregeln und Prüfschleife; handgezeichnete Pixel-Raster (scripts/ui/stage/handmade_art.gd) als Test an 3 Vorzeige-Figuren: Henker (Kapuze mit Sehschlitz und roten Augen, Muskeln, Gurt, Blutschürze, große Henkersaxt), König Midas (Edelsteinkrone, weißer Bart, Pelzkragen, Robe mit Smaragdborte), Schuldeneintreiber (Monokel, Schreibfeder am Zylinder, Goldknöpfe, Uhrkette, Rockschöße); kleine Handgegenstände (Goldapfel, Beutel, Kelch) wieder vor dem Arm; Skins/Fusionen nutzen weiter die gezeichneten Teile | Plan: erst 2–3 Vorzeige-Figuren zum Vergleich | Fremde Design-Skills |
| 2026-11-17 | v0.15.1: Feste Regel „Waffen verdecken nie ein Gesicht“: der Kopf wird immer zuletzt gezeichnet, über jeder Waffe und jedem Handgegenstand, auch beim Angriff; Test prüft alle Figuren; Regel im Pixel-Art-Skill festgehalten | Spieler-Vorgabe | – |
| 2026-11-17 | v0.16.0: Pixel-Art-Quellen als Textdateien unter art/ (eine pro Figur/Gegner/Symbol, gemeinsame Farben in art/_common.txt), Werkzeug tools/build_handmade.py erzeugt handmade_art.gd; Etappe 1 neu gezeichnet: Münzknecht, Goldgepanzerter, Goldene Waage, Funkenträger, Wutentbrannter, Herrin der Glut, Aschekönig (Köpfe) | Spieler: alle Figuren, Skins, Gegner, Relikt- und Tarot-Symbole neu zeichnen | – |
| 2026-11-17 | v0.17.0: Etappe 2+3 neu gezeichnet – Messdiener, Bluttrinker, Kelch der Wiederkehr, Ertrunkener König, Klingenlehrling, Klare Klinge, Richter, 4 Asse (mit Heiligenschein), Waage des Midas, König aus Asche und Flut, 4 legendäre Skins (eigene Köpfe); Fusionen behalten Kopf und Rumpf der Hauptfigur in Handarbeit | Spieler: alles neu zeichnen | – |
| 2026-11-17 | v0.18.0: Etappe 4 – alle 8 normalen Gegner und beide Bosse neu gezeichnet (Bettlergeist mit Schale, Münzwerfer mit Sack, Wechsler mit Doppelmaske, Gierschlund als Mimic mit Zunge, Tresorwächter mit Tresortür, Drache auf Goldhaufen, Spiegelmünze mit Flügeln, Steuereintreiber als Kröten-Fürst mit Monokel und Schuldbuch auf Geldsäcken, Goldene Mauer mit Glutmaul und Ketten); Skizzen-Skripte unter tools/art_sketches | Spieler: alles neu zeichnen | – |
| 2026-11-17 | v0.19.0: Eigene handgezeichnete Symbole (16×16) für alle 8 Relikte, 6 Tarot-Karten und die Ritualkerze – auf Objektkarten, in Relikt-/Tarot-Leisten, Packs und Grimoire; damit sind alle Figuren, Skins, Gegner, Bosse, Relikte und Tarot neu gezeichnet | Spieler: alles neu zeichnen | – |
| 2026-11-17 | v0.20.0: Neue Symbole für alle 8 Pakte und 6 Ausrüstungsarten; handgezeichnete Rümpfe mit eigenen Details für 14 Hofkarten (z. B. Brandflecken beim Funkenträger, Narben und Flammen-Tätowierung beim Wutentbrannten, glühende Risse in der Aschen-Rüstung, Seetang und Muscheln beim Ertrunkenen König, Messergurt beim Klingenlehrling, Goldkette beim Richter); Skript tools/art_sketches/bodies.py | Spieler: alles neu zeichnen | – |
| 2026-11-17 | v0.21.0: Arme und Beine aller Figuren handgezeichnet (Ärmel/Stulpen/Manschetten, Hände, Hosen, Stiefel mit Sohle, je Figur eigene Details wie Flammen-Tätowierung, Glutgelenke, Seetang, Wurfmesser am Handgelenk, goldene Hand bei Midas); 4 legendäre Skins, 4 Asse und beide Rezept-Fusionen komplett neu (Rumpf, Arme, Beine); Skript tools/art_sketches/limbs.py | Spieler: Arme/Beine, Skins und besondere Fusionen überarbeiten | – |
| 2026-11-17 | Kartendesign nach Seltenheit: Rahmen-Material nach Rang, getönter Hintergrund mit gestaffelten Motiven, verfluchte Gegnerkarten nach Kosten, verflochtene Fusionsrahmen, Stufe als römische Ziffer, Rang-/Gegnersymbole nur im Info-Fenster | Spieler-Wahl | Leuchtrand; rote Kopie/Steckbrief; einheitlicher Hintergrund, Szenerie/Muster; Edelsteine/Sterne; Fusion wie bisher |
| 2026-11-17 | v0.22.0 umgesetzt: Pixel-Kartengesichter (scripts/ui/card_art.gd) – Rahmen Holz/Eisen mit Nieten/Silber mit Ornamenten/Gold mit Edelsteinen/Legende mit leuchtenden Edelsteinen auf Sternenhimmel, getöntes Pergament mit Farb-Wasserzeichen und gestaffelten Motiven (Bordüre, Ranken, Strahlenkranz), Gegner auf rissigem dunklem Pergament mit Rost-/Dornen-/Knochen- und Blut-Rahmen, Bosse mit Totenköpfen und roten Augen, Fusionen mit geflochtenem Rahmen; Stufe als römische Ziffer im Wachssiegel zwischen Angriff und Leben, F-Stufe darüber; Rang-, Farb- und Gegnersymbole nur noch im Info-Fenster | Plan freigegeben | – |
| 2026-11-17 | Kartendesign v2 (Feedback): kein Name mehr auf Karten (nur Info-Fenster), oben mittig nur das Stufen-Siegel; Seltenheit klar über Farbe + Glanz + Polychrom gestaffelt (Bube schlicht bronze, Ritter blau mit Metallglanz, Königin violett mit wanderndem Glanzstreifen, König Gold mit Glanz und Funkeln, Ass/Legende polychrom animiert); besondere Karten: Asse, Rezept-Fusionen, normale Fusionen (Glanz je Stufe), legendäre Skins (Themenfarbe); Objektkarten im gleichen Stil (Ausrüstung nach Seltenheit, Relikt/Tarot/Pakt in Kategoriefarbe); Ornamente/Ranken entfallen | Spieler-Feedback | Rang als Schriftband/Symbol; nur Farben; nur Glanz |
| 2026-11-17 | v0.23.0 umgesetzt: Kartendesign v2 – Namen nur im Info-Fenster, Stufen-Medaillon oben mittig in der Seltenheitsfarbe; klare Farbstufen mit Shader-Effekten (card_shine.gdshader: Glanzstreifen, Funkeln, Polychrom): Bube Bronze, Ritter Blau (Glanz), Königin Violett (Glanz), König Gold (Glanz+Funkeln), Ass polychrom auf Sternenhimmel, Rezept schwarzgold mit Zauberkreis und starkem Polychrom, Fusion geflochtener Rahmen mit Glanz je Stufe (F3 polychrom), legendärer Skin in Themenfarbe; Objektkarten im gleichen Stil (Ausrüstung nach Seltenheit, einzigartig türkis-polychrom; Relikt türkis, Tarot violett, Pakt rot); Gegner verflucht | Spieler-Feedback | – |
| 2026-11-17 | v0.23.1: Tarot-Karten im eigenen Arkana-Design (Mitternachtshimmel, goldener Bogen um das Bild, doppelter Goldrahmen, Nummer der großen Arkana oben); Meister-Karten im Grimoire polychrom; Objektkarten etwas höher mit kompakterer Schrift, damit kein Text über den Rand läuft; Prüfung von Grimoire (alle Reiter), Gegnerwahl, Shop, Pack-Öffnung, Pack-Auswahl, Info-Fenster, Ereignissen und Blutmond | Spieler: Tarotkarten auch, alles zueinander passend | – |
| 2026-11-17 | v0.24.0: Gegnerkarten im gleichen Kartenaufbau, aber verflucht statt glänzend – blutrotes rissiges Pergament, Totenkopf-Wasserzeichen, Totenköpfe mit glühenden (pulsierenden) Augen am Rahmen (Stufe 1: einer, Stufe 2: drei, Stufe 3: alle Ecken mit Blut, Bosse große Totenköpfe) und aufsteigender Rauch mit Glut (card_curse.gdshader), stärker je Gegner; Tarot-, Relikt- und Pakt-Texte auf dunkler Textplatte mit heller Schrift | Spieler-Feedback | – |
| 2026-11-17 | v0.24.1: Tarot-Karten mit festen Bereichen – Nummer und Bild im Tor, Name auf eigenem Namensschild (schrumpft bei langen Namen), Text in eigenem umrandetem Feld darunter; keine Überschneidung mit Linien | Spieler-Feedback | – |
| 2026-11-17 | v0.24.2: Skin-Karten ruhiger (neutraler dunkler Hintergrund, Themenfarbe nur im Rahmen, leichter Glanz); Karten-Leuchten (Skins, Fusionen) liegt jetzt hinter der Karte statt als Schleier darüber; Gegnerkarten auf staubig-blutrotem Mittelton statt Schwarz, ohne Totenkopf-Wasserzeichen hinter dem Monster, für mehr Kontrast | Feedback: Skins zu stark leuchtend, Schwarz auf Schwarz bei Monstern | – |
| 2026-11-17 | v0.24.3: Gieriger Drache neu gezeichnet (Fledermausflügel mit Fingerknochen und gezacktem Rand, S-Hals, keilförmiger gehörnter Kopf mit offenem Maul und Feuer, Stachelkamm, Krallenbeine, Schwanz mit Spitze, auf dem Goldhort); Ausrüstungskarten lesbar: dunkle Überschrift auf hellen Karten, Seltenheit auf dunklem Band, Text auf dunkler Platte | Spieler-Feedback | – |
| 2026-11-17 | v0.24.4: Fusionskarten dezenter und eleganter – ruhiger Hintergrund ohne Strahlen, nur leichter Glanz (kein Funkeln/Polychrom), geflochtener Rahmen, feine Goldlinie innen, je Fusionsstufe ein kleiner Goldstein unten, schmales weiches Leuchten hinter der Karte | Feedback: zu viel Lichteffekt | – |
| 2026-11-17 | v0.24.5: Fusionskarten ohne F-Siegel; stattdessen ein Fusionswirbel als Figurenhintergrund (Spiralarme in den Farben der verschmolzenen Figuren, heller Kern, mehr Arme je Stufe); Goldsteine unten bleiben als dezenter Stufen-Hinweis | Spieler-Wunsch | – |
| 2026-11-17 | v0.25.0 Balancing mit 6 Strategie-Bots (Verschwender, Sparer, Leveler, Farbspezialist, Fusionist, Taktiker; tools/bots.gd, tools/balance_report.gd, Skill balance), je 150 Runs: Akt-1-Boss bleibt bewusst eine Mauer (Bots 16 %, Spieler-Wahl „so lassen“); Akt 2 war zu leicht (100 % in normalen Kämpfen) → Wachstum der Gegnerbudgets ×1,5 → ×3,2, Akt-2-Boss-Gefolge 3 → 6, Goldene Mauer 3/20 → 3/23; Ergebnis Akt 2: klein 96 %, groß 65 %, Boss 59 % (Bots) | Spieler: Akt 2 deutlich stärker, auch der Boss | Boss Leben 12→9, ohne Gefolge, weniger Diebstahl; Akt 2 nur etwas stärker |
| 2026-11-17 | Balancing-Runde 2 geplant (Münzfiguren, Farbboni für alle vier Farben, Startgold 6, Schatzkammer nach Bossen, Relikte/Pakte seltener, Beutepack für schwere Banden, Buben stärker, Top-Karten gedämpft) | Spieler: Münzen zu schwach, Anfang zu leicht, Boss/schwere Wahl zu wenig belohnend | Stufen-Sets 2/4/6; einfache +1/+1 je Farbe; günstigeres Neu würfeln |
| 2026-11-17 | v0.26.0 Balancing-Runde 2: Midas /10 /7 /5, Münzknecht +Gold nach Siegen, Goldene Waage + Gold-Mult, Farbboni (Münzen Zinsgrenze, Kelche Leben, Schwerter Blutung, Stäbe Brennen), Startgold −2, Akt-1-Gegner stärker (klein 2,6, groß 4,6), Schatzkammer nach Bossen (Relikt/Ass-Pack/+12 Gold), keine Relikt-Packs mehr, Relikt 5 % in Arkana-Packs, Seelen-Pack 7, Opferaltar halb so oft, mittel +3 / schwer +5 Gold + Beutepack, Messdiener/Funkenträger stärker, Klinge/Richter/Ertrunkener König schwächer, Akt-2-Boss-Gefolge 13 | Spieler: Münzen zu schwach, Anfang zu leicht, Boss und schwere Wahl zu wenig belohnend, Farb-Builds sollen sich lohnen | Stufen-Sets 2/4/6; günstigeres Neu würfeln; Zins je 4 Gold |
| 2026-11-17 | v0.27.0: Bots kontern jede Gegnerbande mit Testkämpfen im Simulator (alle Reihenfolgen bis 4 Figuren, sonst Paartausch; adaptive Bots nehmen die schwerste Bande, die sie im Test schlagen); neuer Bot „Stratege“ (80 % schwere Bande, testet jeden Kauf an einer Kopie des Runs gegen die kommende Bande). Akt-1-Boss schwerer: Steuereintreiber 3/12 → 4/18, Gefolge 1,5 → 2; Akt 1 groß 4,6 → 5,4; Goldene Mauer 3/23 → 4/30, Gefolge 13 → 16. Ist die Gegnerreihe voll (späte Akte), werden leicht/mittel abgeschwächt, damit die Stufen 1,3× auseinander bleiben. Messung (150 Runs je Bot): Siege 5–16 %, A1 K1 82 %, A1 K2 83 %, A1 Boss 20 %, A2 K1 97 %, A2 K2 88 %, A2 Boss 84 %; Stratege verliert die Hälfte seiner Runs schon im ersten Kampf an der schweren Bande | Spieler: Akt-1-Boss schwerer, Bots sollen Schwächen der Gegner gezielt ausnutzen, ein Bot oft schwer | Akt-2-Gegnerbudget weiter erhöhen (die Reihe ist schon voll, ohne neue Gegner ändert sich kaum etwas) |
| 2026-11-17 | Neue Gegner (2 für Akt 1, 6 Elite für Akt 2) und 4 seltene negative Ereignisse mit Ausweg geplant | Messung: Akt 2 lässt sich mit nur 8 Gegnertypen nicht härter machen; Spieler-Wunsch | nur Elite für Akt 2; breite Mischung; reine Strafen; häufige Ereignisse |
| 2026-11-17 | v0.27.1: Funkenträger Brennen 2/3/4 → 1/2/3, Flammenkrone (Ass der Stäbe) Brennen auf alle Gegner 1 → 2; Figuren aus Packs, vom Schwarzmarkt und Belohnungen lassen sich per Drag & Drop in die Reihe ziehen (vorher fing die Kartenfläche den Ziehvorgang ab) | Spieler: Bube zu stark gegenüber der Flammenkrone, Asse ließen sich nicht ziehen | Nur die Flammenkrone stärken |
| 2026-11-17 | v0.27.2 nach Ausschluss-Test (Bots starten mit der Karte, 210 Runs, Basis 7 %): Wiederkehr-Pakt 2 → 1 Wiederbelebung (+51 → +14 Pkt), Pakt der Vorhut ×2 → ×1,5 (+35 → +8), Aschepakt Brennen ×2 → ×1,5 (+22 → +1); Ewige Glut nur noch Stab-Figuren (+19 → +13), Totenglocke nur hinterste Figur (+17 → +11); Kriegskasse +1/+1, Bettelschale +2 Gold, Wetzstein +2 Blutung (alle weiter +2 bis +4, im Rauschen); Goldene Waage neu: Kampfbeginn Schild 2/3/4 je Münzfigur, Gold-Mult für die hinterste Figur bleibt. Wundversiegler und Tresorkardinal neu gezeichnet | Spieler wählte alle vier Vorschläge; Pixel-Feedback | – |
| 2026-11-17 | v0.28.0: 8 neue Gegner (Fluchweber, Kerzenträger; Elite ab Akt 2: Salzgolem, Bannprior, Schildbrecher, Wundversiegler, Tresorkardinal, Uhrwerk-Wächter) und 4 seltene negative Ereignisse (Steuerrazzia, Seuche, Hinterhalt, Fluchnebel). Neu abgestimmt mit dem Auto-Tuning: Akt 1 klein 2,6 → 3,35, groß 5,4 → 6,3, Steuereintreiber 4/18 → 4/14, Wachstum je Akt 3,4 → 4,8, Akt 2 klein ×1,19, Akt-2-Boss-Gefolge 16 → 43 (Reihe dann voll), Goldene Mauer 4/30 → 6/30. Messung (150 Runs je Bot): A1 K1 71 %, A1 K2 69 %, A1 Boss 27 %, A2 K1 80 %, A2 K2 66 %, A2 Boss 62 %; ganze Runs 1–8 % je Bot (unter dem Ziel 8–20 %) | Spieler: neue Gegner und negative Ereignisse; Ziele aus tools/balance_targets.json | Akt-2-Boss über sein Gefolge schwerer machen (Reihe voll, keine Wirkung) |
| 2026-11-17 | v0.28.1: Akt 1 leichter, vor allem die schweren Banden: Budget klein 3,35 → 2,8, groß 6,3 → 5,6, schwer in Akt 1 nur ×1,15 statt ×1,35 und Mindestabstand 1,2 statt 1,3; Akt 2 unverändert stark (Wachstum 5,4, Akt 2 klein ×1,26). Messung (60 Runs je Bot): A1 K1 90 % (schwer 15 % → 54 %), A1 K2 80 % (schwer 79 %), A1 Boss 29 %, Akt 2 77/80/72 %; ganze Runs 0–15 % je Bot. Neue Report-Zeile: Siegquote je gewählter Schwierigkeit; Zielkorridore Akt 1 angepasst | Spieler: schwere Teams in Akt 1 fast nicht machbar | – |
| 2026-11-17 | v0.28.2: Bluttrinker-Lebensraub wirkt direkt nach seinem Treffer im selben Schlagabtausch, also auch, wenn der gleichzeitige Gegenschlag ihn auf 0 gebracht hätte (Tode werden erst danach geprüft) – vorher verfiel die Heilung in diesem Fall | Spieler: Lebensraub prüfen, Heilung direkt nach dem Angriff | – |
| 2026-11-17 | v0.28.3 Fähigkeiten-Prüfung: „Wenn getroffen“ löst auch aus, wenn der Treffer tödlich war (gleichzeitiger Schlagabtausch; z. B. Wutentbrannter brennt seinen Angreifer); Gierschlund-Heilung wirkt wie Lebensraub noch im selben Schlagabtausch; Lebensraub und Aderlass zählen nur wirklich genommenes Leben (kein Überschuss-Schaden); Status-Effekte, die nichts bewirken (Brennen auf den Salzgolem), werden nicht mehr als ausgelöst angezeigt. Neuer Massentest: 400 Zufallskämpfe mit allen Figuren, Gegnern, Relikten und Pakten prüfen feste Regeln (keine Ereignisse nach Kampfende, keine Aktionen entfernter Figuren, Leben nie über Maximum, keine negativen Stapel, Ergebnis passt zu den Überlebenden) | Spieler: alle Figuren auf solche Fehler prüfen | – |
| 2026-11-17 | Sound/Musik aus CC0-Bibliotheken (OpenGameArt inkl. Kenney-Pakete), Musik Mischung aus düsterer Orgel/Glocken und Chiptune, getrennte Regler; Erst-Hinweise als Pergament-Zettel mit Pfeil; Aschepakt ×1,75 | Spieler-Wahl; eigene Umgebung „Roguelike“ mit Zugriff auf kenney.nl und opengameart.org | Selbst synthetisieren; Banner-Hinweise; Hinweise nur im Grimoire |
| 2026-11-17 | v0.29.0: Sound und Musik (45 Effekte, 5 Musikstücke, alle CC0 von OpenGameArt, Credits in docs/AUDIO_CREDITS.md): Menü/Grimoire „Cathedral“, Planung „Dark Shrine Loop“, Lager „Dark Bishop“, Kampf „8-Bit Slay the Evil“, Boss „8-Bit Danger Strong Boss“ mit Überblendung; Klicks, Karten, Münzen, Treffer, Schild, Brennen, Blutung, Fluch, Heilung, Tod, Wiederbelebung, Stufenaufstieg, Fusion, Packs (Glocke ab episch), Schatzkammer, Sieg/Niederlage. Einstellungsseite im Menü: Musik, Effekte, Stumm, Hinweise an/aus, Hinweise zurücksetzen. 12 Erst-Hinweise als Pergament-Zettel mit Pfeil (Gegnerwahl, Boss, Shop, Kampf, Packs, Farbboni, Seelen/Pakte, Belohnung, Ereignis, Gefahr, Fusion, Schatzkammer), je einmal, einer pro Bildschirm. Aschepakt ×1,75 (Ausschluss-Test +2 Pkt, im Rauschen) | Spieler-Wahl | – |
| 2026-11-17 | v0.29.1: Das Gratis-Beutepack der schweren Bande öffnet sich direkt nach dem Sieg auf dem Belohnungsbildschirm statt im nächsten Shop zu warten: großes „Beute!“, goldenes Pack mit Leuchten, Münzregen, Münz- und Glockenklang, zusätzlicher goldener Funkenstoß beim Aufreißen; Debug-Knopf „Beute“ | Spieler-Wunsch | – |
| 2026-11-17 | Figurenkarten nach Familienfarbe statt Rangfarbe, Rang über Glanz/Effekte/Rahmenschmuck; Familiensymbole neu (Wasserzeichen + Ecke); Kerzenträger heilt sich nie selbst; Opfer-Beschreibungen vollständig | Spieler: bessere Übersicht | Rückseiten nach Familie; klassische Tarotfarben; nur Ecke / nur Wasserzeichen |
| 2026-11-17 | v0.30.0: Figurenkarten in Familienfarbe (Grund + Rahmen; Asse dunkel in Familienfarbe mit Strahlen und Polychrom; Fusionsrahmen aus den Familien der verschmolzenen Figuren), Rang über Rahmenschmuck (Ritter Nieten, Königin Silber-Ecken, König/Ass Goldsteine, König Strahlen) und die bisherigen Glanz-Effekte; neue Familiensymbole (Münze mit Pentakel, Stab mit Flamme, Kelch, Schwert) oben links und als Wasserzeichen – überall gleich stark (dunklere Töne auf hellem, hellere auf dunklem Grund); Kerzenträger heilt nie sich selbst; Opfer-Beschreibungen vollständig | Spieler-Feedback zur Vorschau: Wasserzeichen bei allen gleich stark | Wasserzeichen kräftiger; Rang deutlicher |
| 2026-11-17 | v0.30.1: Uhrwerk-Wächter wächst weiter um +2/+2/+3 je Runde, aber insgesamt höchstens +6/+8/+10 (vorher unbegrenzt, z. B. 33 Angriff hinten im Bosskampf); alle Figurenkarten laufen durch denselben Effekt-Shader, damit Bube und höhere Ränge einer Familie exakt dieselbe Farbe zeigen (vorher wirkten Buben blasser). Nachmessung 60 Runs je Bot: Akt 2 klein 81 %, groß 85 %, Boss 66 % | Spieler-Feedback | Uhrwerk-Wächter allgemein schwächer |
| 2026-11-17 | v0.31.0: Schriften größer – alle kleinen Texte (Beschreibungen, Infozeilen, Knöpfe, Hinweise, Info-Fenster) ×1,3 bis max. 26 px, Überschriften ab 24 px bleiben, Kartenflächen/obere Leiste/Siegel/Pack-Felder behalten ihre Größe; Einstellung „Schriftgröße“ 100/115/130/150 %. Gleiche Figuren verschmelzen jetzt auch beim Ablegen am Kartenrand; geht es nicht (Stufe 3 erreicht, Fusion), erklärt eine Meldung warum. Fusion: Jede übernommene Fähigkeit behält die Stufe ihrer Figur (Funkenträger III bleibt Brennen 3), steigt mit der Fusion aber weiter mit | Spieler: Schrift zu klein, Funkenträger ließ sich nicht immer aufleveln, Fähigkeitsstufen bei Fusion übernehmen | Alles inkl. Karten und Überschriften skalieren |
| 2026-11-17 | Übersicht/Intuition: 5 Pakete aus 26 Vorschlägen (Planung neu, Entscheidungshilfen, Kampfanzeige, Gestaltung, Einstieg), paketweise mit Vorschau | Spieler: noch zu unübersichtlich und nicht intuitiv | Auto-Aufstellen, Kampf-Protokoll, Was-tun-Knopf, Regelbuch, antippbare Schlüsselwörter |
| 2026-11-17 | v0.32.0 Paket 1 (nach zwei Vorschau-Runden): Planung zeigt nur noch das eigene Team (größer, auf einer „Bühne“); Gegner per Knopf „Gegner ansehen“ als Fenster; Relikte/Tarot/Pakte in einem eigenen Fach rechts; eingerahmter Laden mit Fächern „Figuren“ und „Packs“, Preise unter den Karten, Neu würfeln/Rückgängig im Laden-Kopf; Ressourcenleiste mit Symbolen (Antippen erklärt), Seelenglut nur im Menü; einheitlicher schlichter Panelstil (dunkles Glas, feine Goldkante); Fähigkeits-Symbol mit Zahl oben rechts auf jeder Karte; Stufen-Rauten statt „EP“; „+1 Stufe“ auf Shop-Karten, die aufleveln würden; Ablagezonen leuchten beim Ziehen (grün verschmilzt, gold frei, weiß tauschen, rot geht nicht) | Spieler-Feedback: Gegenvorschau weg, richtiger Laden, Team größer, eleganter | Gegner weiter im Planungsbildschirm; Gegenstände als Schublade links |
| 2026-11-17 | v0.33.0 Paket 2 (nach Skizzen und mehreren Vorschau-Runden): Planung ohne unnötige Texte (kein Akt-Titel, keine Region, kein „Dein Team“, keine Farbboni-Zeile, keine Siegchance, kein Fähigkeits-Symbol am Kartenrand); links Info-Spalte (Menü, Gold mit Zinsen, Seelen, Plätze), oben das Team, oben rechts eine kleine Leiste für Relikte/Tarot/Pakte (farbige Plätze ohne Überschriften); unten der Laden als Tresen nach dem Shop-Prinzip von Karten-Roguelikes (eigene Optik): Fächer Figuren und Packs, rechts Kampf, Gegner ansehen, Neu würfeln, Rückgängig; Verschmelzen ohne Abfrage: auf die Karte ziehen = goldenes Leuchten + „+1 Stufe“, an den Rand = leuchtende Linie, die Figur kommt daneben; Siegbildschirm: großes zentriertes „Sieg!“, Belohnungstabelle (Sieg, Bonus, Zinsen, Relikte, Seelen, neuer Platz, Beutepack, Gesamt), drei Belohnungen exakt mittig, Nehmen nur per Ziehen ins Team, „Weiter (+2 Gold)“; Ereignis- und Stufentitel mittig oben; Info-Fenster gekürzt, 31 Texte prägnanter; Kampf-Warnung bei freien Plätzen und Gold; Werte-Marker grün/rot | Spieler: zu viel Text, Ablagen zu groß, Fokus auf Shop und Team, Belohnung ohne Knopf, Verschmelzen/Danebenstellen eindeutig | Marktstand oben; Schublade unten; Verschmelz-Abfrage; Doppeltippen zum Nehmen |
| 2026-11-18 | v0.34.0 Paket 3 + Aufräumen: Gegnerwahl ohne Gebietszeile, „Wähle…“-Überschrift, „Dein Team“ und Versionszeile (Bossregel bleibt), Team größer in einem Rahmen; Ereignisse mit Namen mittig oben, kurzer gedämpfter Beschreibung, breiteren Angeboten, kleinerem Emblem, Team unten mit kleiner Ablagen-Leiste, Verkaufsfeld nur beim Ziehen; Kampfanzeige: minimale Kopfzeile (Zug mittig; rechts Pause, Nächster Zug, 1×/2×/3×, Überspringen), Pause hält vor dem nächsten Ereignis, „Nächster Zug“ spielt bis zum nächsten Zug, große aufspringende Zahlen (Schaden 50 px, Heilung grün, Schild blau), Status (Schild, Brand, Blutung, Fluch) als große Symbole mit Zahl über den Figuren, Zusammenfassung am Ende (Schaden, Eingesteckt, Geblockt, Geheilt je eigener Figur, stärkste in Gold) mit Weiter-Knopf; Gold und Version im Kampf ausgeblendet | Spieler: Kampf besser nachvollziehen, alles schlicht | Kampf-Protokoll als Liste; Gegner in der Zusammenfassung |
| 2026-11-18 | v0.35.0 Shop nach Agenten-Vorschlägen (Game-Designer + Pixel-Artist, Skizze freigegeben): Gold, Seelen und Plätze oben rechts untereinander, Boxen 224×72, Symbol 42 px, Zahl 36 px, Zinsen nur als „+1“ (Erklärung beim Antippen), Seelen-Box gedämpft bei 0; Relikte/Tarot/Pakte links unter dem Menü, Plätze 60 px, je Gruppe eine Reihe mit Farbe, kleinem Symbol und feiner Goldlinie, leere Plätze mit blassem Gruppensymbol; beide Seitenspalten 248 px, Team mittig; zu teure Figuren/Packs leicht abgedunkelt; beim Kauf fliegen Münzen von der Gold-Box zur Figur (0,4 s) | Spieler: Ressourcen und Ablagen zu klein, Ressourcen rechts oben, Ablagen links | Ablagen als Leiste oben rechts; Ressourcen links |
| 2026-11-18 | v0.36.0: Münzwerfer wirft nur jeden 2. Zug (Feld „every“ für Zugbeginn-Fähigkeiten); Fusionen ketten: an jedem Anlass beliebig viele Schritte hintereinander (Boss/Kerze/Blutmond: angebotene Schritte gratis, jeder weitere 2 Seelen; Altar: jeder Schritt zum Altarpreis), der Anlass endet mit „Fertig“ oder wenn nichts mehr fusionierbar ist; Ritualkerze auch auf dem Ereignis-Bildschirm nutzbar (Fehler: am Schwarzmarkt gekauft ließ sie sich nicht einsetzen), Tarot-Hinweis nur im Shop; Paket 4: festes Farbsystem (Gold = Geld/Kauf, Rot = Gefahr/Kampf/Verkauf, Blau = Seelen/Schild, Grün = Heilung/Aufstieg/Verschmelzen, Violett = Tarot/Fluch/Ereignis/Fusion), Verschmelz-Leuchten grün, Einfügelinie weiß; neues Info-Fenster mit großer Karte links und antippbaren Symbolen mit Kurzerklärung; Schild, Brennen, Blutung, Fluch, Angriff, Leben, Gold als Symbole im Text (eigene Pixel-Symbole); Phasen-Titelkarten (~1 s) für neuen Kampf, Bosskampf (rot) und Ereignis (violett, Gefahr rot), Hinweise erst danach; drei abgeschnittene Texte repariert (ungeschützte Kommas) + Test gegen kaputte CSV-Zeilen | Spieler: Münzwerfer zu stark, F3 kaum erreichbar, Kerze ging nicht, Paket 4 komplett | Münzwerfer: begrenzte Würfe, schwächer, Spieler-Konter; Fusion: mehr Anlässe, Boss 2 Schritte |
| 2026-11-20 | v0.37.0 Paket 5 + Feedback-Runde: geführter erster Run (leuchtender Rahmen nacheinander: leichte Bande, Figur ins Team ziehen, Kampf, Belohnung ziehen, Pack öffnen; „Führung beenden“; nur ohne beendete Runs); ein Bedienprinzip: Ziehen = handeln, Tippen = Info (Shop-Figuren kaufen, Tarot/Kerze auf Figuren, Relikte und Ausrüstung aufs Verkaufsfeld; Packs: Tippen zeigt Info mit Knopf „Kaufen & öffnen“); Tippflächen mind. 48 px; Debug nur mit ?debug=1; Gegnerwahl nacheinander (Leicht → Risiko → Mittel → Risiko → Schwer, nächste Bande verdeckt, kein Zurück, kein Überspringen); Packs groß über den ganzen Bildschirm, Ausrüstung landet im Ausrüstungsfach (3 Plätze, 4. Reihe links) und wird von dort auf Figuren gezogen (Tausch legt die alte zurück ins Fach) oder verkauft; Ereignis-Bildschirme im Shop-Rahmen (links Menü+Ablagen, rechts Ressourcen, Mitte Ereignis, unten Team); Grabkammer/Schwarzmarkt: Truhe öffnet sich, Relikt steigt auf und fliegt in die Relikt-Reihe; Farbboni im Info-Fenster (Familien-Knopf mit Regel und aktueller Anzahl); Bannprior halbiert Heilung statt sie zu blockieren; Spiegelbild kopiert mit gleicher Stufe; Akt 1: höchstens 3 Gegner je Bande, Budget ×0,85; Eliten höchstens einmal je Art pro Bande (Bots: A1 K1 90→93 %, K2 81→90 %, Boss ~36 %, A2 K2 75→85 %); Fehler: Fusionen aus zwei gleichfarbigen Teilen zählten doppelt für Farbboni (Blutung auf alle Gegner); Dolch/Fackel-Text nur „Blutung/Brennen v“; Info öffnet nicht mehr beim Loslassen nach Ziehen und weicht beim Ziehen aus; Gebiets-Intro zeigt Akt/Kampf, keine doppelte Titelkarte. Henker: Logik geprüft (4000 Kämpfe), kein Fehler gefunden | Spieler-Feedback 20.11. | Spiegel: 1 Seele oder +1 Stufe; Bannprior: nur vorderste Figur, 3 Züge, schwächer; Gegnerwahl mit Zurück; Ausrüstungsfach 2 oder unbegrenzt |
| 2026-11-20 | v0.38.0 Kosmetik nach Entwürfen des Pixel-Artist-Agenten (Spieler-Wahl): Aura-Variante C „Lichtsäule“ (weicher Schein von unten, atmet langsam, Bodenring, 2–4 feste Funkel, Stärke nach Fusionsstufe); gekaufte Auren tragen jetzt alle eigenen Figuren (vorher nur Fusionen – deshalb unsichtbar), Gegner nie, die kostenlose Standard-Aura bleibt auf Fusionen; Kartenrücken als Pixel-Rücken je Familie (Pentakel, gekreuzte Stäbe, Kelch, Schwert; Samtmuster, Edelsteine, Eckmotive) in Shop-Packs, Pack-Öffnung und Spiegel; Krypta-Lager als begehbarer Raum mit antippbaren Truhen, Altar, Bildnissen und Spiegel; Kampf-Krypta neu (Mondfenster mit Lichtstrahl, Fackeln, Nischen, Ketten, Perspektivboden, Nebel); Arena zeigt angelegte Kosmetik; „Führung beenden“ unter den Ressourcen (überdeckte auf dem iPad „Rückgängig“); Geräte-Check iPhone/iPad quer | Spieler: Auren, Kartenrücken, Krypta überarbeiten; Aura nie sichtbar | Aura A Schleier, B Nimbus |
| 2026-11-20 | v0.38.1: eigene Pixel-Rücken für Seelen-Pack (violett-schwarzer Samt, Knochen-Silber, Seelenblau, Pakt-Siegel mit Seelenflamme; auch für Pakt-Karten beim Öffnen) und Schmiede-Pack (Eisenrahmen, rußschwarzes Leder mit Nieten, Glutorange, Amboss mit Hammer und Funken; auch für verdeckte Ausrüstungskarten); einheitliche Namensleiste unten auf allen Packs; Markt-Ereignis zeigt den passenden Pack-Rücken | Spieler: Seelen-Pack grafisch überarbeiten, Schmiede-Pack anders als Arkana-Pack | – |

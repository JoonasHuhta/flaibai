# Flaibai — Projektin Nykytila & Käsikirja (Handover / Codex)

Tämä dokumentti on tarkoitettu AI-agenteille (kuten Codex) projektin nykytilanteen nopeaan sisäistämiseen. Se kuvaa arkkitehtuurin, ydinmekaniikat, fysiikan säännöt ja tunnetun teknisen velan.

## 1. Yleiskatsaus
**Flaibai** on fysiikkapohjainen arcade-tasohyppely mobiililaitteille (portrait-tila). Pelaaja ohjaa vieterikenkäistä hahmoa napauttamalla ja kallistamalla sitä ilmassa. Tavoitteena on päästä maaliin kaatumatta ja laskeutua puhtaasti. Peli nojaa raskaasti "game feeliin" (kameran tärinä, haptinen palaute, fysiikan paino).

## 2. Tiedostorakenne ja Arkkitehtuuri

### Autoloads (Singletonit)
*   **`ProjectState` (`scripts/core/project_state.gd`)**: Pitää kirjaa nykyisestä kenttäindeksistä. Määrittää kenttäjärjestyksen (`level_scenes` array).
*   **`AudioManager` (`scripts/core/audio_manager.gd`)**: Käsittelee musiikin ja SFX:n. Null-safe (jos `.ogg` tai `.wav` tiedosto puuttuu, se ohitetaan hiljaa).

### Keskeiset Scenet
*   **`scenes/start_screen.tscn`**: Aloitusruutu. Käynnistää pelimusiikin ja odottaa napautusta.
*   **`scenes/levels/level_01.tscn`**: Ensimmäinen (helppo) kenttä. Toimii tutoriaalina.
*   **`scenes/prototyyppi.tscn`**: Kenttä 2 (vaikea). Sisältää kaikki erikoispinnat. Toimii toistaiseksi toisena kenttänä.

### ⚠️ Kriittinen Tekninen Velka (TÄRKEÄÄ!)
Tällä hetkellä **pelaajahahmo (`Flaibai` Node2D), kamera, UI (`RetryLayer`) ja `GameManager` ovat kopioituna suoraan jokaiseen kenttä-sceneen** (`level_01.tscn` ja `prototyyppi.tscn`).
*   **Miksi?** Prototyyppivaiheessa kaikki oli yhdessä tiedostossa.
*   **Seuraava iso arkkitehtuurimuutos:** Nämä on erotettava. Tarvitaan `Game.tscn` (joka sisältää GameManagerin, UI:n, Kameran ja Pelaaja-instanssin), joka lataa sisäänsä dynaamisesti vain kentän geometrian (`level_01.tscn`, jne.).

## 3. Pelaajan Fysiikka ja Ohjaus (`PlayerController2D`)

Hahmo on `RigidBody2D`. Fysiikkaa säädetään `PlayerTuning` resursseilla.

*   **Laukaisu (Tap-to-launch):** Kun hahmo on maassa odottamassa, mikä tahansa napautus (tap) laukaisee sen ilmaan automaattisella impulssilla (`auto_launch_impulse`). Hahmo tekee idle-heiluntaa odottaessaan.
*   **Ilmaohjaus:** Kun hahmo on ilmassa, pelaaja pitää sormea ruudun vasemmalla tai oikealla puoliskolla antaakseen vääntöä (`air_torque`) ja pyörittääkseen hahmoa.
*   **Pomppiminen:** Hahmo pomppaa automaattisesti laskeutuessaan. Pompun voima riippuu `bounce_takeoff_speed` arvosta ja tulokulmasta.
*   **Crash (Kuolema):**
    *   Liian kova isku huonossa kulmassa (`crash_min_impact_speed`).
    *   **Kyljelleen makaaminen:** Jos hahmo on maassa ja kallistunut yli 72 astetta yli 0.38 sekunnin ajan (sisältää grace periodin pompun jälkeen).

## 4. Kenttäelementit ja Pinnat

Kaikki pinnat ovat `StaticBody2D` nodeja, joiden toiminta määritellään `groups`-tageilla (esim. `["ground", "mushroom"]`).

| Ryhmä (Group) | Toiminta (`player_controller.gd: _handle_bounce()`) |
| :--- | :--- |
| `ground` | Normaali pomppu. Kaikilla pinnoilla on oltava tämä ryhmä. |
| `mushroom` | Antaa merkittävästi isomman pystysuuntaisen impulssin. |
| `moss` | Sammal. Vaimentaa kaiken liike-energian nollaan. Hahmo pysähtyy ja jää odottamaan uutta tap-to-launchia. |
| `ice` | Jää. Poistaa vaakasuuntaisen kitkan, hahmo liukuu eteenpäin. |

### GoalZone (`scripts/level/goal_zone.gd`)
Maalialue vaatii tarkkaa laskeutumista.
1.  Pelaajan on oltava `is_grounded_any()` (vähintään yksi jalka maassa, GoalZonen alla on FinalPlatform).
2.  Kulma pystysuorassa (< 34 astetta) ja pystynopeus pieni (< 220).
3.  Pelaajan on pysyttävä tässä tilassa `goal_hold_time` (0.45s) ajan.
4.  Laukaisee `player.celebrate()` (iloinen tuplahyppy) ja 0.9s myöhemmin GameManager näyttää "LEVEL COMPLETE!" UI:n.

## 5. UI ja Audio

*   **GameManager:** Käsittelee Flow-mittarin (kasvaa volteista ja puhtaista alastuloista), pisteet, ja näyttää lopussa tulosruudun. "Next Level" nappi kutsuu `ProjectState.advance_level()`.
*   **Audio:** Kts. `audio/AUDIO_BRIEF.md`. Käytössä `.ogg` tai `.wav`. Jos tiedosto on kansiossa, `AudioManager` soittaa sen automaattisesti. Esimerkiksi `bounce.ogg`, `crash.ogg`, `game_theme.ogg`.

## 6. Lähitulevaisuuden Kehityskohteet (TODO)

1.  **Arkkitehtuurin Refaktorointi:** Rakenna modulaarinen `Game.tscn` + `LevelLoader` järjestelmä, jotta uusien kenttien tekeminen ei vaadi koko pelaajan ja UI:n kopioimista.
2.  **Uusien kenttien suunnittelu:** Kun arkkitehtuuri on kunnossa, tarvitaan kenttiä 03-10, jotka opettavat pintoja (jää, sammal) yksitellen.
3.  **Puuttuvat Äänet:** Etsi ja konvertoi loput `.ogg` tiedostot (esim. `launch.ogg`, `moss_stop.ogg`, `clean_streak.ogg`).
4.  **Ghost Runner:** Lisää haamu edellisestä ennätyssuorituksesta parantamaan uudelleenpelattavuutta.

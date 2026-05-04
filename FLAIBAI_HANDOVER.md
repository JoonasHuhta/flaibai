# Flaibai — Projektin Nykytila & Käsikirja (Handover / Codex)

Tämä dokumentti on tarkoitettu AI-agenteille (kuten Codex) ja kehittäjille projektin nykytilanteen nopeaan sisäistämiseen. Se kuvaa arkkitehtuurin, ydinmekaniikat, uuden tallennusjärjestelmän ja tulevaisuuden suuntaviivat.

**Päivitetty:** Scoreboard-järjestelmän, Start Screen -uudistusten ja hitbox-viilausten jälkeen.

## 1. Yleiskatsaus & Ydinmekaniikat
**Flaibai** on fysiikkapohjainen arcade-tasohyppely mobiililaitteille (portrait-tila). Pelaaja ohjaa vieterikenkäistä hahmoa (RigidBody2D) napauttamalla ja kallistamalla sitä ilmassa vasemmalta ja oikealta puolelta ruutua. 
*   **Tavoite:** Päästä maaliin (GoalZone) kaatumatta ja laskeutua jaloilleen riittävän pitkäksi aikaa (0.45s) pystyssä.
*   **Game Feel:** Peli nojaa raskaasti painavaan fysiikkaan, kameratärinään ja haptiseen palautteeseen. Hahmon hitboxeja on hiljattain hieman pienennetty armollisemman pelituntuman saavuttamiseksi.

## 2. Arkkitehtuuri & Tiedostorakenne

### Autoloads (Singletonit)
Näitä tulee kutsua dynaamisesti `get_tree().root.get_node_or_null("Nimi")` avulla, ei `Engine.get_singleton()`:
*   **`ProjectState`**: Hallitsee kenttälistaa, etenemistä (unlocks) ja pitää kirjaa parhaista ajoista (Top 10 per kenttä). Hoitaa tallennuksen ja latauksen polkuun `user://flaibai_records.cfg`.
*   **`AudioManager`**: Käsittelee musiikin ja SFX:n dynaamisesti (`.ogg`, `.wav`).

### Keskeiset Scenet
*   **`scenes/start_screen.tscn`**: "Juicy" aloitusruutu (leijuva hahmo, parallax-tausta). Sisältää nykyään **kenttävalikon**, josta näkee lukitut kentät ja parhaat ajat.
*   **`scenes/levels/level_01.tscn`**: Tutoriaalikenttä.
*   **`scenes/prototyyppi.tscn`**: Vaikeampi testi/leikkikenttä (jää, sammal, sienet).

## 3. Uudet Järjestelmät (Elastomania-henkinen Scoreboard)
Peliin on lisätty lokaali ennätysjärjestelmä:
*   Jokaisesta kentästä tallennetaan 10 parasta aikaa. 
*   Kun pelaaja läpäisee kentän (GoalZone hyväksyy laskeutumisen), `GameManager` pysäyttää ajan ja kutsuu `ProjectState.record_level_time()`.
*   Ruudulle aukeaa **`ScoreboardUI`**, joka näyttää Top 10 -listan, pelaajan oman ajan ja ilmoittaa "NEW RECORD!" jos aika oli ykkönen.
*   Scoreboardista löytyy napit "RETRY" (lataa uudelleen) ja "NEXT LEVEL" (avaa ja lataa seuraavan kentän).

## 4. Kenttäelementit ja Pinnat
Kaikki pinnat ovat `StaticBody2D` nodeja, joilla on jokin näistä `groups`-tageista:
*   `ground`: Normaali pomppu.
*   `mushroom`: Voimakas korkea pomppu.
*   `moss`: Vaimentaa liike-energian nollaan (hahmo pysähtyy, vaatii uuden lähdön).
*   `ice`: Poistaa vaakasuuntaisen kitkan (liukuu loputtomiin).

## 5. ⚠️ Kriittinen Tekninen Velka (SEURAAVA ISO TEHTÄVÄ)
Tällä hetkellä **pelaajahahmo, kamera, UI ja GameManager ovat kopioituna suoraan jokaiseen kenttä-sceneen**. 
Tämä tarkoittaa, että jos haluamme muuttaa GameManagerin koodia tai UI:n asettelua, se on päivitettävä jokaiseen `.tscn` tiedostoon erikseen.

**Arkkitehtuurimuutos (Kenttä-Pipeline):**
Ennen uusien kenttien massatuotantoa meidän on erotettava nämä:
1.  Tehdään master-scene nimeltä `Game.tscn` (tai Core.tscn).
2.  Tämä scene sisältää `GameManagerin`, Pelaaja-instanssin, Kameran ja UI-layerin.
3.  Varsinaiset kentät (`level_01.tscn` jne.) sisältävät **vain maaston, maalin ja spawn-pisteen tiedot**.
4.  `Game.tscn` lataa sisäänsä pyydetyn maasto-scenen, siirtää pelaajan spawn-pisteeseen ja aloittaa pelin.
Tämä tekee uusien kenttien tekemisestä äärimmäisen helppoa ja nopeaa!

## 6. Lähitulevaisuuden Suunnitelma
1.  **Arkkitehtuurin siivous (kts. yllä):** Irrotetaan level-geometria core-pelaajasta.
2.  **Kenttäsuunnittelu (Level Design):** Kun arkkitehtuuri on kunnossa, rakennetaan 10–20 lyhyttä ja tiivistä kenttää. Kenttien tulisi opettaa aina yksi mekaniikka (esim. pelkkä jää, pelkkä sammal, pelkkä takaperinvoltti) kerrallaan.
3.  **Ghost Runner (Haamupelaaja):** Tallennettaisiin ennätysajon reitti (position + rotation history) ja toistettaisiin se visuaalisesti seuraavalla yrityksellä. Muiden AI-agenttien tulisi harkita tämän toteutusta myöhemmin.

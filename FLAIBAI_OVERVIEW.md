# Flaibai – Pelin Laaja Katsaus ja Konseptidokumentti

Tämä dokumentti on yhteenveto **Flaibai**-pelistä. Se kuvaa pelin perusidean, tavoitteet, keskeiset mekaniikat ja sen mistä osista peli koostuu.

---

## 1. Mistä pelissä on kyse?
**Flaibai** on fysiikkapohjainen arcade-tasohyppelypeli mobiililaitteille (pystysuuntainen / portrait-tila). Peli nojaa vahvasti nopeatempoiseen ja haastavaan "Elastomania-henkiseen" speedrun-pelattavuuteen. 

Pelaaja ohjaa vieterikenkäistä pikkuhahmoa (Flaibai), jonka tarkoitus on pomppia ja volttailla kaksiulotteisissa kentissä kohti maalia. Pelissä ei ole perinteistä kävelyä, vaan kaikki liikkuminen perustuu fysiikan lakeihin, kimmokkeisiin, ilmalentojen hallintaan ja taitavaan ohjattavuuteen ruutua napauttamalla.

**Pelin henki (Game Feel):**  
Pelin tunnelma on energinen, mehuisa (juicy) ja erittäin responsiivinen. Se on suunniteltu antamaan voimakasta palautetta onnistumisista ja epäonnistumisista. Laskeutumiset täräyttävät ruutua (camera shake), laite värisee (haptic feedback), ja äänimaailma korostaa kineettistä energiaa. Virheistä rangaistaan armottomasti ragdoll-kaatumisella, mutta kentän voi yrittää uudelleen silmänräpäyksessä.

---

## 2. Pelaajan Tavoite
Pelaajan ensisijainen tavoite on **päästä kentän alusta maaliin (GoalZone) hengissä ja mahdollisimman nopeasti**. 

Tämä jakautuu seuraaviin alitavoitteisiin:
1. **Selviytyminen:** Pelaaja ei saa kaatua. Jos hahmo osuu maahan pää edellä tai kyljellään liiassa kulmassa, se kolaroi (crash) ja kenttä on aloitettava alusta.
2. **Puhdas laskeutuminen:** Maalialueelle saavuttuaan pelaajan on kyettävä pysäyttämään hahmon liike-energia ja laskeuduttava siististi jaloilleen (0.45 sekunnin ajaksi). Vasta tämä pysäyttää kellon.
3. **Speedrun ja ennätykset:** Kun pelin mekaniikat oppii, tavoitteeksi muodostuu kenttien läpäiseminen huippuajassa. Pelaaja kisaa omia aiempia parhaita aikojaan vastaan hiomalla reittejä ja hyödyntämällä fysiikkaa nopeampiin ilmalentoihin.

---

## 3. Mitä osia pelissä on? (Järjestelmät ja Mekaniikat)

Peli rakentuu useiden toisiinsa kytkeytyvien osajärjestelmien varaan:

### A. Fysiikkapohjainen Pelaajaohjain (Player Controller)
Pelin sydän. Pelaaja on `RigidBody2D`, jonka jaloissa on erilliset osumaalueet (hitboxit).
*   **Laukaisu:** Ensimmäinen napautus ampuu hahmon liikkeelle.
*   **Pomput:** Kun hahmo osuu maahan, se kimpoaa takaisin ylös. Pompun voimakkuus ja suunta riippuvat hahmon kallistuskulmasta, alastulonopeudesta ja pelaajan liike-energiasta.
*   **Ilmahallinta (Air Control):** Pelaaja voi pyörittää hahmoa ilmassa eteen- ja taaksepäin painamalla ruudun vasenta tai oikeaa laitaa. Tämä on kriittistä, jotta hahmon saa käännettyä jaloilleen ennen maahan osumista.

### B. Dynaamiset Pinnat ja Maastot (Surfaces)
Kentät eivät ole vain esteitä, vaan maasto vaikuttaa fysiikkaan:
*   **Normaali maa:** Tavallinen kimpoaminen.
*   **Sieni (Mushroom):** Trampoliinimainen erittäin voimakas kimmoke, joka ampuu hahmon korkeuksiin.
*   **Jää (Ice):** Kitkaton pinta, jossa hahmo liukuu holtittomasti ja pomput venyvät pitkiksi.
*   **Sammal (Moss):** Kuolleen kulman pinta. Vaimentaa kaiken liike-energian nollaan; hahmo "tarrautuu" siihen ja vaatii uuden laukaisunappulan painalluksen päästäkseen liikkeelle.

### C. Paikallinen Ennätysjärjestelmä (Scoreboard)
Kun kenttä on läpäisty, pelaajalle aukeaa dynaaminen tulostaulu.
*   Peli tallentaa `user://`-kansioon pysyvästi pelaajan top 10 -ajat jokaisesta kentästä.
*   UI näyttää uuden ajan ja onnittelee dynaamisesti (esim. "NEW RECORD" tai "TOP 10! RANK #3").

### D. Käyttöliittymä ja Valikot (UI / Start Screen)
*   Dynaaminen aloitusruutu, jossa Flaibai-hahmo pomppii taustalla jatkuvassa loopissa yönsinistä tähtitaivasta vasten.
*   Kenttävalikko, josta pelaaja voi valita avattuja kenttiä ja nähdä suoraan oman parhaan aikansa niissä.

### E. Äänijärjestelmä (Audio Manager)
Dynaaminen äänien hallinta, joka toistaa onnistumisen tunnetta vahvistavia äänitehosteita (kimpoamisäänet alustan mukaan, volttien huminat, kolarin rusahdus, UI-klikkaukset) ja taustamusiikkia yhtenäisesti ilman katkoja.

---

## 4. Kehityksen Suunta ja Arkkitehtuurillinen Tavoite

**Tällä hetkellä** peli on vahvassa prototyyppi/alpha-vaiheessa. Ydinmekaniikat ovat todella hauskoja ja APK-vienti Androidille on täysin pelattavissa. 

**Tulevaisuuden kehitystavoitteet (Missä olemme nyt):**
1.  **Arkkitehtuurin refaktorointi:** Suurin tekninen pullonkaula on tällä hetkellä se, että ydinjärjestelmät (pelaaja, käyttöliittymä, kamerat) on kopioitu fyysisesti jokaisen kentän sisään. Tavoitteena on erottaa Peli (Core) ja Kentät (Geometry) toisistaan dynaamisen Level Loaderin avulla.
2.  **Kenttäsuunnittelu (Level Design):** Kun arkkitehtuuri sallii, peliin on tarkoitus tuottaa 20-30 erilaista, lyhyttä "puraisun" kokoista kenttää, jotka opettavat ja haastavat pelaajan eri fysiikkamekaniikoilla.
3.  **Ghost Runner:** Haamupelaajan lisääminen tulevaisuudessa. Pelaaja näkisi oman parhaan aikansa "haamun" juoksevan rinnallaan, mikä lisäisi speedrun-aspektin koukuttavuutta entisestään.

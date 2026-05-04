# Flaibai – Kehitysstrategia ja Pelaajapsykologia (Codexin Ohjeistus)

Nämä suuntaviivat perustuvat fysiikka-arcade-pelien (kuten Elasto Mania, Trials HD ja Getting Over It) menestystekijöihin. Tämän dokumentin tarkoitus on ohjata tekoälyagentteja (kuten Codex) pelimekaniikkojen hienosäädössä ja kenttäsuunnittelussa.

---

## 1. Koukuttavuuden Ydin: "Fail, Diagnose, Retry, Improve"

Fysiikkapelien vetovoima perustuu siihen, että pelaaja kokee oppivansa hallitsemaan alun perin kaoottista systeemiä. Virheiden on tunnuttava pelaajan omalta syyltä, ei pelin epäreiluudelta.

**Mitä tämä tarkoittaa Flaibain kehityksessä:**
*   **Täydellinen determinismi:** Saman napautuksen tai kallistuksen on *aina* tuotettava sama lopputulos. Satunnaisuutta (RNG) ei saa käyttää fysiikassa tai kimpoamisissa lainkaan.
*   **Luettava epäonnistuminen (Readable Failure):** Kun pelaaja kolaroi, hänen on heti ymmärrettävä miksi. Esimerkiksi: "Kallistuin liikaa eteenpäin", "Tulin liian kovaa alas", tai "Aloitin volttini liian myöhään".
*   **Instrumentaalinen ohjaus:** Hahmon ei pidä tuntua raskaalta kiveltä, vaan työkalulta (precision instrument), jonka hallinta paranee toiston myötä. Äskettäinen hitboxien pienennys oli askel juuri tähän suuntaan.

---

## 2. Instant Retry & Pieni Kitka

Koukuttavuuden tärkein yksittäinen ominaisuus on "Near-miss learning" yhdistettynä olemattomaan kitkaan. Mitä nopeammin epäonnistumisen jälkeen pääsee yrittämään uudelleen, sitä vahvempi "yksi vielä" -ilmiö on.

**Action Pointit Codexille:**
*   **Nopea Uudelleensyntymä:** Varmista, että kolarin (crash) jälkeinen viive pidetään erittäin lyhyenä. Nykyinen 0.45 sekunnin ragdoll-tumble on hyvä, mutta sen jälkeen "Retry"-napin pitää ilmestyä välittömästi, tai vielä parempaa: mahdollista nopea uudelleenkäynnistys suoraan ruutua painamalla kolarin jälkeen, ilman valikoiden odottelua.
*   **Ei rankaisevia valikoita:** Kun pelaaja epäonnistuu, älä pakota häntä takaisin aloitusruutuun tai lataustaukoihin.

---

## 3. "Ghost Tension" – Uusi Innovaatio

Tutkimusmuistiinpanoista nousee esiin äärimmäisen mielenkiintoinen mekaniikka: **Ghost Tension**. Sen sijaan, että peli näyttäisi vain parhaan ajan "haamu-juoksijan" (Ghost Runner), peli voi näyttää pelaajan *viimeisimmän epäonnistuneen yrityksen*.

**Action Pointit Codexille:**
*   **Toteuta Last Fail Ghost:** Rakenna järjestelmä, joka tallentaa pelaajan sijainnin ja rotaation. Jos pelaaja kolaroi, seuraavalla yrityksellä hänen edellinen kolaroinut hahmonsa näkyy läpinäkyvänä haamuna ruudulla (esim. 3–5 sekuntia).
*   **Miksi?** Tämä haamu toimii konkreettisena, visuaalisena oppaana ("älä tee kuten tuo teki") ja vahvistaa "diagnose and improve" -sykliä valtavasti. Se tekee epäonnistumisesta arvokkaan tiedonlähteen.

---

## 4. Kenttäsuunnittelun Säännöt (Level Design Rules)

Jotta "syyllisyys" virheestä pysyy pelaajalla, kenttien on oltava selkeitä ja reiluja.

**Action Pointit Codexille:**
*   **Yksi konsepti per kenttä:** Kun alat rakentaa kenttiä 03–20, opeta vain yksi asia kerrallaan. Esim. "Vain jäätä ja jarrujen opettelua", tai "Vain yksi valtava sienipomppu, jossa pitää hallita ilmakulmaa". Älä tee sekamelskaa.
*   **Kontrasti avuttomuuden ja hallinnan välillä:** Suunnittele kenttiin kohtia, jotka tuntuvat aluksi mahdottomilta, mutta oikealla rytmillä (kuten jatkuvalla eteenpäin nojaamisella) ne muuttuvat sulavaksi liukumiseksi.
*   **Selkeä riskinotto:** Rakenna turvallisia mutta hitaita reittejä (esim. sammal-pysähdyksiä) ja vaarallisia mutta nopeita reittejä (esim. suora pudotus jääluiskaan), jotta speedrun-yhteisö saa työkaluja omien aikojensa parantamiseen.

# Godot-proton rakenne

Tämä projekti toteuttaa Boinkster-proton Godot 4 -rakenteella:

- `Boinkster` on ohjaava `Node2D`
- `Body`, `LeftFoot` ja `RightFoot` ovat erillisiä `RigidBody2D`-kappaleita
- jalat on kiinnitetty runkoon `DampedSpringJoint2D`-jousilla
- pää ja raajat ovat vain visuaaleja `VisualRoot`-nodessa
- kamera seuraa runkoa x-suunnassa portrait-näkymässä

## Pääscene

Pääscene on:

`res://scenes/prototyyppi.tscn`

Se sisältää:

- `GameManager`
- `SpawnPoint`
- `Ground`
- kolme platformia
- yhden wall-kick-seinän
- `GoalZone`
- `Boinkster`
- `Camera2D`

## Skriptit

- `res://scripts/player/player_controller.gd`
  - drag-to-launch
  - air tilt
  - foot bounce
  - respawn-reset

- `res://scripts/player/foot_contact_2d.gd`
  - tunnistaa jalkojen kontaktit `ground`-groupiin
  - välittää impact speedin controllerille

- `res://scripts/player/player_visuals_2d.gd`
  - pitää pään, rungon, jalat ja jalkaterät fysiikasta erillään
  - lisää crouch/squash-efektin lataukseen

- `res://scripts/player/player_tuning.gd`
  - kaikki tärkeimmät tuntuma-arvot yhdessä `Resource`-assetissa

- `res://scripts/core/camera_follow_2d.gd`
  - x-suuntainen kameraseuranta

- `res://scripts/core/game_manager.gd`
  - respawn
  - fail-y
  - level complete

- `res://scripts/level/goal_zone.gd`
  - hyväksyy maalin vain siistillä kahden jalan laskeutumisella

## Testijärjestys

1. Avaa `scenes/prototyyppi.tscn`.
2. Käynnistä peli.
3. Odota että hahmo putoaa jaloilleen.
4. Vedä hiirellä tai touchilla taaksepäin ja vapauta.
5. Ilmassa:
   - `A` / vasen nuoli kallistaa vasemmalle
   - `D` / oikea nuoli kallistaa oikealle
   - touch/hiiri ruudun vasemmalla tai oikealla puoliskolla toimii myös ilmassa
6. Laskeudu jaloilleen ja tarkista että bounce syntyy vain riittävän pystyssä.
7. Mene maalialueelle ja pidä hahmo hetki molemmilla jaloilla.
8. Paina `R`, jos haluat respawnata.

## Säädettävät arvot

Prototyypissä tuning on sisäisenä resource-alivarana `prototyyppi.tscn`-scenessä. Kun tuntuma alkaa löytyä, siitä kannattaa tehdä erillinen `.tres`-asset:

1. Luo uusi resource: `PlayerTuning`.
2. Tallenna se esimerkiksi `res://assets/tuning/player_tuning_arcade.tres`.
3. Vedä sama asset `Boinkster`- ja `GoalZone`-nodeihin.

Tärkeimmät ensimmäiset säädöt:

- `max_launch_power`
- `launch_multiplier`
- `air_torque`
- `balance_torque`
- `bounce_impulse`
- `upright_limit_degrees`
- `goal_hold_time`

## Tärkeä rakennepäätös

Älä tee päästä omaa `RigidBody2D`-kappaletta alkuvaiheessa. Pää on vain visuaali. Pelituntuman ydin on runko + kaksi jousijalkaa, ja erillinen fysiikkapää tekee tasapainosta tarpeettoman vaikean ennen kuin core loop toimii.

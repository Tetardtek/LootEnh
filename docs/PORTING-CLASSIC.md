# Portage Classic Era — état des lieux

> Branche `classic-era`. Cible : **WoW Classic Era 1.15.9** (frFR), client installé
> dans `_classic_era_`, où tournent déjà ElvUI, Details, Questie et WeakAuras.
>
> Ces addons servent de **preuve d'existence** : si l'un d'eux appelle une API,
> elle est disponible sur ce client. Mesuré, pas supposé.

---

## Le piège de départ

**Classic Era n'est pas un vieux client.** C'est un client moderne qui émule le
contenu vanilla — son API est *plus récente* que 3.3.5, pas plus ancienne. Porter,
c'est sauter par-dessus quinze ans d'évolutions, pas reculer.

---

## Pourquoi LootEnh d'abord

| | BagsEnh | **LootEnh** |
|---|---|---|
| API conteneurs (`C_Container`) | **57** occurrences | **0** |
| `InterfaceOptions_AddCategory` | 6 | 6 (+2 `OpenToCategory`) |
| `SetBackdrop` | 12 | 17 |
| `GetAddOnMetadata` | 2 | 0 |
| **Total** | **77** | **25** |
| Volume | 5 880 lignes | 5 395 lignes |

LootEnh n'a **aucune** dépendance aux conteneurs — c'est-à-dire au seul gros risque.
Sa surface tient en deux sujets, et **les deux sont communs à BagsEnh** : ce qu'on
règle ici se réapplique tel quel ensuite.

---

## Ce qui est établi

### ✅ Les API modernes existent bien sur 1.15.9

| API | Fichiers qui l'utilisent |
|---|---|
| `BackdropTemplate` | **150** |
| `C_Spell.GetSpellInfo` | 39 |
| `C_UnitAuras` | 16 |
| `CombatLogGetCurrentEventInfo` | 9 |
| `C_ChatInfo.SendAddonMessage` | 7 |
| `C_Container.*` | 2-3 |
| `Settings.RegisterCanvasLayoutCategory` | 2 |

### 🔴 Les anciennes globales de conteneurs, elles, sont MORTES

Relevé en jeu le 04/08 :

```
container: table: 000000003E2ED950   nil
           ^ C_Container existe      ^ GetContainerNumSlots = nil
canal:     function  function        (JoinChannelByName, SendChatMessage)
settings:  table     nil             (Settings, InterfaceOptions_AddCategory)
```

**Les 57 occurrences de BagsEnh sont bien à migrer.**

> ⚠️ **Leçon de méthode.** L'analyse statique disait le contraire : Details et
> LibOpenRaid appellent `GetContainerNumSlots` sans garde. Mais **un appel présent
> dans du code ne prouve pas que l'API existe** — c'est du chemin Retail jamais
> atteint sur ce client. Et le pont de Questie
> (`if C_Container then … elseif GetContainerNumSlots then`) ne disait pas « les
> deux coexistent », il disait « il faut gérer deux clients ».
>
> Trois greps concordants, une conclusion fausse, démolie par une ligne en jeu.
> Même motif que la sonde DelvEnh : seule l'exécution tranche.

---

## Les deux vrais chantiers de LootEnh

### 1. `SetBackdrop` — 17 occurrences, mécanique

L'API existe (134 fichiers l'utilisent), mais depuis Shadowlands elle exige que la
frame soit créée avec le bon gabarit :

```lua
CreateFrame("Frame", nom, parent)                      -- 3.3.5
CreateFrame("Frame", nom, parent, "BackdropTemplate")  -- moderne
```

Sans ça, `SetBackdrop` est nil sur la frame. Correction ligne à ligne, sans piège.

### 2. Les options — 8 occurrences, et une ironie

`InterfaceOptions_AddCategory` et `InterfaceOptionsFrame_OpenToCategory` sont
remplacés par `Settings.RegisterCanvasLayoutCategory` / `Settings.OpenToCategory`.

> **L'irritant fondateur du hub disparaît de lui-même.** La « boîte grise de 2006 »
> qui a déclenché tout le chantier AllEnh le 02/08 n'existe plus sur ce client :
> Blizzard l'a remplacée. Le contournement du double appel à
> `InterfaceOptionsFrame_OpenToCategory` — quinze ans de folklore — devient inutile.

---

## 🟢 Le mur redouté n'en est pas un — mais reste à moitié vérifié

**Le réseau du hub.** Tout le protocole `AE1^…` d'AllEnh passe par un canal de
discussion partagé, faute d'API réseau en 3.3.5.

`JoinChannelByName` **et** `SendChatMessage` existent tous deux sur 1.15.9 (relevé
en jeu). Le pattern FrostSeek n'est donc pas mort d'avance.

⚠️ **Mais exister n'est pas être autorisé.** Une fonction peut être présente et
refuser l'envoi programmatique. Le seul test qui tranche :

```
/run JoinChannelByName("enhtest")
/run SendChatMessage("ping", "CHANNEL", nil, GetChannelName("enhtest"))
```

Si le `ping` s'affiche, tout le réseau du hub est portable : contrôle de version,
recensement, roster. Sinon, `C_ChatInfo.SendAddonMessage` existe mais ne porte qu'en
guilde, groupe ou chuchotement — précisément l'angle mort que le canal couvrait.

Ça ne bloque pas LootEnh, qui se contente de se déclarer au hub. Ça décide de ce que
vaut AllEnh sur Classic Era.

---

## ✅ Test de sondage — fait le 04/08

```
/run print("container:", C_Container, GetContainerNumSlots, "| canal:", JoinChannelByName, SendChatMessage, "| settings:", Settings, InterfaceOptions_AddCategory)
```

| Résultat | Conséquence |
|---|---|
| `C_Container` table, `GetContainerNumSlots` **nil** | 🔴 les 57 occurrences de BagsEnh sont à migrer |
| `JoinChannelByName` + `SendChatMessage` **présents** | 🟢 le réseau du hub a une voie — envoi réel encore à tester |
| `Settings` table, `InterfaceOptions_AddCategory` **nil** | migration options obligatoire |

**Reste à faire** : le test d'envoi réel sur canal (ci-dessus).

---

## Ce qui disparaît, simplement

Le module Challenges d'AllEnh et tout ce qui touche au Mode Aventure sont
**Ascension-only**. Sur Classic Era ils n'ont pas d'objet — ce n'est pas un portage,
c'est une soustraction.

---

## Plan une fois le test fait

1. `.toc` — `## Interface: 11509`, éventuellement un fichier séparé pour cohabiter
   avec la version 3.3.5 sur le même dépôt.
2. `BackdropTemplate` sur les 17 frames concernées.
3. Options → `Settings`, en gardant un pont pour 3.3.5 si on veut un tronc commun.
4. Test en jeu, puis report des mêmes recettes sur BagsEnh.

---

## La question de fond — tronc commun ou branches divergentes ?

**Recommandation : tronc commun, avec un `Compat.lua` par addon.** Il résout une
fois au chargement quel client tourne et expose une API unique ; le reste du code
ignore la différence. Modèle : `QuestieCompat.lua`.

Deux branches qui divergent, c'est confortable six mois, puis c'est deux addons à
maintenir et un drift structurel.

> **Pourquoi ça ne contredit pas l'arbitrage du 02/08** sur le contrôle de version,
> où un fichier recopié dans trois dépôts a été refusé : ce protocole-là **évolue**,
> donc chaque changement doit être répercuté et le drift est certain. Un `Compat.lua`
> est **figé** — écrit une fois, jamais retouché après. *Ce qui dérive, c'est ce qui
> bouge.*

Corollaire pratique : la couche vit **dans chaque addon**, pas dans le hub. Sans elle
l'addon ne démarre pas — ce serait une dépendance dure, contraire à « chaque addon
reste complet seul ».

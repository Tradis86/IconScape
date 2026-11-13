# IconScape

**Adaptive Windows wallpaper that makes your desktop icons part of the scenery.**

> **IconScape is a modified version of [Deskland Preview](https://github.com/BLEZZ0102/Deskland)**, released under the same GPL-3.0 license. It is not an official Deskland release and is not endorsed by the Deskland authors. As they ask of modified distributions, it uses its own name and icon ([TRADEMARKS.md](TRADEMARKS.md)). Version 0.1.5, based on Deskland Preview 0.1.3; see [Changes from Deskland Preview](#changes-from-deskland-preview).

IconScape turns the space around your icons into a living landscape. Move, add or remove an icon and the beach, meadow, islands, clouds and shadows quietly reshape around it — in real time, without AI, an account or an API key.

**English** · [Italiano](#italiano) · [简体中文](#中文说明) · [Features](#features) · [Build from source](#build-from-source)

![Meadow theme](docs/images/meadow.webp)

![Beach theme](docs/images/beach.webp)

## Themes

From Deskland Preview:

| Beach | Meadow |
| --- | --- |
| ![Beach theme](prototype/thumbs/beach.webp) | ![Meadow theme](prototype/thumbs/meadow.webp) |
| Turquoise waves, kayaks, seabirds and coconut palms. | Drifting clouds and shadows, a boy flying a kite and a little black cat. |

Added in IconScape:

| Floating Isles | Circuit |
| --- | --- |
| ![Floating Isles theme](prototype/thumbs/isles.webp) | ![Circuit theme](prototype/thumbs/circuit.webp) |
| Grassy islands above a sea of clouds at dusk, dawn, day or night; glowing crystals, magic motes and a passing dragon. | A dark circuit board with copper pours under the icons, 45° traces, data pulses, LEDs and falling hex digits. |

| Steampunk | Cosmos |
| --- | --- |
| ![Steampunk theme](prototype/thumbs/steampunk.webp) | ![Cosmos theme](prototype/thumbs/cosmos.webp) |
| An old machine room drawn by hand in pencil and watercolour: rusty patched sheets, an iron beam and a plank floor with working corners (a boiler and its flue, tanks piped into the wall, a store, doors with ladders and catwalks, a workbench under the electrical board), meshing gears, pipes and gauges, lit windows, hanging lamps, sparrows, a patched airship. | Every group of icons is a star system: orbits follow its shape, planets travel along them, with nebulae, a spiral galaxy, shooting stars and comets. |

| Manga | Ninja Village |
| --- | --- |
| ![Manga theme](prototype/thumbs/manga.webp) | ![Ninja Village theme](prototype/thumbs/ninja.webp) |
| A black-and-white manga page: icons on ink splashes bursting with impact lines; panels of pen-and-hatching backgrounds (streets in perspective, the city at night, cumulonimbus and utility poles, mountains and pines, sea and rocks, bamboo, shrine steps, a pagoda under the moon) and sound effects, cherry petals and a passing crow; four ink-and-paper palettes. | A Japanese village drawn like a 1970s anime: houses seen from above with tiled hip roofs, white walls and timber, raked sand, flat colours with ink outlines, hard shadows and film grain, at night, sunset or day; an original ninja appears in smoke, leaps from roof to roof and throws a shuriken. |

| Storybook Woods |
| --- |
| ![Storybook Woods theme](prototype/thumbs/woodland.webp) |
| A picture-book wood drawn like a classic cartoon, with original characters: icons float on ponds with water lilies, frogs and families of ducklings; around them round trees, red toadstools and flowers, bunnies, foxes and hedgehogs out for a stroll, bluebirds and butterflies; by day, at sunset or at night with fireflies. |

The theme list contains only these nine themes. The locked preview cards of Deskland's paid Wallpaper edition, which Deskland Preview shows, are not part of IconScape.

## Features

- **Adaptive scenery:** uses the real positions of desktop icons and transitions smoothly when they move.
- **Nine complete themes:** every setting for Beach, Meadow, Floating Isles, Circuit, Steampunk, Cosmos, Manga, Ninja Village and Storybook Woods is included and saved between sessions.
- **Every monitor, one landscape:** the scene is computed over the whole desktop as your monitors are arranged, and each monitor shows its part: islands, coasts, clouds, boards and orbits continue from one monitor to the next, and a dragon, an airship or a comet crosses from one to the other. Monitors can be added, removed or rearranged while IconScape runs.
- **Made for the desktop:** tray controls, startup on sign-in and automatic pause of each monitor that a maximized or full-screen window covers, even when that window is not in the foreground.
- **Animations on or off:** the Animations switch in Settings, or Stop animations in the tray menu, keeps a still picture of the theme on every monitor; the choice is remembered.
- **Private sharing:** image and animation exports use sample icons and color blocks, never a screenshot of your desktop or real file names.
- **Independent installation:** IconScape uses its own install directory, settings, startup entry and instance identity, so it can coexist with Deskland.
- **Six languages:** English, Italian, Spanish, French, German and Simplified Chinese; "System default" follows Windows and falls back to English. No sign-in, purchase restoration, update service or store API is included.

## Requirements

- Windows 10 or Windows 11, 64-bit.
- Microsoft Edge WebView2 Runtime.
- PowerShell and the .NET Framework C# compiler included with Windows; no .NET SDK installation is required.
- An internet connection for the first build, which downloads the WebView2 development library.
- Node.js is optional: the browser preview can also be served with the included PowerShell script.

IconScape renders on **every connected monitor** and targets 30 fps on integrated graphics.

## Build from source

Open PowerShell in the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File host\build.ps1
host\bin\IconScape.exe
```

Keep `host/` and `prototype/` together. Build output is written to `host/bin/`.

Run the program again or double-click its tray icon to open Settings. To exit and restore the original Windows wallpaper, use the tray menu or run:

```powershell
host\bin\IconScape.exe --exit
```

Settings and logs are stored in `%LOCALAPPDATA%\IconScape`; shared images and clips in `Pictures\IconScape`. On the first start IconScape copies your settings from `%LOCALAPPDATA%\DesklandPreview` if that folder exists; an installed Deskland Preview keeps its own data.

## Browser preview

```powershell
node prototype\serve.mjs
```

Without Node.js, serve the same folder on the same port with:

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

Open **http://localhost:5178/settings.html**. The browser uses sample icons; adaptation to real desktop icons requires the Windows host.

## Windows installer

Build the NSIS installer without installing global development tools:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-installer.ps1
```

The first build downloads portable NSIS and Microsoft's WebView2 bootstrapper. Artifacts are written to `dist/` with SHA256 checksums and a matching source ZIP.

The installer targets the current user's `Programs\IconScape` directory and does not require administrator rights. If WebView2 is missing, its bootstrapper requires an internet connection. Uninstalling preserves user settings. No IconScape installer has been published: build it from source.

## macOS (experimental)

The `mac/` folder holds a macOS host written in Swift. It shows the same theme pages and settings page as the Windows host and speaks the same message protocol: one window per display above the desktop picture and below the Finder icons, icon positions read from Finder, a menu bar icon instead of the tray icon, and open at login. **It has not been tried on a real Mac yet.**

Build it on a Mac with macOS 11 or later and the Xcode command line tools (`xcode-select --install`):

```bash
bash mac/build.sh
open mac/build/IconScape.app
```

`bash mac/build.sh --dmg` also writes `dist/IconScape-<version>-mac.dmg` with its SHA256. Without a Mac, run the **macOS build** workflow from the repository's GitHub Actions (`.github/workflows/mac.yml`) and download the disk image from its artifacts.

- The first time, macOS asks whether IconScape may control Finder: that is how it reads where the desktop icons are. If you refuse, the landscape ignores the icons; you can allow it later in System Settings → Privacy & Security → Automation.
- The app is signed ad hoc, not with an Apple developer certificate: on another Mac, open it the first time with right click → Open (or allow it in System Settings → Privacy & Security).
- Settings and logs are stored in `~/Library/Application Support/IconScape`; shared images and clips in `~/Pictures/IconScape`; open at login is `~/Library/LaunchAgents/app.iconscape.IconScape.plist`. To quit from Terminal: `mac/build/IconScape.app/Contents/MacOS/IconScape --exit`.
- A display pauses while a window fills it or is full screen there, while the displays sleep or the screen is locked, and when the animations are stopped.

## Project layout

| Path | Contents |
| --- | --- |
| `host/` | Windows host, build scripts, application manifest and icon (`IconScape.ico`) |
| `prototype/flat.html` | Beach theme (from Deskland Preview) |
| `prototype/meadow.html` | Meadow theme (from Deskland Preview) |
| `prototype/isles.html` | Floating Isles theme |
| `prototype/circuit.html` | Circuit theme |
| `prototype/steam.html` | Steampunk theme |
| `prototype/cosmos.html` | Cosmos theme |
| `prototype/manga.html` | Manga theme |
| `prototype/ninja.html` | Ninja Village theme |
| `prototype/woodland.html` | Storybook Woods theme |
| `prototype/settings.html` | Settings interface |
| `prototype/themes.json` | Theme definitions: pages, parameters, defaults and thumbnails |
| `prototype/share.js` | Privacy-preserving image and animation sharing |
| `prototype/i18n/` | Interface and theme texts in English, Italian, Spanish, French and German, and the interface texts in Simplified Chinese (its theme texts are `themes.json` itself) |
| `prototype/assets/` | Images used by the included themes |
| `mac/` | macOS host: Swift sources (`mac/Sources/`), `Info.plist.in`, `build.sh` and the 1024 px icon; `.github/workflows/mac.yml` builds it on GitHub |
| `tools/` | Installer build tooling, the version number (`version.json`), the icon generator (`make-icon.ps1`) and the browser-preview server for machines without Node.js (`serve.ps1`) |

## Known limitations

- All monitors show the same theme and parameters; the settings preview and sharing use the primary monitor.
- The landscape is continuous across monitors with the same display scaling; with different scaling (for example 100% and 150%) things meet at the edge but their sizes differ. The boy and the cat (Meadow), kayaks, seabirds and palms (Beach), magic motes, steam, shooting stars and data pulses belong to a single monitor.
- Windows Spotlight or a wallpaper slideshow can briefly flash when Windows changes the background image.
- No account sign-in, entitlement restoration or automatic updates.

## Changes from Deskland Preview

Version 0.1.5, on top of Deskland Preview 0.1.3:

- **New name and icon:** IconScape, with its own executable, data folder, startup entry, install directory and instance identity.
- **Only included themes:** the 11 locked cards of the Deskland Wallpaper edition, with their purchase dialog and thumbnails, have been removed.
- **Multi-monitor:** one wallpaper window per monitor instead of the primary monitor only, showing its part of one landscape computed over the whole desktop; windows are created, moved or closed when the monitor layout changes.
- **Pause per monitor:** a monitor pauses when any maximized or full-screen window hides it, not only the foreground window; overlays that cover the screen without hiding anything are ignored.
- **Languages:** English is the main language, used whenever Windows uses a language that is not included; Italian, Spanish, French and German were added, and Simplified Chinese remains selectable. Settings, tray menu, messages, theme texts and the installer are translated; the share buttons and share error messages follow the interface language.
- **Stop animations:** the tray pause is now a saved setting, also available as a switch in Settings.
- **macOS host (experimental):** `mac/`, see [macOS](#macos-experimental).
- **Seven themes:** Floating Isles (with a choice of sky color), Circuit, Steampunk, Cosmos, Manga, Ninja Village and Storybook Woods. Their thumbnails are rendered from the themes themselves.
- **Browser preview without Node.js:** `tools/serve.ps1`.

## Credits and license

IconScape is based on [Deskland Preview](https://github.com/BLEZZ0102/Deskland) by the Deskland authors ([deskland.app](https://deskland.app)). Source code and included theme assets are released under [GPL-3.0](LICENSE); see [NOTICE](NOTICE). Third-party dependencies are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The Deskland name and icon belong to the Deskland project and are not licensed as trademarks; see [TRADEMARKS.md](TRADEMARKS.md). Please report IconScape problems to this project, not to the Deskland authors.

---

## Italiano

[English](#iconscape) · **Italiano** · [简体中文](#中文说明)

> **IconScape è una versione modificata di [Deskland Preview](https://github.com/BLEZZ0102/Deskland)**, distribuita con la stessa licenza GPL-3.0. Non è una release ufficiale di Deskland e non è approvata dai suoi autori. Come chiedono per le versioni modificate, usa un nome e un'icona propri ([TRADEMARKS.md](TRADEMARKS.md)). Versione 0.1.5, basata su Deskland Preview 0.1.3; vedi [Differenze rispetto a Deskland Preview](#differenze-rispetto-a-deskland-preview).

**Uno sfondo animato per Windows che rende le icone del desktop parte del paesaggio.**

IconScape trasforma lo spazio intorno alle icone in un paesaggio vivo. Sposta, aggiungi o elimina un'icona e spiaggia, prato, isole, nuvole e ombre si rimodellano intorno a lei, in tempo reale, senza IA, senza account e senza chiave API.

[Compilare dai sorgenti](#compilare-dai-sorgenti) · [Licenza](#crediti-e-licenza)

### Temi

Da Deskland Preview:

| Spiaggia | Prato |
| --- | --- |
| ![Tema Spiaggia](prototype/thumbs/beach.webp) | ![Tema Prato](prototype/thumbs/meadow.webp) |
| Onde turchesi, kayak, gabbiani e palme da cocco. | Nuvole che scorrono con le loro ombre, un bambino con l'aquilone e un gattino nero. |

Aggiunti in IconScape:

| Isole sospese | Circuito |
| --- | --- |
| ![Tema Isole sospese](prototype/thumbs/isles.webp) | ![Tema Circuito](prototype/thumbs/circuit.webp) |
| Isole erbose sopra un mare di nubi, con cielo al crepuscolo, all'alba, di giorno o di notte; cristalli luminosi, lucciole magiche e un drago di passaggio. | Un circuito stampato scuro con zone di rame sotto le icone, piste a 45°, impulsi di dati, LED e cifre esadecimali che cadono. |

| Steampunk | Universo |
| --- | --- |
| ![Tema Steampunk](prototype/thumbs/steampunk.webp) | ![Tema Universo](prototype/thumbs/cosmos.webp) |
| Una vecchia stanza delle macchine disegnata a mano, a matita e acquerello: lamiere arrugginite e rattoppate, una trave di ferro e un pavimento di assi con le postazioni di lavoro (caldaia con canna fumaria, serbatoi con i tubi nel muro, magazzino, porte con scale e passerelle, banco sotto il quadro elettrico), ingranaggi che ingranano, tubi e manometri, finestre accese, lampade appese, passerotti, un dirigibile rattoppato. | Ogni gruppo di icone è un sistema stellare: le orbite ne seguono la forma e i pianeti le percorrono, tra nebulose, una galassia a spirale, stelle cadenti e comete. |

| Manga | Villaggio ninja |
| --- | --- |
| ![Tema Manga](prototype/thumbs/manga.webp) | ![Tema Villaggio ninja](prototype/thumbs/ninja.webp) |
| Una tavola di manga in bianco e nero: le icone su macchie d'inchiostro da cui esplodono linee d'impatto; vignette di fondali a pennino e tratteggio (strade in prospettiva, città notturna, cumulonembi e pali della luce, montagne e pini, mare e scogli, bambù, santuario, pagoda sotto la luna) e onomatopee, petali di ciliegio e un corvo di passaggio; quattro combinazioni di inchiostro e carta. | Un villaggio giapponese disegnato come un anime degli anni Settanta: case viste dall'alto con tetti di tegole a padiglione, muri bianchi e travi, sabbia rastrellata, tinte piatte con contorni neri, ombre nette e grana di pellicola, di notte, al tramonto o di giorno; un ninja originale compare nel fumo, salta di tetto in tetto e lancia uno shuriken. |

| Bosco delle fiabe |
| --- |
| ![Tema Bosco delle fiabe](prototype/thumbs/woodland.webp) |
| Un bosco da libro di fiabe disegnato come un cartone animato classico, con personaggi originali: le icone galleggiano su stagni con ninfee, rane e famiglie di anatroccoli; intorno alberi tondi, funghi rossi e fiori, coniglietti, volpi e ricci che passeggiano, uccellini azzurri e farfalle; di giorno, al tramonto o di notte con le lucciole. |

L'elenco dei temi contiene solo questi nove. Le schede bloccate dell'edizione Wallpaper a pagamento di Deskland, presenti in Deskland Preview, non fanno parte di IconScape.

### Funzioni

- **Paesaggio adattivo:** usa le posizioni reali delle icone del desktop e passa in modo fluido da una disposizione all'altra quando si spostano.
- **Nove temi completi:** tutte le impostazioni di Spiaggia, Prato, Isole sospese, Circuito, Steampunk, Universo, Manga, Villaggio ninja e Bosco delle fiabe sono disponibili e vengono salvate.
- **Tutti i monitor, un solo paesaggio:** la scena è calcolata sull'intero desktop, così come sono disposti i monitor, e ogni monitor ne mostra la sua parte: isole, coste, nuvole, circuiti e orbite continuano da un monitor all'altro, e un drago, un dirigibile o una cometa passano dall'uno all'altro. I monitor si possono collegare, scollegare o ridisporre mentre IconScape è in esecuzione.
- **Pensato per il desktop:** controlli nell'area di notifica, avvio all'accesso e pausa automatica di ogni monitor coperto da una finestra massimizzata o a schermo intero, anche se quella finestra non è in primo piano.
- **Animazioni accese o spente:** l'interruttore Animazioni nelle impostazioni, o Ferma le animazioni nel menu dell'icona, lascia su ogni monitor un'immagine ferma del tema; la scelta viene ricordata.
- **Condivisione rispettosa della privacy:** immagini e animazioni usano icone di esempio e blocchi di colore, mai una cattura del desktop o i nomi veri dei file.
- **Installazione indipendente:** IconScape ha cartella di installazione, impostazioni, voce di avvio e identità dell'istanza proprie, quindi può convivere con Deskland.
- **Sei lingue:** inglese, italiano, spagnolo, francese, tedesco e cinese semplificato; «Predefinita di sistema» segue Windows e, per le altre lingue, usa l'inglese. Non sono inclusi accesso con account, ripristino degli acquisti, servizio di aggiornamento né interfacce dello store.

### Requisiti

- Windows 10 o Windows 11 a 64 bit.
- Microsoft Edge WebView2 Runtime.
- PowerShell e il compilatore C# di .NET Framework incluso in Windows; non serve installare il .NET SDK.
- Una connessione a Internet per la prima compilazione, che scarica la libreria di sviluppo di WebView2.
- Node.js è facoltativo: l'anteprima nel browser funziona anche con lo script PowerShell incluso.

IconScape disegna su **tutti i monitor collegati** con l'obiettivo di 30 fps su grafica integrata.

### Compilare dai sorgenti

Apri PowerShell nella cartella principale del repository:

```powershell
powershell -ExecutionPolicy Bypass -File host\build.ps1
host\bin\IconScape.exe
```

Tieni insieme `host/` e `prototype/`. Il programma compilato si trova in `host/bin/`.

Avvia di nuovo il programma o fai doppio clic sull'icona nell'area di notifica per aprire le impostazioni. Per uscire e ripristinare lo sfondo originale di Windows usa il menu dell'icona oppure esegui:

```powershell
host\bin\IconScape.exe --exit
```

Impostazioni e log sono salvati in `%LOCALAPPDATA%\IconScape`; immagini e animazioni condivise in `Immagini\IconScape`. Al primo avvio IconScape copia le tue impostazioni da `%LOCALAPPDATA%\DesklandPreview`, se la cartella esiste; un Deskland Preview installato conserva i propri dati.

### Anteprima nel browser

```powershell
node prototype\serve.mjs
```

Senza Node.js puoi servire la stessa cartella sulla stessa porta con:

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

Apri **http://localhost:5178/settings.html**. Nel browser si usano icone di esempio; l'adattamento alle icone reali del desktop richiede l'host per Windows.

### Installer per Windows

Compila l'installer NSIS senza installare strumenti di sviluppo globali:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-installer.ps1
```

La prima compilazione scarica NSIS in versione portatile e il programma di installazione di WebView2 di Microsoft. I file prodotti finiscono in `dist/`, con i checksum SHA256 e lo ZIP dei sorgenti corrispondenti.

L'installer installa nella cartella `Programs\IconScape` dell'utente corrente e non richiede diritti di amministratore. Se manca WebView2, serve una connessione a Internet per installarlo. La disinstallazione conserva le impostazioni dell'utente. Non è stato pubblicato alcun installer di IconScape: va compilato dai sorgenti.

### macOS (sperimentale)

La cartella `mac/` contiene un host per macOS scritto in Swift. Mostra le stesse pagine dei temi e delle impostazioni dell'host per Windows e usa lo stesso protocollo di messaggi: una finestra per ogni monitor sopra l'immagine della scrivania e sotto le icone del Finder, posizioni delle icone lette dal Finder, un'icona nella barra dei menu al posto dell'area di notifica e l'apertura all'accesso. **Non è ancora stato provato su un Mac reale.**

Si compila su un Mac con macOS 11 o successivo e gli strumenti da riga di comando di Xcode (`xcode-select --install`):

```bash
bash mac/build.sh
open mac/build/IconScape.app
```

`bash mac/build.sh --dmg` crea anche `dist/IconScape-<versione>-mac.dmg` con il suo SHA256. Senza un Mac, avvia il workflow **macOS build** dalle GitHub Actions del repository (`.github/workflows/mac.yml`) e scarica l'immagine disco dai suoi artifact.

- La prima volta macOS chiede se IconScape può controllare il Finder: è così che legge dove sono le icone della scrivania. Se rifiuti, il paesaggio ignora le icone; puoi consentirlo più tardi in Impostazioni di Sistema → Privacy e sicurezza → Automazione.
- L'app è firmata ad hoc, non con un certificato da sviluppatore Apple: su un altro Mac aprila la prima volta con clic destro → Apri (oppure consentila in Impostazioni di Sistema → Privacy e sicurezza).
- Impostazioni e log sono in `~/Library/Application Support/IconScape`; immagini e animazioni condivise in `~/Pictures/IconScape`; l'apertura all'accesso è `~/Library/LaunchAgents/app.iconscape.IconScape.plist`. Per uscire dal Terminale: `mac/build/IconScape.app/Contents/MacOS/IconScape --exit`.
- Un monitor va in pausa quando una finestra lo riempie o è a schermo intero su di esso, quando i monitor sono in stop o lo schermo è bloccato, e quando le animazioni sono ferme.

### Struttura del progetto

| Percorso | Contenuto |
| --- | --- |
| `host/` | Host per Windows, script di compilazione, manifest dell'applicazione e icona (`IconScape.ico`) |
| `prototype/flat.html` | Tema Spiaggia (da Deskland Preview) |
| `prototype/meadow.html` | Tema Prato (da Deskland Preview) |
| `prototype/isles.html` | Tema Isole sospese |
| `prototype/circuit.html` | Tema Circuito |
| `prototype/steam.html` | Tema Steampunk |
| `prototype/cosmos.html` | Tema Universo |
| `prototype/manga.html` | Tema Manga |
| `prototype/ninja.html` | Tema Villaggio ninja |
| `prototype/woodland.html` | Tema Bosco delle fiabe |
| `prototype/settings.html` | Interfaccia delle impostazioni |
| `prototype/themes.json` | Definizione dei temi: pagine, parametri, valori predefiniti e miniature |
| `prototype/share.js` | Condivisione di immagini e animazioni rispettosa della privacy |
| `prototype/i18n/` | Testi dell'interfaccia e dei temi in inglese, italiano, spagnolo, francese e tedesco, e testi dell'interfaccia in cinese semplificato (i testi cinesi dei temi sono `themes.json` stesso) |
| `prototype/assets/` | Immagini usate dai temi inclusi |
| `mac/` | Host per macOS: sorgenti Swift (`mac/Sources/`), `Info.plist.in`, `build.sh` e icona da 1024 px; `.github/workflows/mac.yml` lo compila su GitHub |
| `tools/` | Strumenti per l'installer, numero di versione (`version.json`), generatore dell'icona (`make-icon.ps1`) e server dell'anteprima per chi non ha Node.js (`serve.ps1`) |

### Limiti noti

- Tutti i monitor mostrano lo stesso tema con gli stessi parametri; l'anteprima delle impostazioni e la condivisione usano il monitor principale.
- Il paesaggio è continuo tra monitor con la stessa scala di visualizzazione; con scale diverse (per esempio 100% e 150%) le cose si incontrano sul bordo ma con dimensioni diverse. Il bambino e il gatto (Prato), kayak, gabbiani e palme (Spiaggia), lucciole magiche, vapore, stelle cadenti e impulsi di dati restano propri di ogni monitor.
- Con Windows Spotlight o una presentazione di sfondi, il cambio di immagine può causare un breve sfarfallio.
- Nessun accesso con account, ripristino degli acquisti o aggiornamento automatico.

### Differenze rispetto a Deskland Preview

Versione 0.1.5, basata su Deskland Preview 0.1.3:

- **Nome e icona nuovi:** IconScape, con eseguibile, cartella dei dati, voce di avvio, cartella di installazione e identità dell'istanza propri.
- **Solo i temi inclusi:** sono state tolte le 11 schede bloccate dell'edizione Wallpaper di Deskland, con la finestra di acquisto e le miniature.
- **Multi monitor:** una finestra di sfondo per ogni monitor invece del solo monitor principale, che mostra la propria parte di un unico paesaggio calcolato sull'intero desktop; le finestre vengono create, spostate o chiuse quando cambia la disposizione dei monitor.
- **Pausa per monitor:** un monitor va in pausa quando lo nasconde una qualsiasi finestra massimizzata o a schermo intero, non solo quella in primo piano; le sovrapposizioni che coprono lo schermo senza nascondere nulla vengono ignorate.
- **Lingue:** l'inglese è la lingua principale, usata quando Windows è in una lingua non inclusa; sono stati aggiunti italiano, spagnolo, francese e tedesco, e il cinese semplificato resta selezionabile. Impostazioni, menu dell'icona, messaggi, testi dei temi e installer sono tradotti; i pulsanti e gli errori della condivisione seguono la lingua dell'interfaccia.
- **Ferma le animazioni:** la pausa del menu dell'icona ora è un'impostazione salvata, disponibile anche come interruttore nelle impostazioni.
- **Host per macOS (sperimentale):** `mac/`, vedi [macOS](#macos-sperimentale).
- **Sette temi:** Isole sospese (con scelta del colore del cielo), Circuito, Steampunk, Universo, Manga, Villaggio ninja e Bosco delle fiabe. Le loro miniature sono generate dai temi stessi.
- **Anteprima nel browser senza Node.js:** `tools/serve.ps1`.

### Crediti e licenza

IconScape è basato su [Deskland Preview](https://github.com/BLEZZ0102/Deskland) degli autori di Deskland ([deskland.app](https://deskland.app)). Il codice sorgente e le risorse dei temi inclusi sono rilasciati con licenza [GPL-3.0](LICENSE); vedi [NOTICE](NOTICE). Le dipendenze di terze parti sono elencate in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Il nome e l'icona di Deskland appartengono al progetto Deskland e non sono concessi in licenza come marchi; vedi [TRADEMARKS.md](TRADEMARKS.md). Segnala i problemi di IconScape a questo progetto, non agli autori di Deskland.

---

## 中文说明

[English](#iconscape) · [Italiano](#italiano) · **简体中文**

> **IconScape 是 [Deskland Preview](https://github.com/BLEZZ0102/Deskland) 的修改版**，同样按 GPL-3.0 发布。它不是 Deskland 官方发布，也未获 Deskland 作者认可。按照作者对修改版的要求，它使用自己的名称和图标（见 [TRADEMARKS.md](TRADEMARKS.md)）。版本 0.1.5，基于 Deskland Preview 0.1.3，详见[与 Deskland Preview 的区别](#与-deskland-preview-的区别)。

**让桌面图标成为风景的一部分。**

IconScape 是一款 Windows 自适应动态壁纸。移动、添加或删除桌面图标时，海岸线、草地、岛屿、云朵和阴影会实时围绕图标调整。全部在本地实时演算，不使用 AI，无需账号或 API Key。

[从源码运行](#从源码运行) · [许可](#许可与反馈)

### 主题

来自 Deskland Preview：

| 沙滩 | 草地 |
| --- | --- |
| ![沙滩主题](prototype/thumbs/beach.webp) | ![草地主题](prototype/thumbs/meadow.webp) |
| 海浪、皮划艇、海鸟和椰子树。 | 漂浮的云与云影、放风筝的男孩和小黑猫。 |

IconScape 新增：

| 浮空岛 | 电路板 |
| --- | --- |
| ![浮空岛主题](prototype/thumbs/isles.webp) | ![电路板主题](prototype/thumbs/circuit.webp) |
| 云海之上的青草小岛，天空可选黄昏、日出、白天或夜晚；发光的水晶、飘动的萤火和偶尔飞过的龙。 | 深色电路板：图标下方是铺铜区，走线以 45° 延伸，还有数据脉冲、LED 和下落的十六进制数字。 |

| 蒸汽朋克 | 宇宙 |
| --- | --- |
| ![蒸汽朋克主题](prototype/thumbs/steampunk.webp) | ![宇宙主题](prototype/thumbs/cosmos.webp) |
| 铅笔加水彩手绘的旧机房：生锈打补丁的铁皮，铁梁和木地板之间的工作角（带烟道的锅炉、管道通进墙里的水箱、货堆、带梯子和走道的门、配电板下的工作台），咬合的齿轮、管道和压力表、亮灯的窗户、垂下的灯、麻雀和打补丁的飞艇。 | 每组图标都是一个恒星系：轨道顺着图标的形状展开，行星沿轨道运行，还有星云、旋涡星系、流星和彗星。 |

| 漫画 | 忍者之村 |
| --- | --- |
| ![漫画主题](prototype/thumbs/manga.webp) | ![忍者之村主题](prototype/thumbs/ninja.webp) |
| 黑白漫画的一页：图标落在迸出集中线的浓墨上；分镜格是钢笔排线画的背景（透视街道、夜晚城市、积雨云与电线杆、山与松、海与礁石、竹林、神社、月下五重塔），还有拟声词，樱花飘落，偶尔有乌鸦飞过；四种墨与纸的配色。 | 七十年代日本动画风格的村落：俯瞰的瓦顶房屋有白墙和木梁，周围是枯山水沙纹，平涂上色、黑色描线、硬朗阴影和胶片颗粒，可选夜晚、黄昏或白天；原创忍者在烟雾中现身，在屋顶间跳跃并掷出手里剑。 |

| 童话森林 |
| --- |
| ![童话森林主题](prototype/thumbs/woodland.webp) |
| 经典卡通风格的童话森林：图标浮在长满睡莲的池塘上，有青蛙和一家小鸭子；周围是圆圆的树、红色蘑菇和小花，小兔子、狐狸和刺猬在散步，还有小蓝鸟和蝴蝶；可选白天、黄昏或有萤火虫的夜晚。 |

主题列表只包含这九个主题。Deskland Preview 中展示的 Deskland 付费壁纸版锁定主题卡片不属于 IconScape。

### 功能

- **图标自适应：**读取真实桌面图标的位置，在移动、添加或删除时平滑调整场景。
- **九个完整主题：**沙滩、草地、浮空岛、电路板、蒸汽朋克、宇宙、漫画、忍者之村和童话森林的全部参数均可调整并自动保存。
- **所有显示器，一片风景：**场景按显示器的实际排列在整个桌面上计算，每个显示器显示其中的一部分：岛屿、海岸、云、电路和轨道从一个显示器延续到另一个，龙、飞艇或彗星会从一个显示器飞到另一个。运行中增减或重新排列显示器会自动调整。
- **适合常驻桌面：**托盘控制、开机自动启动；某个显示器被最大化或全屏窗口遮住时（即使该窗口不在前台）只暂停这个显示器。
- **动画开关：**设置中的“动画”开关或托盘菜单中的“停止动画”会让每个显示器停在主题的静止画面上，并记住这一选择。
- **隐私分享：**图片和动画使用示例图标与名字色块，不截取桌面窗口或真实文件名。
- **独立安装：**安装目录、用户数据、启动项和运行实例标识均独立，可与 Deskland 共存。
- **六种语言：**英文、意大利语、西班牙语、法语、德语和简体中文；“跟随系统”使用 Windows 的语言，其他语言时使用英文。不包含登录、购买恢复、自动更新或商店接口。

### 系统要求

- Windows 10 / Windows 11，64 位。
- Microsoft Edge WebView2 Runtime。
- 使用 Windows 自带的 .NET Framework C# 编译器，无需安装 .NET SDK。
- 第一次构建需要联网下载 WebView2 开发库。
- Node.js 可选：浏览器预览也可以用随附的 PowerShell 脚本提供。

IconScape 会覆盖**所有已连接的显示器**，以核显 30fps 为目标。

### 从源码运行

在仓库根目录打开 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File host\build.ps1
host\bin\IconScape.exe
```

请保持 `host/` 和 `prototype/` 的相对目录结构，编译结果位于 `host/bin/`。

再次运行程序或双击托盘图标可打开设置。退出并恢复系统原壁纸，请使用托盘菜单或执行：

```powershell
host\bin\IconScape.exe --exit
```

设置与日志保存在 `%LOCALAPPDATA%\IconScape`，分享的图片和动画保存在“图片\IconScape”。首次启动时，如果存在 `%LOCALAPPDATA%\DesklandPreview`，IconScape 会从中复制设置；已安装的 Deskland Preview 保留自己的数据。

### 浏览器预览

```powershell
node prototype\serve.mjs
```

没有 Node.js 时，可以用下面的脚本在同一端口提供同一目录：

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

打开 **http://localhost:5178/settings.html**。浏览器使用示例图标，真实桌面图标适配需要 Windows 宿主。

### Windows 安装包

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-installer.ps1
```

首次构建会下载便携版 NSIS 和微软 WebView2 引导程序，无需安装全局开发工具。产物位于 `dist/`，附 SHA256 校验文件和对应源码 ZIP。

安装包安装到当前用户的 `Programs\IconScape` 目录，无需管理员权限。缺少 WebView2 时需要联网安装；卸载保留用户设置。IconScape 尚未发布安装包，请从源码构建。

### macOS（实验性）

`mac/` 目录是用 Swift 编写的 macOS 宿主。它显示与 Windows 宿主相同的主题页面和设置页面，使用相同的消息协议：每个显示器一个窗口，位于桌面图片之上、访达图标之下；图标位置从访达读取；用菜单栏图标代替托盘图标；支持登录时打开。**尚未在真实的 Mac 上测试。**

在 macOS 11 或更高版本、装有 Xcode 命令行工具（`xcode-select --install`）的 Mac 上构建：

```bash
bash mac/build.sh
open mac/build/IconScape.app
```

`bash mac/build.sh --dmg` 还会生成 `dist/IconScape-<版本>-mac.dmg` 及其 SHA256。没有 Mac 时，可在仓库的 GitHub Actions 中运行 **macOS build** 工作流（`.github/workflows/mac.yml`），从产物中下载磁盘映像。

- 首次运行时 macOS 会询问是否允许 IconScape 控制“访达”：它通过访达读取桌面图标的位置。如果拒绝，风景会忽略图标；之后可在“系统设置 → 隐私与安全性 → 自动化”中允许。
- 应用只做了临时签名，没有 Apple 开发者证书：在其他 Mac 上第一次请右键 → 打开（或在“系统设置 → 隐私与安全性”中允许）。
- 设置与日志保存在 `~/Library/Application Support/IconScape`，分享的图片和动画保存在 `~/Pictures/IconScape`，登录时打开使用 `~/Library/LaunchAgents/app.iconscape.IconScape.plist`。从终端退出：`mac/build/IconScape.app/Contents/MacOS/IconScape --exit`。
- 当窗口铺满某个显示器或在其上全屏、显示器睡眠或屏幕锁定、以及停止动画时，该显示器暂停。

### 目录结构

| 路径 | 用途 |
| --- | --- |
| `host/` | Windows 宿主、构建脚本、清单与图标（`IconScape.ico`） |
| `prototype/flat.html` | 沙滩主题（来自 Deskland Preview） |
| `prototype/meadow.html` | 草地主题（来自 Deskland Preview） |
| `prototype/isles.html` | 浮空岛主题 |
| `prototype/circuit.html` | 电路板主题 |
| `prototype/steam.html` | 蒸汽朋克主题 |
| `prototype/cosmos.html` | 宇宙主题 |
| `prototype/manga.html` | 漫画主题 |
| `prototype/ninja.html` | 忍者之村主题 |
| `prototype/woodland.html` | 童话森林主题 |
| `prototype/settings.html` | 设置界面 |
| `prototype/themes.json` | 主题定义：页面、参数、默认值和缩略图 |
| `prototype/share.js` | 隐私保护的图片和动画分享 |
| `prototype/i18n/` | 英文、意大利语、西班牙语、法语和德语的界面与主题文字，以及简体中文界面文字（中文主题文字就是 `themes.json`） |
| `prototype/assets/` | 随附主题图片素材 |
| `mac/` | macOS 宿主：Swift 源码（`mac/Sources/`）、`Info.plist.in`、`build.sh` 和 1024 像素图标；`.github/workflows/mac.yml` 在 GitHub 上构建它 |
| `tools/` | 安装包构建工具、版本号（`version.json`）、图标生成脚本（`make-icon.ps1`）以及无 Node.js 时使用的浏览器预览服务（`serve.ps1`） |

### 已知限制

- 所有显示器使用同一主题和参数；设置预览与分享使用主显示器。
- 显示缩放相同的显示器之间风景是连续的；缩放不同（例如 100% 和 150%）时，边缘处能对上位置，但大小不同。男孩和小猫（草地）、皮划艇、海鸟和椰子树（沙滩）、萤火、蒸汽、流星和数据脉冲各属于一个显示器。
- 使用 Windows 聚焦或壁纸幻灯片时，系统换图可能造成短暂闪烁。
- 不提供账号登录、购买恢复或自动更新。

### 与 Deskland Preview 的区别

版本 0.1.5，基于 Deskland Preview 0.1.3：

- **新名称和图标：**IconScape，拥有独立的可执行文件、数据目录、启动项、安装目录和实例标识。
- **只保留包含的主题：**移除了 Deskland 壁纸版的 11 个锁定主题卡片、购买窗口和缩略图。
- **多显示器：**每个显示器一个壁纸窗口，不再只覆盖主显示器，各自显示在整个桌面上计算的同一片风景的一部分；显示器布局变化时自动创建、移动或关闭窗口。
- **按显示器暂停：**任何最大化或全屏窗口遮住某个显示器时暂停该显示器，不只看前台窗口；覆盖整个屏幕但不遮挡内容的悬浮层不会触发暂停。
- **语言：**英文是主要语言，Windows 使用未包含的语言时显示英文；新增意大利语、西班牙语、法语和德语，简体中文仍可选择。设置、托盘菜单、提示、主题文字和安装包均已翻译；分享按钮和分享错误信息跟随界面语言。
- **停止动画：**托盘菜单的暂停现在是会保存的设置，设置界面中也有对应开关。
- **macOS 宿主（实验性）：**`mac/`，见上文 macOS 一节。
- **七个主题：**浮空岛（可选天空颜色）、电路板、蒸汽朋克、宇宙、漫画、忍者之村和童话森林，缩略图由主题本身渲染生成。
- **无需 Node.js 的浏览器预览：**`tools/serve.ps1`。

### 许可与反馈

IconScape 基于 Deskland 作者的 [Deskland Preview](https://github.com/BLEZZ0102/Deskland)（[deskland.app](https://deskland.app)）。项目源码和随附主题素材按 [GPL-3.0](LICENSE) 发布，见 [NOTICE](NOTICE)；第三方依赖见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

Deskland 名称与图标属于 Deskland 项目，不作为商标授权授予，详见 [TRADEMARKS.md](TRADEMARKS.md)。IconScape 的问题请反馈给本项目，而不是 Deskland 作者。

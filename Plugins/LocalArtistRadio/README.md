# Local Artist Radio

Local Artist Radio is a Lyrion Music Server 9.x plugin. It adds a **Local
Artist Radio** button to Material Skin's artist view and also keeps the action
in the artist's **More** menu. It continuously fills the active player's queue
with:

- local, readable `file://` tracks only;
- the selected artist and locally available similar artists from Last.fm;
- a six-track artist cooldown, relaxed only when the local library is too
  small to keep playback running.

The first track is always from the selected artist. If Last.fm is unavailable,
the plugin continues with local tracks by the selected artist.

## Requirements

- Lyrion Music Server 9.x
- Material Skin
- LastMix 2.4.2 or newer, enabled
- Don't Stop The Music, enabled

LastMix provides the authenticated Last.fm adapter. This plugin never asks an
online music service for playable tracks.

## Installation

Extract the release archive into the LMS `Plugins` directory so the final path
is `Plugins/LocalArtistRadio/Plugin.pm`, then restart LMS. Install and enable
LastMix and Don't Stop The Music before enabling Local Artist Radio.

In Material Skin, open an artist and select **Local Artist Radio** next to the
standard artist mix button. After the first installation or an update, reload
Material Skin once while bypassing the browser cache.

The button is integrated through Material Skin's supported `custom.js` file.
Existing custom JavaScript is preserved.

The standard LastMix action remains available separately and does not have the
strict local-only guarantee of this plugin.

## CLI

```text
<player-id> localartistradio play artist_id:<id>
<player-id> localartistradio stop
```

## License

GPL-2.0-or-later

# Local Artist Radio for Lyrion Music Server

Local Artist Radio creates a continuous mix from locally available music by a
selected artist and similar artists reported by Last.fm. Playback remains
restricted to local files.

## Requirements

- Lyrion Music Server 9.x
- LastMix 2.4.2 or newer
- Don't Stop The Music

Material Skin is optional. When enabled, the plugin adds a dedicated button to
its artist view.

## Install from the LMS plugin manager

Add this URL under **Settings > Plugins > Additional Repositories**:

```text
https://raw.githubusercontent.com/th80de/lms-local-artist-radio/main/extensions.xml
```

Save the LMS plugin settings, select **Local Artist Radio**, and restart LMS
when prompted.

## Development

The plugin source is in `Plugins/LocalArtistRadio`. Run the tests with:

```sh
prove -I. -v t
```

## License

GPL-2.0-or-later

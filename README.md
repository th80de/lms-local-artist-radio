# Local Artist Radio for Lyrion Music Server

Local Artist Radio creates a continuous mix from locally available music by a
selected artist and similar artists reported by Last.fm. Playback remains
restricted to local files.

## Requirements

- Lyrion Music Server 9.x
- Material Skin
- LastMix 2.4.2 or newer
- Don't Stop The Music

## Install from the LMS plugin manager

After publishing this repository publicly on GitHub and creating the first
release, enable GitHub Pages with **GitHub Actions** as its source. LMS cannot
download releases or repository metadata from a private GitHub repository.

Add this URL under **Settings > Plugins > Additional Repositories** in LMS:

```text
https://GITHUB-USER.github.io/REPOSITORY/extensions.xml
```

For example, a repository named `lms-local-artist-radio` owned by
`example-user` would use:

```text
https://example-user.github.io/lms-local-artist-radio/extensions.xml
```

Save the LMS plugin settings, select **Local Artist Radio**, and restart LMS
when prompted.

When migrating an existing manual installation, keep **Local Artist Radio**
selected when saving the plugin settings. LMS can then manage the existing
installation and future updates through this repository.

## Development

The plugin source is in `Plugins/LocalArtistRadio`. Run the tests with:

```sh
prove -I. -v t
```

Build the installable archive with:

```sh
./scripts/build-release.sh
```

Generate an LMS repository file locally with:

```sh
./scripts/build-repository.sh GITHUB-USER/REPOSITORY
```

## Publishing a release

Create an empty GitHub repository, then connect and push this local repository:

```sh
git remote add origin git@github.com:GITHUB-USER/REPOSITORY.git
git add .
git commit -m "Initial Local Artist Radio release"
git push -u origin main
```

Enable **Settings > Pages > Build and deployment > Source: GitHub Actions**.

For each release:

1. Update the version in `Plugins/LocalArtistRadio/install.xml`.
2. Update `CHANGELOG.md`.
3. Commit and push the changes to the `main` branch.
4. Create and push a matching version tag:

```sh
git tag v0.2.0
git push origin main
git push origin v0.2.0
```

The release workflow tests the plugin, builds the ZIP, calculates the SHA-1
required by LMS, creates the GitHub release, and publishes `extensions.xml`
through GitHub Pages.

## License

GPL-2.0-or-later

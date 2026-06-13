use strict;
use warnings;

use Test::More;

my $root = 'Plugins/LocalArtistRadio';

for my $file (qw(
	Plugin.pm
	ProtocolHandler.pm
	Mixer.pm
	Selector.pm
	LocalLibrary.pm
	LastFm.pm
	install.xml
	strings.txt
	README.md
	LICENSE
	HTML/EN/plugins/LocalArtistRadio/html/material-button.js
)) {
	ok(-f "$root/$file", "$file is packaged");
}

open my $install, '<', "$root/install.xml" or die $!;
my $xml = do { local $/; <$install> };
close $install;

like($xml, qr{<module>Plugins::LocalArtistRadio::Plugin</module>}, 'manifest module is correct');
like($xml, qr{<minVersion>9\.0</minVersion>}, 'manifest targets LMS 9');
like($xml, qr{<version>0\.2\.0</version>}, 'manifest version is set');

open my $library, '<', "$root/LocalLibrary.pm" or die $!;
my $source = do { local $/; <$library> };
close $library;

like($source, qr{tracks\.url LIKE 'file://%'}, 'database query is restricted to file URLs');
like($source, qr{COALESCE\(tracks\.remote, 0\) = 0}, 'database query excludes remote tracks');

open my $plugin, '<', "$root/Plugin.pm" or die $!;
my $plugin_source = do { local $/; <$plugin> };
close $plugin;

like(
	$plugin_source,
	qr{\$client->execute\(\[\s*'playlist',\s*'loadtracks'},
	'initial playlist load stays bound to the LMS client',
);
unlike(
	$plugin_source,
	qr{Slim::Control::Request->new\(\s*\$client},
	'does not pass a client object where LMS expects a client ID',
);
like(
	$plugin_source,
	qr{BEGIN LocalArtistRadio},
	'defines the start marker for its Material Skin custom.js block',
);
like(
	$plugin_source,
	qr{material-button\.js\?v=\$version},
	'installs a versioned Material Skin JavaScript loader',
);
like(
	$plugin_source,
	qr{END LocalArtistRadio},
	'defines the end marker for its Material Skin custom.js block',
);

open my $material_button, '<', "$root/HTML/EN/plugins/LocalArtistRadio/html/material-button.js"
	or die $!;
my $material_button_source = do { local $/; <$material_button> };
close $material_button;

like(
	$material_button_source,
	qr{artist_id:' \+ artistId},
	'Material button sends the selected artist ID',
);
like(
	$material_button_source,
	qr{'localartistradio',\s*'play'},
	'Material button invokes the local radio command',
);

for my $repository_file (qw(
	.github/workflows/test.yml
	.github/workflows/release.yml
	scripts/plugin-version.sh
	scripts/build-repository.sh
	CHANGELOG.md
)) {
	ok(-f $repository_file, "$repository_file supports GitHub distribution");
}

done_testing;

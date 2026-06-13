use strict;
use warnings;

use Digest::SHA qw(sha1_hex);
use Test::More;

my $repository = 'example-user/lms-local-artist-radio';
my $version = qx{./scripts/plugin-version.sh};
chomp $version;

is($? >> 8, 0, 'reads the plugin version');
is($version, '0.2.0', 'repository test uses the current plugin version');

is(system('./scripts/build-release.sh'), 0, 'builds the release archive');
is(
	system('./scripts/build-repository.sh', $repository),
	0,
	'builds the LMS repository file',
);

my $archive = "dist/LocalArtistRadio-$version.zip";
open my $zip, '<', $archive or die $!;
binmode $zip;
my $archive_content = do { local $/; <$zip> };
close $zip;
my $expected_sha = sha1_hex($archive_content);

open my $xml_file, '<', 'dist/extensions.xml' or die $!;
my $xml = do { local $/; <$xml_file> };
close $xml_file;

like(
	$xml,
	qr{<plugin name="LocalArtistRadio" version="\Q$version\E"},
	'repository advertises the manifest version',
);
like(
	$xml,
	qr{https://github\.com/\Q$repository\E/releases/download/v\Q$version\E/LocalArtistRadio-\Q$version\E\.zip},
	'repository points to the matching GitHub release asset',
);
like(
	$xml,
	qr{<sha>\Q$expected_sha\E</sha>},
	'repository contains the release archive SHA-1',
);

done_testing;

use strict;
use warnings;

use Test::More;

BEGIN {
	package Slim::Music::Info;
	sub import {}
	sub isFile { 1 }
	$INC{'Slim/Music/Info.pm'} = 1;

	package Slim::Schema;
	sub import {}
	$INC{'Slim/Schema.pm'} = 1;

	package Slim::Utils::Text;
	sub import {}
	sub ignoreCase { lc $_[1] }
	$INC{'Slim/Utils/Text.pm'} = 1;
}

use lib '.';
use Plugins::LocalArtistRadio::LocalLibrary;

my $rows = [
	{ url => 'file:///music/a.mp3', artist_id => 1 },
	{ url => 'FILE:///music/b.flac', artist_id => 2 },
	{ url => 'https://service.example/track', artist_id => 3 },
	{ url => 'qobuz://123', artist_id => 4 },
	{ url => 'file:///music/missing.aac', artist_id => 5 },
	{ url => 'file:///music/a.mp3', artist_id => 1 },
	{ url => 'file:///music/a.mp3', artist_id => 6 },
];

my $filtered = Plugins::LocalArtistRadio::LocalLibrary->filter_local_rows(
	$rows,
	sub { $_[0] !~ /missing/ },
);

is_deeply(
	[map { [$_->{url}, $_->{artist_id}] } @$filtered],
	[
		['file:///music/a.mp3', 1],
		['FILE:///music/b.flac', 2],
		['file:///music/a.mp3', 6],
	],
	'keeps readable local files and rejects online protocols',
);

done_testing;

use strict;
use warnings;

use Test::More;

BEGIN {
	package Slim::Music::Info;
	sub import {}
	$INC{'Slim/Music/Info.pm'} = 1;

	package Slim::Schema;
	sub import {}
	$INC{'Slim/Schema.pm'} = 1;

	package Slim::Utils::Text;
	sub import {}
	$INC{'Slim/Utils/Text.pm'} = 1;
}

use lib '.';
use Plugins::LocalArtistRadio::Mixer;

my $lastfm_calls = 0;

{
	no warnings 'redefine';

	local *Plugins::LocalArtistRadio::LocalLibrary::contributor = sub {
		return {
			id => 1,
			name => 'Seed Artist',
			mbid => 'seed-mbid',
			weight => 1,
		};
	};

	local *Plugins::LocalArtistRadio::LastFm::similar_artists = sub {
		my ($class, $seed, $callback) = @_;
		$lastfm_calls++;
		$callback->([
			{ name => 'Similar Artist', mbid => 'similar-mbid', match => 0.9 },
		], undef);
	};

	local *Plugins::LocalArtistRadio::LocalLibrary::resolve_similar_artists = sub {
		return [{
			id => 2,
			name => 'Similar Artist',
			mbid => 'similar-mbid',
			weight => 0.9,
		}];
	};

	local *Plugins::LocalArtistRadio::LocalLibrary::tracks_for_artists = sub {
		my @tracks;
		for my $artist (1 .. 2) {
			for my $track (1 .. 6) {
				push @tracks, {
					url => "file:///music/$artist-$track.flac",
					artist_id => $artist,
					artist_name => "Artist $artist",
					weight => 1,
				};
			}
		}
		return \@tracks;
	};

	my $state = {
		seed_artist_id => 1,
		force_seed_first => 1,
		recent_artists => [],
		used_urls => {},
	};

	my ($first, $first_error);
	Plugins::LocalArtistRadio::Mixer->build_batch(
		state => $state,
		count => 5,
		callback => sub {
			($first, undef, $first_error) = @_;
		},
	);

	is($lastfm_calls, 1, 'queries Last.fm for the first batch');
	is(scalar @$first, 5, 'builds first batch');
	like($first->[0], qr{/1-\d+\.flac$}, 'first batch starts with seed artist');
	ok(!$first_error, 'first batch has no error');

	my $second;
	Plugins::LocalArtistRadio::Mixer->build_batch(
		state => $state,
		count => 3,
		callback => sub {
			($second) = @_;
		},
	);

	is($lastfm_calls, 1, 'reuses similar artists for refill');
	is(scalar @$second, 3, 'builds refill batch');
}

{
	no warnings 'redefine';

	local *Plugins::LocalArtistRadio::LocalLibrary::contributor = sub {
		return { id => 7, name => 'Offline Seed', mbid => '', weight => 1 };
	};
	local *Plugins::LocalArtistRadio::LastFm::similar_artists = sub {
		my ($class, $seed, $callback) = @_;
		$callback->([], 'network unavailable');
	};
	local *Plugins::LocalArtistRadio::LocalLibrary::resolve_similar_artists = sub { [] };
	local *Plugins::LocalArtistRadio::LocalLibrary::tracks_for_artists = sub {
		return [
			map {
				{
					url => "file:///offline/$_.mp3",
					artist_id => 7,
					artist_name => 'Offline Seed',
					weight => 1,
				}
			} 1 .. 4
		];
	};

	my ($tracks, $error);
	Plugins::LocalArtistRadio::Mixer->build_batch(
		state => {
			seed_artist_id => 7,
			force_seed_first => 1,
			recent_artists => [],
			used_urls => {},
		},
		count => 4,
		callback => sub {
			($tracks, undef, $error) = @_;
		},
	);

	is(scalar @$tracks, 4, 'falls back to seed tracks when Last.fm fails');
	ok(!$error, 'successful seed fallback does not report an error');
}

done_testing;

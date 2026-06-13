use strict;
use warnings;

use Test::More;

use lib '.';
use Plugins::LocalArtistRadio::Selector;

my @candidates;
for my $artist (1 .. 8) {
	for my $track (1 .. 3) {
		push @candidates, {
			url => "file:///music/$artist-$track.flac",
			artist_id => $artist,
			artist_name => "Artist $artist",
			weight => 1,
		};
	}
}

my @random_values = map { ($_ % 97) / 97 } 1 .. 500;
my $random = sub { shift(@random_values) // 0.5 };
my $state = {};

my ($selected, $updated) = Plugins::LocalArtistRadio::Selector->select_tracks(
	candidates => \@candidates,
	state => $state,
	count => 16,
	cooldown => 6,
	seed_artist_id => 1,
	force_artist_id => 1,
	random => $random,
);

is(scalar @$selected, 16, 'selects requested number of tracks');
is($selected->[0]->{artist_id}, 1, 'starts with the seed artist');

my %last_position;
for my $index (0 .. $#$selected) {
	my $artist = $selected->[$index]->{artist_id};
	if (exists $last_position{$artist}) {
		cmp_ok(
			$index - $last_position{$artist},
			'>',
			6,
			"artist $artist observes six-track cooldown",
		);
	}
	$last_position{$artist} = $index;
}

my %urls = map { $_->{url} => 1 } @$selected;
is(scalar keys %urls, 16, 'does not repeat a track before the pool is exhausted');
cmp_ok(scalar @{$updated->{recent_artists}}, '<=', 6, 'keeps bounded cooldown history');
my $seed_count = grep { $_->{artist_id} == 1 } @$selected;
cmp_ok($seed_count, '<=', 2, 'keeps the seed artist less frequent than the mix');

my @small_pool = map {
	{
		url => "file:///small/$_-1.mp3",
		artist_id => $_,
		artist_name => "Small $_",
		weight => 1,
	}
} 1 .. 2;

my ($relaxed) = Plugins::LocalArtistRadio::Selector->select_tracks(
	candidates => \@small_pool,
	state => {},
	count => 6,
	cooldown => 6,
	seed_artist_id => 1,
	force_artist_id => 1,
	random => sub { 0 },
);

is(scalar @$relaxed, 6, 'relaxes cooldown when the local library is too small');
is($relaxed->[0]->{artist_id}, 1, 'small-pool radio still starts with seed');
isnt($relaxed->[0]->{artist_id}, $relaxed->[1]->{artist_id}, 'uses another artist before relaxing further');

done_testing;

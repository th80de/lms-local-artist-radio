package Plugins::LocalArtistRadio::Mixer;

use strict;
use warnings;

use Plugins::LocalArtistRadio::LastFm;
use Plugins::LocalArtistRadio::LocalLibrary;
use Plugins::LocalArtistRadio::Selector;

use constant ARTIST_COOLDOWN => 6;

sub build_batch {
	my ($class, %args) = @_;

	my $state = $args{state} || {};
	my $callback = $args{callback} || sub {};
	my $count = $args{count} || 5;
	my $seed = Plugins::LocalArtistRadio::LocalLibrary->contributor($state->{seed_artist_id});

	if (!$seed) {
		$callback->([], $state, 'Seed artist was not found');
		return;
	}

	my $finish = sub {
		my ($similar, $lastfm_error) = @_;
		$similar ||= [];

		my $resolved = Plugins::LocalArtistRadio::LocalLibrary->resolve_similar_artists(
			$similar,
			$seed->{id},
		);

		my @artists = (
			{
				%$seed,
				weight => 1,
			},
			@$resolved,
		);

		my $candidates = Plugins::LocalArtistRadio::LocalLibrary->tracks_for_artists(\@artists);
		my ($selected) = Plugins::LocalArtistRadio::Selector->select_tracks(
			candidates => $candidates,
			state => $state,
			count => $count,
			cooldown => ARTIST_COOLDOWN,
			seed_artist_id => $seed->{id},
			force_artist_id => $state->{force_seed_first} ? $seed->{id} : undef,
		);

		$state->{force_seed_first} = 0 if @$selected;
		my @urls = map { $_->{url} } @$selected;
		my $error = @urls ? undef : ($lastfm_error || 'No local tracks were found');
		$callback->(\@urls, $state, $error);
	};

	if (exists $state->{similar_artists}) {
		$finish->($state->{similar_artists}, $state->{lastfm_error});
		return;
	}

	Plugins::LocalArtistRadio::LastFm->similar_artists($seed, sub {
		my ($similar, $error) = @_;
		$state->{similar_artists} = $similar || [];
		$state->{lastfm_error} = $error if $error;
		$finish->($state->{similar_artists}, $error);
	});
}

1;

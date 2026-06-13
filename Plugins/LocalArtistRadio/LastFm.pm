package Plugins::LocalArtistRadio::LastFm;

use strict;
use warnings;

sub similar_artists {
	my ($class, $seed, $callback) = @_;

	my $loaded = eval {
		require Plugins::LastMix::LFM;
		1;
	};

	if (!$loaded) {
		$callback->([], "LastMix LFM module is unavailable: $@");
		return;
	}

	my $args = {
		artist => $seed->{name},
	};
	$args->{mbid} = $seed->{mbid} if $seed->{mbid};

	my $started = eval {
		Plugins::LastMix::LFM->getSimilarArtists(sub {
			my $result = shift || {};
			my $artists = eval {
				$result->{similarartists}->{artist};
			};

			if (!$artists || ref $artists ne 'ARRAY') {
				my $error = $result->{message} || $result->{error} || 'No similar artists returned';
				$callback->([], $error);
				return;
			}

			my %seen;
			my @parsed = grep {
				$_->{name} && !$seen{lc $_->{name}}++
			} map {
				{
					name => $_->{name},
					mbid => $_->{mbid} || '',
					match => $_->{match},
				}
			} @$artists;

			$callback->(\@parsed, undef);
		}, $args);
		1;
	};

	$callback->([], "Last.fm request failed: $@") unless $started;
}

1;

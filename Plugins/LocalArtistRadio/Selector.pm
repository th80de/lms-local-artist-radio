package Plugins::LocalArtistRadio::Selector;

use strict;
use warnings;

sub select_tracks {
	my ($class, %args) = @_;

	my $candidates = $args{candidates} || [];
	my $state = $args{state} || {};
	my $count = $args{count} || 1;
	my $cooldown = defined $args{cooldown} ? $args{cooldown} : 6;
	my $random = $args{random} || sub { rand() };

	$state->{recent_artists} ||= [];
	$state->{used_urls} ||= {};
	$state->{artist_counts} ||= {};

	my @pool = grep {
		defined $_->{url} && defined $_->{artist_id}
	} @$candidates;

	my @selected;

	if ($args{force_artist_id} && !@{$state->{recent_artists}}) {
		my @seed = grep {
			$_->{artist_id} eq $args{force_artist_id}
				&& !$state->{used_urls}->{$_->{url}}
		} @pool;

		if (@seed) {
			my $track = _pick_track(\@seed, $random);
			_record($track, $state, $cooldown);
			push @selected, $track;
		}
	}

	while (@selected < $count && @pool) {
		my @unused = grep { !$state->{used_urls}->{$_->{url}} } @pool;

		if (!@unused) {
			$state->{used_urls} = {};
			@unused = @pool;
		}

		my $track;
		for (my $gap = $cooldown; $gap >= 0; $gap--) {
			my %blocked = map { $_ => 1 } _tail($state->{recent_artists}, $gap);
			my @eligible = grep { !$blocked{$_->{artist_id}} } @unused;
			next unless @eligible;

			$track = _pick_weighted(
				\@eligible,
				$args{seed_artist_id},
				$state,
				$random,
			);
			last if $track;
		}

		last unless $track;

		_record($track, $state, $cooldown);
		push @selected, $track;
	}

	return (\@selected, $state);
}

sub _pick_weighted {
	my ($candidates, $seed_artist_id, $state, $random) = @_;

	my %by_artist;
	for my $candidate (@$candidates) {
		push @{$by_artist{$candidate->{artist_id}}}, $candidate;
	}

	my @artists = sort { "$a" cmp "$b" } keys %by_artist;
	return unless @artists;

	my %adjusted_count;
	my $minimum_count;
	for my $artist_id (@artists) {
		my $count = $state->{artist_counts}->{$artist_id} || 0;
		$count += 0.65 if defined $seed_artist_id && $artist_id eq $seed_artist_id;
		$adjusted_count{$artist_id} = $count;
		$minimum_count = $count if !defined $minimum_count || $count < $minimum_count;
	}

	@artists = grep {
		$adjusted_count{$_} <= $minimum_count + 0.001
	} @artists;

	my @weights;
	my $total = 0;
	for my $artist_id (@artists) {
		my $weight = 0;
		for my $candidate (@{$by_artist{$artist_id}}) {
			my $candidate_weight = $candidate->{weight};
			$candidate_weight = 1 unless defined $candidate_weight && $candidate_weight > 0;
			$weight = $candidate_weight if $candidate_weight > $weight;
		}

		$weight *= 0.35 if defined $seed_artist_id && $artist_id eq $seed_artist_id;
		$weight = 0.05 if $weight < 0.05;
		push @weights, $weight;
		$total += $weight;
	}

	my $point = $random->() * $total;
	my $artist_id = $artists[-1];
	for my $index (0 .. $#artists) {
		$point -= $weights[$index];
		if ($point < 0) {
			$artist_id = $artists[$index];
			last;
		}
	}

	return _pick_track($by_artist{$artist_id}, $random);
}

sub _pick_track {
	my ($tracks, $random) = @_;
	return unless @$tracks;

	my $index = int($random->() * scalar @$tracks);
	$index = $#$tracks if $index > $#$tracks;
	return $tracks->[$index];
}

sub _record {
	my ($track, $state, $cooldown) = @_;

	$state->{used_urls}->{$track->{url}} = 1;
	$state->{artist_counts}->{$track->{artist_id}}++;
	push @{$state->{recent_artists}}, $track->{artist_id};

	while (@{$state->{recent_artists}} > $cooldown) {
		shift @{$state->{recent_artists}};
	}
}

sub _tail {
	my ($items, $count) = @_;
	return () unless $count && @$items;

	my $start = @$items - $count;
	$start = 0 if $start < 0;
	return @$items[$start .. $#$items];
}

1;

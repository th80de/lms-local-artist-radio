package Plugins::LocalArtistRadio::LocalLibrary;

use strict;
use warnings;

use Slim::Music::Info;
use Slim::Schema;
use Slim::Utils::Text;

use constant PERFORMER_ROLES => (1, 5, 6);

sub contributor {
	my ($class, $id) = @_;
	return unless defined $id;

	my $artist = Slim::Schema->find('Contributor', $id);
	return unless $artist;

	return {
		id => $artist->id,
		name => $artist->name,
		mbid => $artist->musicbrainz_id || '',
		weight => 1,
	};
}

sub resolve_similar_artists {
	my ($class, $artists, $seed_id) = @_;

	my $dbh = Slim::Schema->dbh;
	my %seen;
	my @resolved;

	for my $artist (@{$artists || []}) {
		next unless $artist->{name};

		my $row;
		if ($artist->{mbid}) {
			$row = $dbh->selectrow_hashref(
				'SELECT id, name, musicbrainz_id FROM contributors WHERE musicbrainz_id = ? LIMIT 1',
				undef,
				$artist->{mbid},
			);
		}

		if (!$row) {
			my $search_name = Slim::Utils::Text::ignoreCase($artist->{name}, 1);
			$row = $dbh->selectrow_hashref(
				'SELECT id, name, musicbrainz_id FROM contributors WHERE namesearch = ? LIMIT 1',
				undef,
				$search_name,
			);
		}

		next unless $row && defined $row->{id};
		next if defined $seed_id && $row->{id} eq $seed_id;
		next if $seen{$row->{id}}++;

		push @resolved, {
			id => $row->{id},
			name => $row->{name},
			mbid => $row->{musicbrainz_id} || '',
			weight => _similarity_weight($artist->{match}),
		};
	}

	return \@resolved;
}

sub tracks_for_artists {
	my ($class, $artists) = @_;

	my @artists = grep { defined $_->{id} } @{$artists || []};
	return [] unless @artists;

	my %metadata = map { $_->{id} => $_ } @artists;
	my @ids = keys %metadata;
	my @roles = PERFORMER_ROLES;
	my $id_placeholders = join(',', ('?') x @ids);
	my $role_placeholders = join(',', ('?') x @roles);

	my $sql = qq{
		SELECT DISTINCT
			tracks.id AS track_id,
			tracks.url AS url,
			contributors.id AS artist_id,
			contributors.name AS artist_name
		FROM tracks
		JOIN contributor_track
			ON contributor_track.track = tracks.id
		JOIN contributors
			ON contributors.id = contributor_track.contributor
		WHERE contributor_track.contributor IN ($id_placeholders)
			AND contributor_track.role IN ($role_placeholders)
			AND tracks.audio = 1
			AND COALESCE(tracks.remote, 0) = 0
			AND tracks.url LIKE 'file://%'
	};

	my $rows = Slim::Schema->dbh->selectall_arrayref(
		$sql,
		{ Slice => {} },
		@ids,
		@roles,
	) || [];

	for my $row (@$rows) {
		my $artist = $metadata{$row->{artist_id}} || {};
		$row->{weight} = $artist->{weight} || 1;
	}

	return $class->filter_local_rows(
		$rows,
		sub { Slim::Music::Info::isFile($_[0]) },
	);
}

sub filter_local_rows {
	my ($class, $rows, $is_file) = @_;
	$is_file ||= sub { 1 };

	my %seen;
	return [
		grep {
			my $url = $_->{url};
			defined $url
				&& $url =~ m{^file://}i
				&& !$seen{join("\0", $url, $_->{artist_id} || '')}++
				&& $is_file->($url)
		} @{$rows || []}
	];
}

sub _similarity_weight {
	my $match = shift;
	return 1 unless defined $match && $match =~ /^\d+(?:\.\d+)?$/;

	$match += 0;
	return 0.1 if $match < 0.1;
	return $match;
}

1;

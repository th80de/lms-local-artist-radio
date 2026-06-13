package Plugins::LocalArtistRadio::ProtocolHandler;

use strict;
use warnings;

use URI;
use URI::QueryParam;

sub overridePlayback {
	my ($class, $client, $url) = @_;
	return unless $client && $url;

	my $uri = URI->new($url);
	my $artist_id = $uri->query_param('artist_id');
	return unless defined $artist_id && $artist_id =~ /^\d+$/;

	$client->execute([
		'localartistradio',
		'play',
		"artist_id:$artist_id",
	]);

	return 1;
}

sub canDirectStream { 0 }
sub contentType { 'lar' }
sub isRemote { 0 }

sub getMetadataFor {
	my ($class, $client) = @_;
	return {
		title => $client ? $client->string('PLUGIN_LOCALARTISTRADIO_NAME') : 'Local Artist Radio',
	};
}

1;

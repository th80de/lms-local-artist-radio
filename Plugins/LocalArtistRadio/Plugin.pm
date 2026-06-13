package Plugins::LocalArtistRadio::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::Base);

use File::Path qw(make_path);
use File::Spec;
use Scalar::Util qw(blessed);
use URI::Escape qw(uri_escape_utf8);

use Slim::Control::Request;
use Slim::Menu::ArtistInfo;
use Slim::Player::Client;
use Slim::Player::ProtocolHandlers;
use Slim::Utils::Log;
use Slim::Utils::PluginManager;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(cstring);

use Plugins::LocalArtistRadio::Mixer;

use constant PROVIDER_TOKEN => 'PLUGIN_RANDOM_LOCALARTISTRADIO_PROVIDER';
use constant STATE_KEY => 'localArtistRadioState';
use constant INITIAL_TRACKS => 10;
use constant REFILL_TRACKS => 5;
use constant MATERIAL_UI_VERSION => '0.2.0';

my $log = Slim::Utils::Log->addLogCategory({
	'category' => 'plugin.localartistradio',
	'defaultLevel' => 'WARN',
	'description' => 'PLUGIN_LOCALARTISTRADIO_NAME',
});

my $dstm_prefs = preferences('plugin.dontstopthemusic');
my $ready = 0;
my $subscribed = 0;

my $stop_commands = [
	'clear',
	'loadtracks',
	'playtracks',
	'load',
	'play',
	'loadalbum',
	'playalbum',
];

sub initPlugin {
	my $class = shift;
	$class->SUPER::initPlugin();

	Slim::Control::Request::addDispatch(
		['localartistradio', 'play'],
		[1, 0, 1, \&_cli_play],
	);
	Slim::Control::Request::addDispatch(
		['localartistradio', 'stop'],
		[1, 0, 0, \&_cli_stop],
	);

	require Plugins::LocalArtistRadio::ProtocolHandler;
	Slim::Player::ProtocolHandlers->registerHandler(
		localartistradio => 'Plugins::LocalArtistRadio::ProtocolHandler',
	);
}

sub postinitPlugin {
	my $class = shift;

	my $have_lastmix = Slim::Utils::PluginManager->isEnabled('Plugins::LastMix::Plugin');
	my $have_dstm = Slim::Utils::PluginManager->isEnabled('Slim::Plugin::DontStopTheMusic::Plugin');

	if (!$have_lastmix || !$have_dstm) {
		$log->error('LocalArtistRadio requires enabled LastMix and DontStopTheMusic plugins');
		return;
	}

	my $loaded = eval {
		require Plugins::LastMix::LFM;
		require Slim::Plugin::DontStopTheMusic::Plugin;
		1;
	};

	if (!$loaded) {
		$log->error("Could not load required plugin modules: $@");
		return;
	}

	Slim::Plugin::DontStopTheMusic::Plugin->registerHandler(
		PROVIDER_TOKEN,
		\&_refill,
	);

	Slim::Menu::ArtistInfo->registerInfoProvider(
		localArtistRadio => (
			after => 'top',
			func => \&_artist_info_item,
		),
	);

	Slim::Control::Request::subscribe(
		\&_playlist_command,
		[['playlist'], $stop_commands],
	);

	for my $client (Slim::Player::Client::clients()) {
		my $master = $client->master;
		my $provider = $dstm_prefs->client($master)->get('provider') || '';
		if ($provider eq PROVIDER_TOKEN && !$master->pluginData(STATE_KEY)) {
			$dstm_prefs->client($master)->set('provider', '');
		}
	}

	$subscribed = 1;
	$ready = 1;

	if (Slim::Utils::PluginManager->isEnabled('Plugins::MaterialSkin::Plugin')) {
		_install_material_button_loader();
	}
}

sub shutdownPlugin {
	for my $client (Slim::Player::Client::clients()) {
		_deactivate($client);
	}

	if ($subscribed) {
		Slim::Control::Request::unsubscribe(\&_playlist_command);
		$subscribed = 0;
	}

	if (Slim::Plugin::DontStopTheMusic::Plugin->can('unregisterHandler')) {
		Slim::Plugin::DontStopTheMusic::Plugin->unregisterHandler(PROVIDER_TOKEN);
	}

	Slim::Menu::ArtistInfo->deregisterInfoProvider('localArtistRadio');
	Slim::Player::ProtocolHandlers->registerHandler('localartistradio', 0);
	$ready = 0;
}

sub getDisplayName {
	return 'PLUGIN_LOCALARTISTRADIO_NAME';
}

sub _install_material_button_loader {
	my $prefs_dir = Slim::Utils::Prefs::dir();
	return unless $prefs_dir;

	my $material_dir = File::Spec->catdir($prefs_dir, 'material-skin');
	my $custom_js = File::Spec->catfile($material_dir, 'custom.js');
	my $temporary = "$custom_js.$$";
	my $begin = '/* BEGIN LocalArtistRadio */';
	my $end = '/* END LocalArtistRadio */';
	my $version = MATERIAL_UI_VERSION;
	my $block = <<"JS";
$begin
(function () {
	'use strict';
	if (document.querySelector('script[data-local-artist-radio]')) {
		return;
	}
	var script = document.createElement('script');
	script.setAttribute('data-local-artist-radio', '1');
	script.src = '/plugins/LocalArtistRadio/html/material-button.js?v=$version';
	document.head.appendChild(script);
}());
$end
JS

	my $existing = '';
	if (-f $custom_js) {
		my $input;
		if (!open $input, '<', $custom_js) {
			$log->error("Could not read Material Skin custom.js: $!");
			return;
		}
		$existing = do { local $/; <$input> };
		close $input;
	}

	if ($existing =~ /\Q$begin\E.*?\Q$end\E/s) {
		$existing =~ s/\Q$begin\E.*?\Q$end\E/$block/s;
	} else {
		$existing .= "\n" if length($existing) && $existing !~ /\n\z/;
		$existing .= $block;
	}

	eval {
		make_path($material_dir) unless -d $material_dir;
		open my $output, '>', $temporary
			or die "Could not write $temporary: $!";
		print {$output} $existing
			or die "Could not write $temporary: $!";
		close $output
			or die "Could not close $temporary: $!";
		rename $temporary, $custom_js
			or die "Could not replace $custom_js: $!";
		1;
	} or do {
		unlink $temporary if -f $temporary;
		$log->error("Could not install Material Skin button loader: $@");
	};
}

sub _artist_info_item {
	my ($client, $url, $artist) = @_;
	return unless $ready && blessed($client) && blessed($artist);

	return [{
		name => cstring($client, 'PLUGIN_LOCALARTISTRADIO_ACTION'),
		url => 'localartistradio://play?artist_id=' . uri_escape_utf8($artist->id),
		type => 'audio',
	}];
}

sub _cli_play {
	my $request = shift;
	my $client = $request->client;

	if (!$ready) {
		$request->setStatusBadConfig();
		return;
	}

	my $artist_id = $request->getParam('artist_id');
	if (!$client || !defined $artist_id || $artist_id !~ /^\d+$/) {
		$request->setStatusBadParams();
		return;
	}

	$client = $client->master;
	my $old_state = $client->pluginData(STATE_KEY);
	my $current_provider = $dstm_prefs->client($client)->get('provider') || '';
	my $previous_provider = $current_provider;

	if ($current_provider eq PROVIDER_TOKEN) {
		$previous_provider = $old_state
			? ($old_state->{previous_provider} || '')
			: '';
	}

	my $state = {
		active => 1,
		seed_artist_id => $artist_id,
		force_seed_first => 1,
		previous_provider => $previous_provider,
		recent_artists => [],
		used_urls => {},
	};
	$client->pluginData(STATE_KEY => $state);
	$request->setStatusProcessing();

	Plugins::LocalArtistRadio::Mixer->build_batch(
		state => $state,
		count => INITIAL_TRACKS,
		callback => sub {
			my ($tracks, $updated_state, $error) = @_;

			if (!$tracks || !@$tracks) {
				$log->error("Could not start local artist radio: " . ($error || 'unknown error'));
				_deactivate($client);
				$request->setStatusBadParams();
				return;
			}

			$client->pluginData(STATE_KEY => $updated_state);
			$dstm_prefs->client($client)->set('provider', PROVIDER_TOKEN);

			my $load = $client->execute([
				'playlist',
				'loadtracks',
				'listRef',
				$tracks,
			]);
			$load->source(__PACKAGE__);

			$request->addResult('count', scalar @$tracks);
			$request->setStatusDone();
		},
	);
}

sub _cli_stop {
	my $request = shift;
	my $client = $request->client;

	if (!$client) {
		$request->setStatusNeedsClient();
		return;
	}

	_deactivate($client->master);
	$request->setStatusDone();
}

sub _refill {
	my ($client, $callback) = @_;
	$client = $client->master;

	my $state = $client->pluginData(STATE_KEY);
	if (!$state || !$state->{active}) {
		$callback->($client, []);
		return;
	}

	Plugins::LocalArtistRadio::Mixer->build_batch(
		state => $state,
		count => REFILL_TRACKS,
		callback => sub {
			my ($tracks, $updated_state, $error) = @_;
			$client->pluginData(STATE_KEY => $updated_state);
			$log->warn("Could not refill local artist radio: $error") if $error;
			$callback->($client, $tracks || []);
		},
	);
}

sub _playlist_command {
	my $request = shift;
	my $client = $request->client;
	return unless $client;

	my $source = $request->source || '';
	return if $source eq __PACKAGE__;
	return unless $request->isCommand([['playlist'], $stop_commands]);

	_deactivate($client->master);
}

sub _deactivate {
	my $client = shift;
	return unless $client;

	$client = $client->master;
	my $state = $client->pluginData(STATE_KEY);
	return unless $state;

	my $current_provider = $dstm_prefs->client($client)->get('provider') || '';
	if ($current_provider eq PROVIDER_TOKEN) {
		$dstm_prefs->client($client)->set(
			'provider',
			$state->{previous_provider} || '',
		);
	}

	$client->pluginData(STATE_KEY => undef);
}

1;

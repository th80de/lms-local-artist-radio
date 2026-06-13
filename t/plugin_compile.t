use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

BEGIN {
	package Slim::Plugin::Base;
	sub import {}
	$INC{'Slim/Plugin/Base.pm'} = 1;

	package Slim::Control::Request;
	sub import {}
	$INC{'Slim/Control/Request.pm'} = 1;

	package Slim::Menu::ArtistInfo;
	sub import {}
	$INC{'Slim/Menu/ArtistInfo.pm'} = 1;

	package Slim::Player::Client;
	sub import {}
	$INC{'Slim/Player/Client.pm'} = 1;

	package Slim::Player::ProtocolHandlers;
	sub import {}
	$INC{'Slim/Player/ProtocolHandlers.pm'} = 1;

	package LocalArtistRadioTestLog;
	sub error {}
	sub warn {}

	package Slim::Utils::Log;
	sub import {}
	sub addLogCategory { bless {}, 'LocalArtistRadioTestLog' }
	$INC{'Slim/Utils/Log.pm'} = 1;

	package Slim::Utils::PluginManager;
	sub import {}
	$INC{'Slim/Utils/PluginManager.pm'} = 1;

	package LocalArtistRadioTestPrefs;
	sub client { $_[0] }
	sub get { '' }
	sub set {}

	package Slim::Utils::Prefs;
	sub import {
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::preferences"} = sub { bless {}, 'LocalArtistRadioTestPrefs' };
	}
	$INC{'Slim/Utils/Prefs.pm'} = 1;

	package Slim::Utils::Strings;
	sub import {
		my ($class, @symbols) = @_;
		my $caller = caller;
		no strict 'refs';
		for my $symbol (@symbols) {
			*{"${caller}::$symbol"} = sub { $_[-1] };
		}
	}
	$INC{'Slim/Utils/Strings.pm'} = 1;

	package Plugins::LocalArtistRadio::Mixer;
	sub import {}
	$INC{'Plugins/LocalArtistRadio/Mixer.pm'} = 1;
}

use lib '.';

my $loaded = eval {
	require Plugins::LocalArtistRadio::Plugin;
	1;
};

ok($loaded, 'Plugin.pm compiles with LMS interfaces available') or diag $@;

SKIP: {
	skip 'Plugin.pm did not compile', 4 unless $loaded;

	my $prefs_dir = tempdir(CLEANUP => 1);
	my $material_dir = File::Spec->catdir($prefs_dir, 'material-skin');
	my $custom_js = File::Spec->catfile($material_dir, 'custom.js');
	make_path($material_dir);

	open my $output, '>', $custom_js or die $!;
	print {$output} "window.existingMaterialCustomisation = true;\n";
	close $output;

	{
		no warnings qw(redefine once);
		local *Slim::Utils::Prefs::dir = sub { $prefs_dir };
		Plugins::LocalArtistRadio::Plugin::_install_material_button_loader();
		Plugins::LocalArtistRadio::Plugin::_install_material_button_loader();
	}

	open my $input, '<', $custom_js or die $!;
	my $custom_source = do { local $/; <$input> };
	close $input;

	like(
		$custom_source,
		qr{window\.existingMaterialCustomisation = true},
		'Material loader preserves existing custom JavaScript',
	);
	is(
		scalar(() = $custom_source =~ m{/\* BEGIN LocalArtistRadio \*/}g),
		1,
		'Material loader start marker is idempotent',
	);
	is(
		scalar(() = $custom_source =~ m{/\* END LocalArtistRadio \*/}g),
		1,
		'Material loader end marker is idempotent',
	);
	like(
		$custom_source,
		qr{material-button\.js\?v=0\.2\.0},
		'Material loader contains the current UI version',
	);
}

done_testing;

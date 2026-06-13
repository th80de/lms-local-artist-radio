(function () {
	'use strict';

	var BUTTON_ID = 'local-artist-radio-button';
	var pending = false;

	function browseView() {
		var root = document.getElementById('browse-view');
		return root && root.__vue__ ? root.__vue__ : null;
	}

	function currentArtist(view) {
		var current = typeof browseGetCurrent === 'function'
			? browseGetCurrent(view)
			: view.current;

		if (!current || typeof current.id !== 'string' ||
			current.id.indexOf('artist_id:') !== 0) {
			return null;
		}

		return current.id.substring('artist_id:'.length);
	}

	function label() {
		var language = window.lmsOptions && lmsOptions.lang
			? String(lmsOptions.lang).toLowerCase()
			: '';
		return language.indexOf('de') === 0
			? 'Lokales Interpreten-Radio'
			: 'Local Artist Radio';
	}

	function removeButton() {
		var button = document.getElementById(BUTTON_ID);
		if (button) {
			button.remove();
		}
	}

	function startRadio(event) {
		event.preventDefault();
		event.stopPropagation();

		var view = browseView();
		var artistId = view ? currentArtist(view) : null;
		var playerId = view && typeof view.playerId === 'function'
			? view.playerId()
			: '';

		if (!artistId || !playerId || typeof lmsCommand !== 'function') {
			return;
		}

		lmsCommand(playerId, [
			'localartistradio',
			'play',
			'artist_id:' + artistId
		]).catch(function (error) {
			console.error('Could not start Local Artist Radio', error);
		});
	}

	function createButton(anchor) {
		var button = anchor.cloneNode(true);
		var content = button.querySelector('.v-btn__content') || button;
		var icon = content.querySelector('img.svg-img');

		button.id = BUTTON_ID;
		button.title = label();

		while (content.firstChild) {
			content.removeChild(content.firstChild);
		}
		if (icon) {
			content.appendChild(icon.cloneNode(true));
		}
		content.appendChild(document.createTextNode('\u00a0' + label()));
		button.addEventListener('click', startRadio);

		return button;
	}

	function updateButton() {
		pending = false;

		var view = browseView();
		if (!view || !currentArtist(view)) {
			removeButton();
			return;
		}

		var table = document.querySelector('#browse-view table.browse-commands');
		var mixIcon = table
			? table.querySelector('button.context-button img[src*="music-mix"]')
			: null;
		var anchor = mixIcon ? mixIcon.closest('button.context-button') : null;
		if (!anchor) {
			removeButton();
			return;
		}

		var existing = document.getElementById(BUTTON_ID);
		if (existing) {
			return;
		}

		anchor.parentNode.insertBefore(createButton(anchor), anchor.nextSibling);
	}

	function scheduleUpdate() {
		if (pending) {
			return;
		}
		pending = true;
		window.requestAnimationFrame(updateButton);
	}

	function initialise() {
		var app = document.getElementById('app');
		if (!app) {
			return;
		}

		new MutationObserver(scheduleUpdate).observe(app, {
			childList: true,
			subtree: true
		});
		scheduleUpdate();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', initialise);
	} else {
		initialise();
	}
}());

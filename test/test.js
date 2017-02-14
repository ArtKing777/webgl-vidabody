function waitFor (f, t) {
	var condition = false;
	while (!condition) {
		slimer.wait (t || 1000);
		condition = page.evaluate (f);
	}
}

function getCenter (selector) {
	return page.evaluate (function (selector) {
		var rect = document.querySelector(selector).getBoundingClientRect();
		return {
			x: 0.5 * (rect.left + rect.right), y: 0.5 * (rect.top + rect.bottom)
		};
	}, selector);
}

function click (selector) {
	var p = getCenter(selector);
	page.sendEvent('click', p.x, p.y, 'left');
}

function test (action, result, message) {
	if (action) action (); waitFor (result); if (message) console.log ('\x1b[1m\x1B[32mOK\x1B[0m\x1b[1m: ' + message + '\x1b[22m');
}

function compareScreenshots (screens) {
	var base = 'file://' + phantom.libraryPath;
	var html = '';
	for (var i = 0; i < screens; i++) {
		html += '<div>'
		html += '<div style="width:384px;height:216px;display:inline-block;background:url(' + base + '/expected/' + i + '.png);background-size:contain;"></div>';
		html += '<div style="width:384px;height:216px;display:inline-block;background:url(' + base + '/expected/' + i + '.png),url(' + base + '/results/' + i + '.png);background-size:contain;background-blend-mode:difference;"></div>';
		html += '<div style="width:384px;height:216px;display:inline-block;background:url(' + base + '/results/' + i + '.png);background-size:contain;"></div>';
		html += '</div>';
	}
	page.setContent(html, base);
	console.log ('\x1b[1m\x1B[32mOK\x1B[0m\x1b[1m: displayed ' + screens + ' screenshot pairs\x1b[22m');
}

var page = require('webpage').create();
page.onConsoleMessage = function(message, line, file) {
	var prefix = file.substr(file.lastIndexOf('/') + 1) + ':' + line + ' ';
	while (prefix.length < 20) prefix += ' ';
	console.log(prefix + message);
};
page.viewportSize = { width: 1280, height: 720 };
page.open('http://127.0.0.1:8087/#options={"server":"http://beta.vidabody.com/server/","assetver":"dev","failureProbability":"0"}')
	.then(function(status){

		var handled = false;
		var screens = 0;

		if (status == 'success') {
			page.onLoadFinished = function(status) {

				// for some reason (redirect ?) this is somethimes (wtf ?) called twice
				if (handled) return; else handled = true;

				var screenshotsFolder = 'results/';
				if (phantom.args.indexOf ('expected') > -1) {
					screenshotsFolder = 'expected/';
				}

				console.log ('Writing screenshots to ./' + screenshotsFolder);

				// wait for app to show
				test (null, function () {
					var canvas = document.getElementById('canvas');
					return canvas && (canvas.style.visibility == 'visible');
				}, 'The app has started...');

				/*
				// wait for landing tour
				test (null, function () {
					return VidaBody.tour_viewer && VidaBody.tour_viewer.is_viewing() && VidaBody.tour_viewer.is_landing;
				}, 'The landing tour has started...');

				// exit landing tour
				test (function () {
					page.sendEvent('keydown', page.event.key.Escape);
				}, function () {
					return !VidaBody.tour_viewer.is_viewing();
				}, 'The landing tour was stopped...');
				*/

				// expand login form
				test (function () {
					click('#secondary_login_button');
				}, function () {
					return document.querySelector('#login_panel').classList.contains('expanded');
				}, 'Login panel expanded...');

page.render (screenshotsFolder + screens++ + '.png');

				// log in TODO should we send keyboard events?
				test (function () {
					page.evaluate (function () {
						document.querySelector('#login_form #email').value = 'makc.the.great@gmail.com';
						document.querySelector('#login_form #password').value = 'Drowssap1';
					});
					click('#login_form input[type="submit"]');
				}, function () {
					return (document.querySelector('#user_name').innerHTML == 'makc');
				}, 'Logged in...');

page.render (screenshotsFolder + screens++ + '.png');

				// enter tour tree
				test (function () {
					click('#tours > div.expand-accordion.panel-button');
				}, function () {
					return document.querySelector('#main_menu ul').classList.contains('expanded');
				}, 'The tour tree was displayed...');

				/*
				// create new tour
				test (function () {
					click('#new_tour');
				}, function () {
					return document.querySelectorAll('li div[contenteditable="true"]').length == 1;
				});

				test (function () {
					page.evaluate (function () {
						document.querySelector('li div[contenteditable="true"]').innerHTML = 'Test #' + Date.now();
						document.querySelector('li div[contenteditable="true"]').focus();
						// I can't figure working way to press enter, so I am sending fake event to label (div's parentNode)
						var e = new Event ('keydown'); e.keyCode = 13;
						document.querySelector('li div[contenteditable="true"]').parentNode.dispatchEvent (e);
					});
				}, function () {
					return tour_editor.is_editing();
				}, 'Created new tour...');
				*/

				// locate heart tour and enter it
				test (function () {
					// find the tour in the tree
					page.evaluate (function () {
						var hash = '16ae2c3acf546e808c83f5f8217c756ae296251f';
						var nodes = document.querySelectorAll('#tour-tree-container > ul > li > ul > li');
						for (var i = 0; i < nodes.length; i++) {
							var li = nodes[i];
							if (li.tour_data.hash == hash) {
								// tour's li can be inside collapsed folder (not clickable)
								// so we will just start the viewer here
								var label = li.querySelector ('label');
								VidaBody.tour_viewer.start(li.tour_data, label.textContent, 0);
								break;
							}
						}
					});
				}, function () {
					return VidaBody.tour_viewer.is_viewing();
				}, 'Entered heart tour...');

				// navigate to specific slide
				test (function () {
					page.evaluate (function () {
						setTimeout (function () {
							VidaBody.tour_viewer.go_to_slide(null, 21 - 1, true);
							console.log('Ya, ' + (VidaBody.tour_viewer.current_slide + 1) + '-th...');
						}, 3000);
					});
					/* alternatively, click 'next' gazilion times
					for (var i = 0; i < 21 - 1; i++) {
						slimer.wait (2000);
						click ('#next');
					}
					*/
				}, function () {
					// TODO wait for transition to compplete - how?
					return (VidaBody.tour_viewer.current_slide == 21 - 1);
				}, 'Displaying 21-th slide...');

slimer.wait (3000);
page.render (screenshotsFolder + screens++ + '.png');
compareScreenshots (screens);

				//page.close();
				//slimer.exit()
			};
		}

	})
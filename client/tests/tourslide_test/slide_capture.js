/*
	HOW TO USE
	
	STEP 1. SETUP YOUR LOCAL SERVER
	STEP 2. DOWNLOAD TOURS TO THE SERVER FOLDER USING
		$ cd server
		$ coffee copy_tours.coffee <list of tour hashes>
	STEP 3. ENTER THOSE TOUR HASHES INTO THE tourhash_list ARRAY.
	STEP 4. CREATE REFERENCE FROM KNOWN GOOD BRANCH
		$ slimerjs slide_capture.js
		$ mv image_results image_reference
	STEP 4. SWITCH TO BRANCH/COMMIT TO TEST
	STEP 5. RUN TEST, COMPARE WITH REFERENCE.
		$ python autotest.py
	ALL TOURS WILL BE LOADED AND ALL SLIDES CAPTURED TO "./image_results/"

		
	**** BELOW TEXT OUTDATED, ONLY RELEVANT IF do_login IS TRUE AND do_load_first_tour IS TRUE ****
	
	STEP 1. CREATE USER WITH THE FOLLOWING EMAIL AND PASSWORD ON THE LOCAL SERVER
			EMAIL autoqa@autoqa.com
			PASSWORD autoqaautoqaautoqaautoqaautoqa
			
	STEP 2. CREATE OR LOAD TOURS INTO THIS ACCOUNT.
	STEP 3. RUN THIS
		$ slimerjs slide_capture.js
		
	IT SHOULD AUTOMATICALLY LOAD THE FIRST TOUR AND CAPTURE ALL THE SLIDES TO "image_results"
*/

"use strict"
var webpage = require('webpage').create();
console.log("Automatic Slide Capture\n");

// Set vieport size
webpage.viewportSize = { width:1280, height:720 };
webpage.evaluate(function () {
    window.focus();
});
// Event Logging
var msgCount = 0;
function reportEvent(message, type){
	if (type==undefined){
		var type = "status";
	}
	console.log("["+type+"]"+" "+message);
	msgCount += 1;
}

// CONFIGURATION
var test_email = "autoqa@autoqa.com"
var test_password = "autoqaautoqaautoqaautoqaautoqa"
var do_login = false; // Do we login?
var do_load_first_tour = false; // Do we manually load the first tour in the above account?
												// IF FALSE, We will directly load all the tours in the tourhash list.
			
// Captures only 10 slides from each tour, for quick testing.
var quick_run = false;
var single_run = false; // Capture only a single tour?
var tour_number = 0; // Which tour from the list to capture

if(phantom.args[0]==undefined){
	reportEvent("Running through all tours", "WARNING")
}else{
	single_run = true;
	tour_number = phantom.args[0];
	reportEvent("SINGLE RUN MODE, Running through tour number "+tour_number, "WARNING");
}

var tourhash_list = [
	'659494d0f55e76d89a8a90017fa80d13c0fbfec0',
    '1c8ee40fefc65250c17ea106013def781dff90e0',
	'089544b528c237c7c637852d5bc3c096857199a0',
	'3a30cea24a3e4b574c98036e695a4113ba8389a9',
	'3fa9edd2dfa4e000ca5c4cfc4d4bdb8ae754b303',
	'ee59c2d8181b17d2333b87b3659f612c3dede5f9',
	'151cc25874dd40ca749cf74f3e23e9c16254e3a8'
]

webpage
  .open('http://127.0.0.1:8087/#options={"server":"http://127.0.0.1:7654/","assetver":"dev","failureProbability":"0"}') // loads a page
  .then(function(){ // executed after loading
		reportEvent("Application summoned...")

		reportEvent("Waiting for startup...")
		
		webpage.evaluate(function(){
			performance._now = performance.now
			window.fake_timer_start = performance._now()
			performance.now = function(){return (this._now()-window.fake_timer_start)*1000}
			Object.defineProperty(vb.heart,'enabled_animation',{set:function(){},get:function(){}})
			
			var d=document;var s=d.createElement('style');s.textContent='*{transition: none !important;}';d.body.appendChild(s)
			window.addEventListener('mousemove', function(e){
				document.getElementById('fps').textContent = [e.pageX, e.pageY]
			}, true)
		})
		
		// Enter the WAIT FOR STARTUP loop
		// (We can just do this without mouse clicks, but Ill leave it be mouse clicks to make sure these things are not bugged in the UI either)
		while(1){
			webpage.sendEvent("click", 120, 114, 'left', 0); // Attempt to open the tours
			slimer.wait (500);
			// Check if the tour menu is open.
			var response = webpage.evaluate(function(){
				return document.getElementById('tours').classList;
			})
			if(response=="expanded"){
				webpage.sendEvent("click", 120, 114, 'left', 0); // Now we close the tours
			    slimer.wait (500);
				break;
			}
		}
		
		reportEvent("Application started!");
		
		if(do_login){
			reportEvent("Logging in..");
		
			// We are started. Now, we shall login.
			webpage.sendEvent("click", 1050, 60, 'left', 0); // LOGIN MENU
			slimer.wait (3000); // Wait for the extra-slow animation ugh
			
			webpage.sendEvent("click", 630, 270, 'left', 0); // EMAIL
			webpage.sendEvent("keypress", test_email);
			slimer.wait (300);
			
			webpage.sendEvent("click", 630, 340, 'left', 0); // PASSWORD
			webpage.sendEvent("keypress", test_password);
			
			
			webpage.sendEvent("click", 630, 400, 'left', 0); // LOGIN BUTTON
			slimer.wait (2000); // Wait for extra slow login animation ugh
			
			// ASSUMING ACCOUNT IS CORRECT, WE CONTINUE TO OPEN THE TOURS
		}else{
			reportEvent("Login not required, skipping step", "REMINDER")
		}
		
		var current_tour = tour_number;
		var total_tours = tourhash_list.length;
		
		while(true){
				console.log("\n----------------\n");
				if(current_tour==(total_tours)){
					break;
				}
				
				reportEvent("Capturing Tour # "+(current_tour+1)+" of "+total_tours)
				if(do_load_first_tour){
					// Enter the OPEN TOUR MENU loop
				while(1){
					webpage.sendEvent("click", 120, 114, 'left', 0); // Attempt to open the tours
					slimer.wait (1000);
					// Check if the tour menu is open.
					var response = webpage.evaluate(function(){
						return document.getElementById('tours').classList;
					})
					if(response=="expanded"){
						reportEvent("Tour menu opened.");
						slimer.wait (1000);
						break;
					}
				}
			}else{
				reportEvent("Opening tour hash "+tourhash_list[current_tour])
				
				// Simply opens a tour with given hash, It better be in the server!!
				webpage.evaluate(function(tour_hash){
						location.hash='tour=@'+tour_hash;
					}, tourhash_list[current_tour])
			}
			
			
			reportEvent("Waiting for tour to load...")
			
			// Enter the WAIT FOR TOUR TO LOAD loop
			while(1){
				slimer.wait (500);
				var response = webpage.evaluate(function(){
					return vb.tour_viewer.viewing;
				})
				if(response==true){
					slimer.wait(1000);
					break;
				}
			}
			
			// Fetch the tour name
			var tour_name = webpage.evaluate(function(){
					return vb.tour_viewer.tour_name ;
				})
			var tour_file_name = tour_name.replace(/\W/g, '').toUpperCase();
			//replace(/\s+/, "")
			reportEvent("Tour loaded!");
			reportEvent("Tour Name: "+tour_name, "INFO");
			reportEvent("Entering CAPTURE ALL SLIDES loop");
			
			var active_slide = 0;
			if(quick_run){
				var total_slides = 10;
				webpage.evaluate(function(){
							vb.tour_viewer.audio_player.volume = 0
					})
			}else{
				var total_slides = webpage.evaluate(function(){
							vb.tour_viewer.audio_player.volume = 0
							return vb.tour_viewer.slides.length;
					})
			}
			
			
			while(1){
				slimer.wait (500);
				//STOP HEART ANIMATION
				webpage.evaluate(function(){
						vb.heart.enabled_animation = false;
				})
				

				var slide_active = webpage.evaluate(function(){
						return vb.tour_viewer.loading_slide;
				})
				
				// Slide finished, take screenshot and progress to the next one!
				if(slide_active==false){
					// Slide is loaded, wait a second for animation
					slimer.wait (1000);
					
					active_slide++;
					
					reportEvent("Slide "+active_slide+" captured of "+total_slides);
					webpage.render('./image_results/'+tour_file_name+'_slide_'+active_slide+'.png', {onlyViewport:true});
					
					// Check if we are on our last slide, if so break from the loop.
					if (active_slide>=total_slides){
						break;
					}
					// Go to the next slide
					webpage.evaluate(function(){
						vb.tour_viewer.next();
					})
				}else{
					reportEvent("Slide still loading...", "WARNING");
				}
			}

			// Now, we exit the tour.
			webpage.evaluate(function(){
						vb.tour_viewer.stop();
						window.fake_timer_start = performance._now();
					})
			if(single_run){
				reportEvent("Finished with single tour! Exiting!");
				break;
			}else{
				reportEvent("Finished all slides! Going to next tour...");
				slimer.wait(1500);
				
				current_tour++;
			}
		}
		
		console.log("\nFinished capturing all tours! See results in the image_results folder.");
		slimer.exit();
  })

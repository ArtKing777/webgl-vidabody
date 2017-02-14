/*

	HOW TO USE
		Create reference screenshots:
		    slimerjs tour_editor_test.js genref
		Run tests, compare with reference:
			python autotest.py
		
	GENERAL TODO:
		Modularized testing code - DONE  (POORLY DONE TEMPORARIALLY, WILL BE DONE PROPERLY LATER)
		Modularized test results - HALF
		Generate Reference Mode - DONE BUT NOT REQUIRED
		Per-Test validation by using image comparison method of the autotest.py with reference images - DONE, TASK MOVED TO AUTOTEST.PY DUE TO LACK OF SHELL COMMANDS IN SLIMERJS
		Make more tour editor tests!
		Optionally undo events done by tests to have them be isolated. - DONE
		
	TOUR EDITOR TESTS:
		Shape Annotation test - done
		Text annotation test - done
		ALL OTHER ANNOTATIONS - DONE
		MANIPULATING SLIDES

*/

"use strict"

var fs = require('fs');
var webpage = require('webpage').create();

// Setup the browser
webpage.viewportSize = { width:1280, height:720 };
webpage.evaluate(function () {
    window.focus();
});

// Set-up Event Logging
var msgCount = 0;
function reportEvent(message, type){
	if (type==undefined){
		var type = "EVENT";
	}
	console.log("["+msgCount+"]["+type+"]"+" "+message);
	msgCount += 1;
}

// Keeps track of test results.
var test_results = [];

// ======== CONFIGURATION BEGIN HERE ========
var test_email = "autoqa@autoqa.com"
var test_password = "autoqaautoqaautoqaautoqaautoqa"
var do_login = true; // Do we login?
var reference_mode = false; // Do we generate reference? (Can still be overwritten to true if in GENREF mode)
var referende_dir = "image_reference";
var output_dir = "image_results";
var do_freeze = false; // Do we just open the browser and then do nothing? (No running tests, stays open forever until closed manually)
var do_clean_on_test = true; // Do we undo the actions of a test for the next test?
// ======== CONFIGURATION END HERE ========

console.log("Tour Editor Test\n");

// Check do we run in generate reference mode?
if(phantom.args[0]=="genref"){
	reportEvent("GENERATE REFERENCE MODE", "WARNING");
	reference_mode = true;
	// If reference mode is true, our output folder is now the reference folder!
	output_dir = referende_dir;
}

if(do_freeze==true){
	reportEvent("DO_FREEZE MODE ENABLED", "WARNING");

}


webpage
  .open('http://127.0.0.1:8087/#options={"server":"http://127.0.0.1:7654/","assetver":"dev","failureProbability":"0"}') // loads a page
  .then(function(){ // executed after loading
		reportEvent("Application summoned...", "PROGRAM BEGIN")
		reportEvent("Output Folder: "+output_dir, "INFO");
		reportEvent("Reference Folder: "+referende_dir, "INFO");
		reportEvent("Waiting for startup...")
		
		webpage.evaluate(function(){
			performance._now = performance.now
			window.fake_timer_start = performance._now()
			performance.now = function(){return (this._now()-window.fake_timer_start)*1000}
			
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
		
		// Capture login result
		webpage.render('./'+output_dir+'/account_login.png', {onlyViewport:true});
		
		// Fetch our login token
		var login_token = webpage.evaluate(function(){
			return vb.auth.token;
		})
		// Use the login token (or lack therof) to determine if login was a success
		if(login_token == ""){
			console.log("\n");
			reportEvent("Could not login, Check username and password. Early termination.", "FATAL");
			test_results.push(["Account Login", false]);
			slimer.exit();
		}else{
			reportEvent("Successfully logged in!", "SUCCESS");
			test_results.push(["Account Login", true]);
			/*
				these are false/fail conditions
				vb.tour_editor.undo_stack.length = 0
				vb.tour_editor.viewing = undefined
				
				test_result["Creating Text Annotation"] = true
			*/
			if(do_freeze){
				reportEvent("ENTERING FREEZE, USER CAN NOW INTERACT.", "INFO")
				while(1){
					slimer.wait(500);
				}
			}
			// Open the tour editor now.
			reportEvent("Creating new tour..");
			webpage.sendEvent("click", 120, 101, 'left', 0); // TOURS BUTTON
			slimer.wait (500);
			webpage.sendEvent("click", 170, 145, 'left', 0); // NEW TOUR
			slimer.wait (500);
			webpage.sendEvent('keypress', "Test Tour");
			webpage.sendEvent("click", 35, 35, 'left', 0); // This deselects the tour name text box, opening the tour editor now
			slimer.wait (1000);
			
			// Is the tour editor open?
			var tour_editing = webpage.evaluate(function(){
				return vb.tour_editor.editing;
			})
			if(tour_editing==undefined){
				reportEvent("Unable to open tour editor; Please investigate.","FATAL")
			}else{
				reportEvent("New tour created/opened!", "SUCCESS");
				
				// Begin running tests.
				var list = fs.list("./tour_tests");
				// Cycle through all test scripts
				for(var x = 0; x < list.length; x++){
					reportEvent("Running script "+list[x]);
					phantom.injectJs("./tour_tests/" + list[x]);
					// Undo the actions!
					if(do_clean_on_test){
						var undo_stack_length = webpage.evaluate(function(){
							return vb.tour_editor.undo_stack.length;
						})
						reportEvent("Undoing all "+undo_stack_length+" events...", "INFO")
						webpage.evaluate(function(){
							for(var n = 0; n < vb.tour_editor.undo_stack.length; n++){
								vb.tour_editor.undo();
							}
						})
					}else{
						webpage.evaluate(function(){
							vb.tour_editor.undo_stack = [];
						})
					}
				}
			}
			
			if(reference_mode){
				reportEvent("Reference Generation Done in folder ./reference_images/");
			}else{
				// End of all tests.
				reportEvent("Done running all tests, see image_results for screenshots.", "PROGRAM END")
				console.log("========\nTest Report\n========");
				var passed_tests = 0;
				for(var x = 0;x<test_results.length;x++){
					if(test_results[x][1]==true){
						passed_tests++;
					}
				}
				console.log("Passed "+passed_tests+" tests out of "+test_results.length+" total tests.\n========")
				for(var x = 0;x<test_results.length;x++){
					console.log(test_results[x][0]+" - "+test_results[x][1])
				}
			}
			
			slimer.exit();
		}
  })

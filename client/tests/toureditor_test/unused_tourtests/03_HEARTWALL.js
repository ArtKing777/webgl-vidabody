/*

// Text annotation Creation
webpage.evaluate(function(){
				vb.set_meshes_state({Heart_wall: [0,0,0,0,1,0,0,1,0]})
				vb.go_here(['Heart_wall'])
			})
			
slimer.wait (1500);	
reportEvent("Heart Wall loaded: screenshot captured");
webpage.render('./'+output_dir+'/heart_wall_exterior.png', {onlyViewport:true}); 

// Now we zoom in. (hold W for 6 seconds)
webpage.sendEvent("keydown", "W"); 
slimer.wait(500);
webpage.sendEvent("keyup", "W"); 

reportEvent("Zoomed In: screenshot captured");
webpage.render('./'+output_dir+'/heart_wall_interior.png', {onlyViewport:true}); 

// Verify action
var undo_stack_length = webpage.evaluate(function(){
	return vb.tour_editor.undo_stack.length;
})
if(undo_stack_length!=0){
	test_results.push(["Heart Wall", true]);
}else{
	test_results.push(["Heart Wall", false]);
} 

*/
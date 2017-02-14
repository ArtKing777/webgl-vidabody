
// Shape annotation Creation
webpage.sendEvent("click", 750, 24, 'left', 0); 
slimer.wait (500);
webpage.sendEvent("click", 750, 79, 'left', 0); 
slimer.wait (500);
webpage.sendEvent("click", 500, 500, 'left', 0);
slimer.wait (500);
webpage.sendEvent("click", 35, 35, 'left', 0);
slimer.wait (500);
// Capture result
webpage.render('./'+output_dir+'/shape_annotation.png', {onlyViewport:true}); 


// Dragging the object to 400, 300
webpage.sendEvent("mousedown", 700, 435, 'left', 0);
slimer.wait (500);
webpage.sendEvent("mousemove", 400, 300, 'left', 0);
slimer.wait (500);
webpage.sendEvent("mouseup", 400, 300, 'left', 0);
slimer.wait (500);
// Capture result
webpage.render('./'+output_dir+'/shape_annotation_moved.png', {onlyViewport:true}); 

//  RESIZING
// 439, 324
webpage.sendEvent("mousedown", 439, 324, 'left', 0);
slimer.wait (500);
webpage.sendEvent("mousemove", 700, 435, 'left', 0);
slimer.wait (500);
webpage.sendEvent("mouseup", 700, 435, 'left', 0);
slimer.wait (500);

// Capture result
webpage.render('./'+output_dir+'/shape_annotation_resized.png', {onlyViewport:true}); 

// Verify action
var undo_stack_length = webpage.evaluate(function(){
	return vb.tour_editor.undo_stack.length;
})
if(undo_stack_length!=0){
	test_results.push(["Shape Annotation", true]);
}else{
	test_results.push(["Shape Annotation", false]);
} 

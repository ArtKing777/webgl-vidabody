/*
// Text annotation Creation
webpage.sendEvent("click", 691, 24, 'left', 0); // TEXT Annotation
slimer.wait (500);
webpage.sendEvent("click", 500, 500, 'left', 0);
slimer.wait (500);
webpage.sendEvent('keypress', "Test Text Annotation");
webpage.sendEvent("click", 35, 35, 'left', 0);
slimer.wait (500);
webpage.render('./'+output_dir+'/text_annotation.png', {onlyViewport:true}); 

// Verify action
var undo_stack_length = webpage.evaluate(function(){
	return vb.tour_editor.undo_stack.length;
})
if(undo_stack_length!=0){
	test_results.push(["Text Annotation", true]);
}else{
	test_results.push(["Text Annotation", false]);
} 
*/
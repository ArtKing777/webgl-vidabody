/*
// Open UPLOAD IMAGE form
webpage.sendEvent("click", 586, 24, 'left', 0);
slimer.wait (500);
// Fill in the form
page.uploadFile('.popup_menu .file-input input', 'test_image.jpg')

// Capture Result
webpage.render('./'+output_dir+'image_upload.png', {onlyViewport:true}); 

reportEvent("ENTERING FREEZE", "INFO")
while(1){
	slimer.wait(500);
}

// Verify action
var undo_stack_length = webpage.evaluate(function(){
	return vb.tour_editor.undo_stack.length;
})
if(undo_stack_length!=0){
	test_results.push(["Image Upload", true]);
}else{
	test_results.push(["Image Upload", false]);
} 
webpage.evaluate(function(){
	vb.tour_editor.undo_stack = [];
})
*/
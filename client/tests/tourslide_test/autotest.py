import os, subprocess, sys

# Check that the references are available
if(os.path.exists("./image_reference")==False):
	print("NO ./image_reference/ FOLDER, CREATE REFERENCE IMAGES BEFORE RUNNING")
	sys.exit()
# Identify our build ID
build = os.popen("git log -n1").read().split(" ")[1][:12]
	
# Delete old results and create directory if it doesnt exist
os.popen("rm -rf ./image_results/")
os.popen("mkdir ./image_results/")

print "Auto-Build-Tester\nTESTING BUILD ID "+build

# Run the automated test application
print "Running automated capture program\n----------------\n"
for x in range(7):
	p = subprocess.Popen('slimerjs slide_capture.js '+str(x), shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	for line in iter(p.stdout.readline, ''): print line,
print "\n----------------\nComplete, scanning for all images"
# Find all the images in the result folder

comparison_images = []

# Locate all result images and put them in a list
for file in os.listdir("./image_results/"):
    if file.endswith(".png"):
        comparison_images.append(file)
		
print(str(len(comparison_images))+" images total")


diffirences = []

# Record the filename and the diffirence
diffirence_table = []

# Compare the images by generating diffs of each image set
print "Generating diffs"
for image in comparison_images:
	os.popen("compare ./image_results/"+image+" ./image_reference/"+image+" \
          -compose Src -highlight-color White -lowlight-color Black \
          ./image_results/DIFF_"+image)
		  
	# Calculate diffirence
	os.popen("convert ./image_results/DIFF_"+image+" -compress none thing.ppm")
	f=open('thing.ppm').read().replace('\n',' ').split(' ')
	diffirence = 100-(((f.count("0")/3.0)/(int(f[1])*int(f[2])))*100)
	
	diffirences.append(diffirence)
	
	diffirence_table.append((image, diffirence))
	
	if diffirence>1:
		print "WARNING", diffirence, " % difference", image
	else:
		print diffirence, " % difference", image
		
# Sort the list of images and diffs by percentage (BIGGEST DIFFIRENCES FIRST)
diffirence_table =  sorted(diffirence_table, key=lambda item: item[1], reverse=True)
	  
# Rename all the images to prevent collision with reference images
for file in os.listdir("./image_results/"):
    if file.endswith(".png"):
		os.popen("mv ./image_results/"+file+" ./image_results/RESULT_"+file)
		
# Generate an HTML page that compares all the images side by side
print "Done... Generating HTML Image Compare Sheet"
text_file = open("./image_results/index.html", "w")
#counter = 0
#for image in comparison_images:
#	if diffirences[counter] > 1:
#		text_file.write(image+' - POSSIBLE ERROR - ERROR PERCENTAGE: '+str(diffirences[counter])+'<br><a href="'+image+'"><img src="'+image+'" alt="Reference Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a>')
#	else:# Generate html file
#		text_file.write(image+' - Result OK! - Error Percentage: '+str(diffirences[counter])+'<br><a href="'+image+'"><img src="'+image+'" alt="Reference Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a>')
#
#	text_file.write('<a href="RESULT_DIFF_'+image+'"><img src="RESULT_DIFF_'+image+'" alt="Diffirence Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a>')
#	text_file.write('<a href="RESULT_'+image+'"><img src="RESULT_'+image+'" alt="Result Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a><hr>')
#	#<img src="RESULT_DIFF_'+image+'" alt="Diffirence Image" height="288" width="512"> <img src="RESULT_'+image+'" alt="Result Image" height="288" width="512"><hr>')
#	counter+=1


for item in diffirence_table:
	if item[1] > 1:
		text_file.write('POSSIBLE ERROR - ERROR PERCENTAGE: '+str(item[1])+' - '+item[0]+'<br><a href="'+item[0]+'"><img src="'+item[0]+'" alt="Reference Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a>')
	else:# Generate html file
		text_file.write('Result OK! - Error Percentage: '+str(item[1])+' - '+item[0]+'<br><a href="'+item[0]+'"><img src="'+item[0]+'" alt="Reference Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a>')
		
	text_file.write('<a href="RESULT_DIFF_'+item[0]+'"><img src="RESULT_DIFF_'+item[0]+'" alt="Diffirence Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a>')
	text_file.write('<a href="RESULT_'+item[0]+'"><img src="RESULT_'+item[0]+'" alt="Result Image" style="width:30vw;height:'+str(30.0/1280*720)+'vw"></a><hr>')



text_file.close()

# Upload all files of result folder to server, then upload all reference images to server as well
print "Done... Uploading results, diff & reference to server\n----------------\n"
p = subprocess.Popen('rsync -zrP ./image_results/* autoqa@dev.vidabody.com:www/'+build+'/', shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
for line in iter(p.stdout.readline, ''): print line,
p = subprocess.Popen('rsync -zrP ./image_reference/* autoqa@dev.vidabody.com:www/'+build+'/', shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
for line in iter(p.stdout.readline, ''): print line,
print "\n----------------\nComplete!"

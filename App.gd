extends Control

var current_os = OS.get_name()
var download_link = ''
var file_name = ''
var file_name_prefix = 'blender-2.80'
var file_ext = ''
var date = ''
var up_to_date = false
var blender_hash = ''
var button_clicked = 0

func _ready():
	$HTTPRequest.request("https://builder.blender.org/download/")
	match current_os:
		"Windows":
			$OSSelector.select(0)
			file_ext = ".zip"
			_disable_arch(false)
		"OSX":
			$OSSelector.select(1)
			file_ext = ".zip"
			_disable_arch(true)
		"X11":
			$OSSelector.select(2)
			file_ext = ".tar.bz2"
			_disable_arch(true)


	# Add the date and extension to the file name to compare to previous versions
	date = OS.get_date(true)
	date = str(date['day']) + '-' + str(date['month']) + '-' + str(date['year'])
	_update_file_name()
	

	$ProgressBar.value = 0
	up_to_date = is_up_to_date()
	
	

func is_up_to_date():
	# Check if the daily zip already exists on our system
	var dir = Directory.new()
	if dir.file_exists(OS.get_user_data_dir() + '/' + file_name):
		$DownloadButton.text = "Open Directory"
		$DownloadButton.disabled = false
		return true
	return false


func update_download_link():
	# Get the proper download link
	if $OSSelector.selected == 0:
		if $SystemSelector.selected == 1:
			download_link = 'https://builder.blender.org/download/blender-2.80-'+str(blender_hash)+'-win32.zip'
		else:
			download_link = 'https://builder.blender.org/download/blender-2.80-'+str(blender_hash)+'-win64.zip'	

	elif $OSSelector.selected == 1:
		download_link = 'https://builder.blender.org/download/blender-2.80-'+str(blender_hash)+'-OSX-10.9-x86_64.zip'
	else:
		download_link = 'https://builder.blender.org/download/blender-2.80-'+str(blender_hash)+'-linux-glibc224-x86_64.tar.bz2'
	print('[+] Updating download link: ', download_link)



func _on_AboutButton_pressed():
	$AboutDialog.popup()

func _on_OSSelector_item_selected(ID):
	match ID:
		0:
			file_ext = ".zip"
			_disable_arch(false)
		1:
			file_ext = ".zip"
			_disable_arch(true)
		2:
			file_ext = ".tar.bz2"
			_disable_arch(true)
			
	update_download_link()


func _disable_arch(b):
	$SystemSelector.disabled = b
	$SystemSelector.select(0)

func _on_SystemSelector_item_selected(_ID):
	update_download_link()
	up_to_date = false

func _on_DownloadButton_pressed():
	button_clicked = 1
	_update_file_name()
	
	var file_path = "user://" + file_name
	
	if up_to_date:
		# It would be nice to open the downloaded file directly
		# but I've been having a lot of issues doing this so
		# I think that opening the container dir is enough for now
		OS.shell_open(OS.get_user_data_dir())
	else:
		# No file found here so we can go ahead and download
		# the latest version
		print("[+] Starting download")
		$DownloadButton.disabled = true
		$DownloadButton.text = "Downloading..."
		# Checking if a previous version exists and removing them
		print(list_files_in_directory(OS.get_user_data_dir()))
		var dir = Directory.new()
		for file in list_files_in_directory(OS.get_user_data_dir()):
			if 'blender-2.80' in file:
				dir.remove('user://' + file)
			
		# Downloading file
		$HTTPRequest.set_download_file(file_path)
		$HTTPRequest.request(download_link)
		print($HTTPRequest.get_body_size())

func _process(_delta):
	var size = 0
	var current = 0
	if $HTTPRequest.get_body_size() != -1:
		size = $HTTPRequest.get_body_size()
		current = $HTTPRequest.get_downloaded_bytes()
		$ProgressBar.value = current*100/size
		
func _on_HTTPRequest_request_completed(result, response_code, headers, body):
#func _on_HTTPRequest_request_completed(result, response_code, _headers, _body):
	# When the zip is downloaded
	
	var all = body.get_string_from_utf8()
	
	var regex = RegEx.new()
	regex.compile(".*(blender-2.80-)([0-9a-zA-Z]*)(-linux-glibc224-x86_64.tar.bz2).*")
	var rresult = regex.search(all)
	if rresult:
		blender_hash = rresult.get_string(2)
		print(rresult.get_string(2))
	
	update_download_link()
	
	
	if button_clicked == 1:
		print("[+] Download completed ", result, ", ", response_code)
		var cwd = OS.get_user_data_dir()
		if current_os == "Windows":
			# Unzip file
			var _command = OS.execute("unzip.exe", [cwd + '/' + file_name, '-d', cwd], true)
			OS.execute("mv", [cwd + '/godot.exe', cwd + '/godot-nightly.exe'], true)
			up_to_date = is_up_to_date()
			# Open the dir
			OS.shell_open(OS.get_user_data_dir())
		elif current_os == "X11":
			OS.execute('/bin/tar jxf', [cwd + '/' + file_name], false)
			OS.execute('/usr/bin/chmod', ['+x', cwd + '/' + file_name], false)
			up_to_date = is_up_to_date()
			OS.shell_open(OS.get_user_data_dir())
		else:
			print('Todo on osx')
		button_clicked = 0

func list_files_in_directory(path):
	# By volzhs
	# https://godotengine.org/qa/5175/how-to-get-all-the-files-inside-a-folder
    var files = []
    var dir = Directory.new()
    dir.open(path)
    dir.list_dir_begin()

    while true:
        var file = dir.get_next()
        if file == "":
            break
        elif not file.begins_with("."):
            files.append(file)

    dir.list_dir_end()

    return files

func _on_Label2_meta_clicked(meta):
	OS.shell_open(meta)


func _on_Warning_meta_clicked(meta):
	OS.shell_open(meta)
	
func _update_file_name():
	file_name = file_name_prefix + '-' + date + file_ext

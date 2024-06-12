extends Node3D

var xr_interface: XRInterface


#meta
var version = "v0.3.1"


#task parameters
var p_tone = 80
var total_trials = 65
var noise_db = -20
var tone_db_min = -40
var tone_db_max = -20


#vars
var tone = true
var answer = true
var correct
var confidence = 0.0
var answer_coords
var confidence_coords
var answer_time
var confidence_time
var state = "iti"
var data = {}
var rand_vol_db
var score = 0

#data vars
var UID 
var ID = 0
var save_file_name = ""
var trial = 0
var trial_start


var can_select = false

# Headset position / orientation at application launch (not yet synchronized) :
@onready var uninitialized_hmd_transform:Transform3D = XRServer.get_hmd_transform()
var hmd_synchronized:bool = false



func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")
		xr_interface.pose_recentered.connect(_on_openxr_pose_recentered)
		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
	else:
		print("OpenXR not initialized, please check if your headset is connected")
		
		
	
	$noise.volume_db = noise_db
	$noise.play()
	
	$answer_timer.one_shot = true
	$confidence_timer.one_shot = true
	$feedback_timer.one_shot = true
	$trial_timer.one_shot = true
	$iti_timer.one_shot = true
	$continue_timer.one_shot = true
	$end_timer.one_shot = true
	
	$answer.visible = false
	$answer/no.text = "no"
	$answer/yes.text = "yes"
	
	$confidence.visible = false
	$confidence/not_conf.text = "not confident"
	$confidence/conf.text = "confident"
	
	$continue_text.visible = false
	
	
	score = 0
	
	init_file()
	
	start()


func _on_openxr_pose_recentered() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)


func start():
	state = "start"
	$instructions.visible = true
	#$instructions.text = ""
	$participant_id.visible = true
	$participant_id.text = str(ID)


func _process(_delta):
	#print($XROrigin3D/XRCamera3D.rotation)
	#print($XROrigin3D.global_transform.origin )
	if state == "confidence":
		$confidence/slider.position.x = clamp(remap($XROrigin3D/XRCamera3D.rotation.y, 0.3, -0.32, 8, 64),8,64)
		#print($XROrigin3D/XRCamera3D.rotation.y)
	elif state == "continue":
		if $XROrigin3D/XRCamera3D.rotation.x < -0.15 and $XROrigin3D/XRCamera3D.rotation.x > -0.25 and $XROrigin3D/XRCamera3D.rotation.y > -0.3 and $XROrigin3D/XRCamera3D.rotation.y < 0.3:
			$continue_text.scale = Vector3(2.5,2.5,2.5)
		else: 
			$continue_text.scale = Vector3(1,1,1)
	elif state == "trial":
		if $XROrigin3D/XRCamera3D.rotation.x > -0.1 and $XROrigin3D/XRCamera3D.rotation.x < -0.01 and $XROrigin3D/XRCamera3D.rotation.y > -0.3 and $XROrigin3D/XRCamera3D.rotation.y < 0.3:
			$answer/no.scale = Vector3(3,3,3)
			can_select = 1
		elif $XROrigin3D/XRCamera3D.rotation.x > -0.4 and $XROrigin3D/XRCamera3D.rotation.x < -0.3 and $XROrigin3D/XRCamera3D.rotation.y > -0.3 and $XROrigin3D/XRCamera3D.rotation.y < 0.3:
			$answer/yes.scale = Vector3(3,3,3)
			can_select = 2
		else:
			$answer/yes.scale = Vector3(1,1,1)
			$answer/no.scale = Vector3(1,1,1)
			can_select = 0
	if hmd_synchronized:
		return
	# Synchronizes headset ORIENTATION as soon as tracking information begins to arrive :
	if uninitialized_hmd_transform != XRServer.get_hmd_transform():
		hmd_synchronized = true
		_on_openxr_pose_recentered()




func continue_task():
	state = "continue"
	$continue_text.visible = true



func start_trial():
	state = "trial"
	$XROrigin3D/XRCamera3D/camera_label.text = ""
	if trial == total_trials:
		#$XROrigin3D/XRCamera3D/camera_label.text = "end"
		end_task()
	else:
		trial = trial + 1
		
		trial_start = Time.get_unix_time_from_system()
		
		var rand_p_tone = randi() % 101
		
		rand_vol_db = randf_range(tone_db_min,tone_db_max)
		print(rand_p_tone, rand_vol_db)
		
		$Tone_logo_yellow.visible = true
		
		
		if rand_p_tone <  p_tone:
			tone = true
			$tone.volume_db = rand_vol_db
			$tone.play()
		else:
			tone = false
		
		
		$answer_timer.start(1)

func start_feedback():
	state = "feedback"
	$XROrigin3D/XRCamera3D/camera_label.scale = Vector3(2,2,2)
	if correct == true:
		$XROrigin3D/XRCamera3D/camera_label.text = str("Correct \n +1000 \n Score: ",score)
		$XROrigin3D/XRCamera3D/camera_label.modulate = Color(0,1,0)
		$score_text.visible = false
		$score_text.text = str("Score: ",score)
		score += 1000
		
	else:
		$XROrigin3D/XRCamera3D/camera_label.text = str("Wrong \n +0 \n Score: ",score)
		$XROrigin3D/XRCamera3D/camera_label.modulate = Color(1,0,0)
		$score_text.visible = false
		$score_text.text = str("Score: ",score)
	$continue_timer.start(1)


func start_confidence():
	state = "confidence"
	#$XROrigin3D/XRCamera3D/camera_label.text = "How confident are you?"
	$confidence.visible = true


func _on_right_hand_button_pressed(name):
	if state == "start":
		if name == "ax_button":
			ID = ID+1
		elif name == "by_button":
			ID = clamp(ID-1,0,9999)
			
		$participant_id.text = str(ID)
		print(ID)
	select_option(name)

func _on_left_hand_button_pressed(name):
	if state == "start":
		if name == "ax_button":
			ID = ID+1
		elif name == "by_touch":
			ID = clamp(ID-1,0,9999)
		$participant_id.text = str(ID)
	select_option(name)

func _on_right_hand_input_vector_2_changed(name, value):
	if state == "start":
		if name == "primary":
			if value.y < -0.2:
				ID = ID+1
			if value.y > 0.2:
				ID = clamp(ID-1,0,9999)
		$participant_id.text = str(ID)



func select_option(name):
	if state == "start":
		if name == "trigger_click":
			$instructions.visible = false
			$participant_id.visible = false
			continue_task()
	elif state == "trial":
		if name == "trigger_click" and can_select > 0:
			if can_select == 1:
				$XROrigin3D/XRCamera3D/camera_label.text = "no"
				answer = false
				$confidence_timer.start(1)
			elif can_select == 2:
				$XROrigin3D/XRCamera3D/camera_label.text = "yes"
				answer = true
				$confidence_timer.start(1)
			if tone == answer:
				correct = true
			else:
				correct = false
			answer_time = Time.get_unix_time_from_system()
			answer_coords = $XROrigin3D/XRCamera3D.rotation
			$answer.visible = false
			state ="iti"
			
	elif state == "confidence":
		if name == "trigger_click":
			$XROrigin3D/XRCamera3D/camera_label.text = str($XROrigin3D/XRCamera3D.rotation.y)
			confidence = clamp(remap($XROrigin3D/XRCamera3D.rotation.y, 0.45, -0.45, 0, 76),0,76)
			confidence_time = Time.get_unix_time_from_system()
			$confidence.visible = false
			confidence_coords = $XROrigin3D/XRCamera3D.rotation
			
			$feedback_timer.start(2)
			state = "iti"
			
			$XROrigin3D/XRCamera3D/camera_label.text = ""
			
			log_data()
	elif state == "continue":
		if name == "trigger_click":
			if $XROrigin3D/XRCamera3D.rotation.x < -0.15 and $XROrigin3D/XRCamera3D.rotation.x > -0.25 and $XROrigin3D/XRCamera3D.rotation.y > -0.3 and $XROrigin3D/XRCamera3D.rotation.y < 0.3:
				$trial_timer.start(2)
				$continue_text.visible = false

		

#-0.17

func _on_trial_timer_timeout():
	$XROrigin3D/XRCamera3D/camera_label.text = ""
	$continue_text.visible = false
	$Tone_logo.visible = true
	$iti_timer.start(randi() % 5)


func _on_feedback_timer_timeout():
	start_feedback()
	

func _on_confidence_timer_timeout():
	start_confidence()
	

func _on_answer_timer_timeout():
	$Tone_logo.visible = false
	$Tone_logo_yellow.visible = false
	$answer.visible = true
	#$XROrigin3D/XRCamera3D/camera_label.text = "Did you hear a tone?"


func _on_iti_timer_timeout():
	start_trial()



func _on_continue_timer_timeout():
	$XROrigin3D/XRCamera3D/camera_label.text = ""
	$XROrigin3D/XRCamera3D/camera_label.modulate = Color(1,1,1)
	$XROrigin3D/XRCamera3D/camera_label.scale = Vector3(1,1,1)
	$score_text.visible = false
	continue_task()


func init_file():
	UID = Time.get_unix_time_from_system()
	save_file_name = str(ID,"_",UID)
	
#build data dict
	data = {
		#trial info
		"trial":[],
		"trial_start":[],
		"tone":[],
		"answer":[],
		"correct":[],
		"score":[],
		
		"answer_time":[],
		"answer_coords":[],
		"answer_x":[],
		"answer_y":[],
		"answer_z":[],
		
		"confidence":[],
		"confidence_time":[],
		"confidence_coords":[],
		"confidence_x":[],
		"confidence_y":[],
		"confidence_z":[],
		
		"rand_vol_db":[],
		
		#metadata
		"subj_id":[],
		"subj_uid":[],
		"version":[],
		"start_time":[], #redundant
		
		#task parameters
		"prob_tone":[],
		"tone_db_min":[],
		"tone_db_max":[],
		"noise_db":[],
		
		
		}


func log_data():
	#trial info
	data["trial"].push_back(trial)
	data["trial_start"].push_back(trial_start)
	data["tone"].push_back(tone)
	data["answer"].push_back(answer)
	data["correct"].push_back(correct)
	data["score"].push_back(score)
	data["answer_time"].push_back(answer_time)
	data["answer_coords"].push_back(answer_coords)
	data["answer_x"].push_back(answer_coords.x)
	data["answer_y"].push_back(answer_coords.y)
	data["answer_z"].push_back(answer_coords.z)
	data["confidence"].push_back(confidence)
	data["confidence_time"].push_back(confidence_time)
	data["confidence_coords"].push_back(confidence_coords)
	data["confidence_x"].push_back(confidence_coords.x)
	data["confidence_y"].push_back(confidence_coords.y)
	data["confidence_z"].push_back(confidence_coords.z)
	data["rand_vol_db"].push_back(rand_vol_db)
	
	#metadata
	data["subj_id"].push_back(ID)
	data["subj_uid"].push_back(UID)
	
	data["version"].push_back(version)
	data["start_time"].push_back(UID)
	
	#task parameters
	data["prob_tone"].push_back(p_tone)
	data["tone_db_min"].push_back(tone_db_min)
	data["tone_db_max"].push_back(tone_db_max)
	data["noise_db"].push_back(noise_db)
	
	
	var file = FileAccess.open(str(str(OS.get_system_dir(2)), "/" ,str(save_file_name), ".json"), FileAccess.WRITE)
	file.store_line(JSON.stringify(data))
	file.close()


func end_task():
	print(OS.get_system_dir(2))
	var file = FileAccess.open(str(str(OS.get_system_dir(2)), "/" ,str(save_file_name), ".json"), FileAccess.WRITE)
	file.store_line(JSON.stringify(data))
	file.close()
	$instructions.visible = true
	$instructions.text = str("Thank you for playing! \n","You scored ",score," points!  \n We hoped you enjoyed the Noise Salon. \n Please take off your headset and call an experimenter. \n Enjoy the festival.")
	$end_timer.start(60)







func _on_end_timer_timeout():
	get_tree().quit()



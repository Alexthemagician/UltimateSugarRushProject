extends Node

signal status_changed
var session_file := "user://cafe_online_session.cfg"
var endpoint := ""
var publishable_key := ""
var busy := false
var last_error := ""
var profile: Dictionary = {}
var _session: Dictionary = {}
var _relationship_by_code: Dictionary = {}
const STARTER_CAFES: Array[Dictionary] = [
	{"code":"STARTER_BERRY","display_name":"Rosie's Berry Nook","layout":{"version":1,"theme":"strawberry","display_style":"rose","table_position":[4.0,-0.5],"upgrades":{"oven":true,"garden":false,"seating":true}}},
	{"code":"STARTER_MINT","display_name":"Milo's Mint Kitchen","layout":{"version":1,"theme":"mint","display_style":"sage","table_position":[5.0,0.5],"upgrades":{"oven":false,"garden":true,"seating":true}}},
	{"code":"STARTER_COCOA","display_name":"Coco Moon Café","layout":{"version":1,"theme":"cocoa","display_style":"walnut","table_position":[4.5,1.0],"upgrades":{"oven":true,"garden":true,"seating":false}}},
]

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("res://online.cfg") == OK:
		endpoint = str(config.get_value("supabase","url","")).trim_suffix("/")
		publishable_key = str(config.get_value("supabase","publishable_key",""))
	var saved := ConfigFile.new()
	if saved.load(session_file) == OK and saved.get_value("session","endpoint","") == endpoint:
		_session = saved.get_value("session","tokens",{})

func configured() -> bool:
	return endpoint.begins_with("https://") and not publishable_key.is_empty()

func public_layout() -> Dictionary:
	var life := get_node("/root/CafeLife")
	var position: Vector2 = life.table_position()
	var upgrades := {}
	for id in life.UPGRADES: upgrades[id] = life.has_upgrade(id)
	return {"version":1,"theme":life.decor_theme(),"display_style":life.display_style(),"table_position":[position.x,position.y],"upgrades":upgrades}

func call_service(action: String, payload: Dictionary = {}) -> Dictionary:
	var starter_code := str(payload.get("code",""))
	var starter := _starter_by_code(starter_code)
	if not starter.is_empty() and action in ["visit","request","remove"]:
		if action == "request":
			SaveSystem.set_value("starter_friends",starter_code,true)
			_relationship_by_code[starter_code] = "friend"
			return {"ok":true,"data":{"accepted":true}}
		if action == "remove":
			SaveSystem.set_value("starter_friends",starter_code,false)
			_relationship_by_code[starter_code] = "none"
			return {"ok":true,"data":{"removed":true}}
		var snapshot := starter.duplicate(true)
		snapshot["status"] = "friend" if _starter_is_friend(starter_code) else "none"
		return {"ok":true,"data":snapshot}
	if busy: return {"ok":false,"error":"Another online request is still finishing."}
	if not configured(): return _failure("Online café visits are not connected yet.")
	busy = true
	last_error = ""
	status_changed.emit()
	var auth := await _ensure_session()
	var result: Dictionary = auth
	if bool(auth.get("ok",false)):
		var rpc_path := "/rest/v1/rpc/cafe_discover" if action == "discover" else ("/rest/v1/rpc/cafe_friend_action" if action in ["request","remove"] else "/rest/v1/rpc/cafe_social")
		var rpc_body := {} if action == "discover" else ({"action":action,"payload":payload})
		result = await _request(rpc_path,rpc_body,true)
		if int(result.get("status",0)) == 401:
			_session["expires_at"] = 0
			auth = await _ensure_session()
			if bool(auth.get("ok",false)):
				result = await _request(rpc_path,rpc_body,true)
			else: result = auth
	busy = false
	if not bool(result.get("ok",false)): last_error = str(result.get("error","Could not connect."))
	elif action in ["profile","register"]: profile = result.data
	elif action == "discover":
		for starter_cafe in STARTER_CAFES:
			var card := starter_cafe.duplicate(true)
			card.erase("layout")
			card["visits_enabled"] = true
			card["status"] = "friend" if _starter_is_friend(str(card.code)) else "none"
			result.data.cafes.append(card)
		for cafe: Dictionary in result.data.get("cafes",[]):
			_relationship_by_code[str(cafe.get("code",""))] = str(cafe.get("status","none"))
	elif action == "friends":
		for starter_cafe in STARTER_CAFES:
			if not _starter_is_friend(str(starter_cafe.code)): continue
			result.data.friends.append({"code":starter_cafe.code,"display_name":starter_cafe.display_name,"status":"friend","visits_enabled":true})
		for friend: Dictionary in result.data.get("friends",[]):
			_relationship_by_code[str(friend.get("code",""))] = str(friend.get("status","none"))
	elif action == "visit" and result.get("data") is Dictionary:
		result.data["status"] = _relationship_by_code.get(str(result.data.get("code","")),"none")
	status_changed.emit()
	return result

func _starter_by_code(code: String) -> Dictionary:
	for starter in STARTER_CAFES:
		if str(starter.code) == code: return starter
	return {}

func _starter_is_friend(code: String) -> bool:
	return bool(SaveSystem.get_value("starter_friends",code,true))

func _ensure_session() -> Dictionary:
	if not str(_session.get("access_token","")).is_empty() and float(_session.get("expires_at",0)) > Time.get_unix_time_from_system()+60:
		return {"ok":true}
	var refresh := str(_session.get("refresh_token",""))
	var path := "/auth/v1/signup" if refresh.is_empty() else "/auth/v1/token?grant_type=refresh_token"
	var body := {} if refresh.is_empty() else {"refresh_token":refresh}
	var result := await _request(path,body,false)
	if not bool(result.get("ok",false)):
		# Never silently create a replacement identity after refresh failure.
		return result
	var data: Dictionary = result.data
	if str(data.get("access_token","")).is_empty() or str(data.get("refresh_token","")).is_empty():
		return {"ok":false,"error":"The service could not create an online session."}
	_session = {"access_token":data.access_token,"refresh_token":data.refresh_token,
		"expires_at":float(data.get("expires_at",Time.get_unix_time_from_system()+float(data.get("expires_in",3600))))}
	var saved := ConfigFile.new()
	saved.set_value("session","endpoint",endpoint)
	saved.set_value("session","tokens",_session)
	if saved.save(session_file) != OK:
		return {"ok":false,"error":"Could not save your online session. Check device storage."}
	return {"ok":true}

func _request(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15
	http.body_size_limit = 262144
	http.max_redirects = 0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json","apikey: "+publishable_key])
	if authenticated: headers.append("Authorization: Bearer "+str(_session.get("access_token","")))
	var started := http.request(endpoint+path,headers,HTTPClient.METHOD_POST,JSON.stringify(body))
	if started != OK:
		http.queue_free()
		return {"ok":false,"error":"Could not start the connection. Please try again."}
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok":false,"error":"Connection interrupted. Check your internet and try again."}
	var status := int(response[1])
	var decoded: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if status < 200 or status >= 300:
		var message := "The café service is unavailable. Please try again."
		if status == 429: message = "Too many requests. Please wait a moment and try again."
		elif status == 401: message = "Your online session could not be restored."
		elif decoded is Dictionary:
			# Only display known game errors; never echo arbitrary proxy/auth response bodies.
			var server_message := str(decoded.get("message",""))
			if server_message in ["Cafe code not found","This cafe is not open for visits","This is your own code","Your friends list is full","This cafe cannot receive more friend requests","No incoming request","Create your cafe profile first","Choose a name of 1 to 32 characters"]:
				message = server_message
		return {"ok":false,"status":status,"error":message}
	if not decoded is Dictionary: return {"ok":false,"error":"The café service returned an unreadable response."}
	return {"ok":true,"status":status,"data":decoded}

func _failure(message: String) -> Dictionary:
	last_error = message
	status_changed.emit()
	return {"ok":false,"error":message}

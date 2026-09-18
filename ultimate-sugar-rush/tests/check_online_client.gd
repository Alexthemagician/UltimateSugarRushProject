extends SceneTree

class FakeClient extends "res://scripts/core/cafe_online.gd":
	var replies: Array[Dictionary] = []
	var calls: Array[Dictionary] = []
	func _ready() -> void: pass
	func _request(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
		calls.append({"path":path,"body":body.duplicate(true),"authenticated":authenticated})
		return replies.pop_front()

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var client := FakeClient.new()
	root.add_child(client)
	var result: Dictionary = await client.call_service("profile")
	check(not result.ok and client.calls.is_empty(),"Unconfigured build makes no network request")
	client.endpoint = "https://test.invalid"
	client.publishable_key = "test-public-key"
	client._session = {}
	client.replies = [
		{"ok":true,"data":{"access_token":"test-access","refresh_token":"test-refresh","expires_in":3600}},
		{"ok":true,"data":{"code":"TESTCODE1234","display_name":"Test"}}
	]
	result = await client.call_service("register",{"display_name":"Test"})
	check(result.ok and client.profile.code=="TESTCODE1234","Profile response retained")
	check(client.calls[0].path=="/auth/v1/signup" and not client.calls[0].authenticated,"First use establishes identity")
	check(client.calls[1].authenticated,"RPC requires player bearer token")
	client.replies = [{"ok":true,"data":{"friends":[]}}]
	await client.call_service("friends")
	check(client.calls.size()==3,"Valid session reused")
	client._session.expires_at = 0
	client.replies = [{"ok":false,"status":400,"error":"Refresh failed"}]
	result = await client.call_service("friends")
	check(not result.ok and not client.busy,"Failed refresh releases request state")
	check(client.calls[-1].path.contains("grant_type=refresh_token"),"Expired identity uses refresh")
	check(client._session.refresh_token=="test-refresh","Refresh failure preserves identity instead of creating a replacement")
	client.busy = true
	var count := client.calls.size()
	result = await client.call_service("friends")
	check(not result.ok and client.calls.size()==count,"Concurrent requests do not rotate refresh tokens twice")
	client.busy = false
	var layout := client.public_layout()
	check(layout.keys().size()==5 and not layout.has("inventory") and not layout.has("tokens"),"Snapshot contains only public layout fields")
	check(layout.version==1 and layout.table_position.size()==2,"Snapshot follows service contract")
	client.queue_free()
	print("Online client: %d failures" % failures)
	quit(failures)

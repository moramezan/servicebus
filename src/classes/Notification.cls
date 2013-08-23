global class Notification {
	
	private Map<String,Object> state = new Map<String,Object>();
	
	public void put(String key, Object value) {
		this.state.put(key, value);
	}
	
	public Object get(String key) {
		return this.state.get(key);
	}
	
}
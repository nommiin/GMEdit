package gml;
import tools.Dictionary;

/**
 * ...
 * @author YellowAfterlife
 */
class GmlSeekData {
	/** path -> data */
	public static var map:Dictionary<GmlSeekData> = new Dictionary();
	private static var blank:GmlSeekData = new GmlSeekData();
	//
	public var enumList:Array<GmlEnum> = [];
	public var enumMap:Dictionary<GmlEnum> = new Dictionary();
	public var globalList:Array<GmlGlobal> = [];
	public var globalMap:Dictionary<GmlGlobal> = new Dictionary();
	public var macroList:Array<GmlMacro> = [];
	public var macroMap:Dictionary<GmlMacro> = new Dictionary();
	//
	public function new() {
		
	}
	public static function apply(prev:GmlSeekData, next:GmlSeekData) {
		if (prev == null) prev = blank;
		if (next == null) next = blank;
		// todo: updating for incremental changes
		// remove enums:
		for (e in prev.enumList) {
			if (next.enumMap.exists(e.name)) continue;
			for (comp in e.compList) GmlAPI.gmlComp.remove(comp);
			GmlAPI.gmlKind.remove(e.name);
			GmlAPI.gmlEnums.remove(e.name);
		}
		// add enums:
		for (e in next.enumList) {
			if (prev.enumMap.exists(e.name)) continue;
			for (comp in e.compList) GmlAPI.gmlComp.push(comp);
			GmlAPI.gmlEnums.set(e.name, e);
			GmlAPI.gmlKind.set(e.name, "enum");
		}
		// update enums:
		for (e in prev.enumList) {
			var q = next.enumMap[e.name];
			if (q == null) continue;
		}
		// add globals:
		for (g in next.globalList) {
			GmlAPI.gmlKind.set(g.name, "globalvar");
			GmlAPI.gmlComp.push(g.comp);
		}
		// add macros:
		for (m in next.macroList) {
			GmlAPI.gmlKind.set(m.name, "macro");
			GmlAPI.gmlComp.push(m.comp);
		}
	}
}
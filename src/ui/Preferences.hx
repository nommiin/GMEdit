package ui;
import ace.AceWrap;
import electron.FileSystem;
import electron.FileWrap;
import electron.Menu;
import file.kind.misc.KSnippets;
import gml.GmlAPI;
import gml.file.GmlFile;
import haxe.DynamicAccess;
import haxe.Json;
import haxe.io.Path;
import js.html.Element;
import js.html.InputElement;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.SelectElement;
import js.html.Window;
import Main.document;
import Main.console;
import tools.Dictionary;
import tools.NativeObject;
import ui.treeview.TreeView;
using tools.HtmlTools;

/**
 * User preferences are managed here!
 * @author YellowAfterlife
 */
class Preferences {
	public static var path:String = "user-preferences";
	public static var current:PrefData;
	public static var element:Element;
	public static var subMenu:Element;
	static function setMenu(el:Element) {
		if (subMenu != el) {
			if (subMenu != null) element.removeChild(subMenu);
			subMenu = el;
			element.appendChild(el);
		}
		return el;
	}
	//
	private static function addRadios(out:Element, legend:String, curr:String, names:Array<String>, fn:String->Void) {
		var fs = document.createFieldSetElement();
		fs.classList.add("radios");
		var lg = document.createLegendElement();
		lg.innerText = legend;
		fs.appendChild(lg);
		for (name in names) {
			var id = createValidIdFromString(name);
			var rad = document.createInputElement();
			rad.type = "radio";
			rad.name = legend;
			rad.value = name;
			rad.id = id;
			rad.addEventListener("change", function(_) {
				fn(name);
			});
			if (curr == name) rad.checked = true;
			var lb = document.createLabelElement();
			lb.htmlFor = id;
			lb.appendChild(rad);
			lb.appendChild(document.createTextNode(name));
			fs.appendChild(lb);
			fs.appendChild(document.createBRElement());
		}
		out.appendChild(fs);
		return fs;
	}
	private static function addDropdown(out:Element, legend:String, curr:String, names:Array<String>, fn:String->Void) {
		var ctr = document.createDivElement();
		ctr.classList.add("select");
		//
		var lb = document.createLabelElement();
		lb.htmlFor = legend;
		lb.appendChild(document.createTextNode(legend));
		ctr.appendChild(lb);
		//
		var sel = document.createSelectElement();
		for (name in names) {
			var opt = document.createOptionElement();
			opt.value = name;
			opt.appendChild(document.createTextNode(name));
			sel.appendChild(opt);
		}
		sel.addEventListener("change", function(_) {
			fn(sel.value);
		});
		sel.value = curr;
		ctr.appendChild(sel);
		//
		out.appendChild(ctr);
		return ctr;
	}
	private static function addCheckbox(out:Element, legend:String, curr:Bool, fn:Bool->Void):Element {
		var id = createValidIdFromString(legend);
		var ctr = document.createDivElement();
		ctr.classList.add("checkbox");
		var cb = document.createInputElement();
		cb.type = "checkbox";
		cb.checked = curr;
		cb.name = legend;
		cb.addEventListener("change", function(_) {
			fn(cb.checked);
		});
		cb.id = id;
		// ctr.appendChild(cb);
		var lb = document.createLabelElement();
		lb.htmlFor = id;
		lb.appendChild(cb);
		lb.appendChild(document.createTextNode(legend));
		ctr.appendChild(lb);
		out.appendChild(ctr);
		return ctr;
	}
	private static function addInput(out:Element, legend:String, curr:String, fn:String->Void):Element {
		var ctr = document.createDivElement();
		ctr.classList.add("input");
		//
		var lb = document.createLabelElement();
		lb.htmlFor = legend;
		lb.appendChild(document.createTextNode(legend));
		ctr.appendChild(lb);
		//
		var cb = document.createInputElement();
		cb.type = "text";
		cb.value = curr;
		cb.name = legend;
		cb.addEventListener("change", function(_) {
			fn(cb.value);
		});
		cb.addEventListener("keydown", function(e:KeyboardEvent) {
			if (e.keyCode == KeyboardEvent.DOM_VK_RETURN) fn(cb.value);
		});
		ctr.appendChild(cb);
		//
		out.appendChild(ctr);
		return ctr;
	}
	private static function addIntInput(out:Element, legend:String, val:Int, fn:Int->Void):Element {
		var fd:InputElement = null;
		var el = addInput(out, legend, val != null ? ("" + val) : "", function(s:String) {
			var v = Std.parseInt(s);
			if (v != null) {
				fd.classList.remove("error");
				fn(v);
			} else fd.classList.add("error");
		});
		fd = el.querySelectorAuto("input");
		return el;
	}
	private static function addFloatInput(out:Element, legend:String, val:Float, fn:Float->Void):Element {
		var fd:InputElement = null;
		var el = addInput(out, legend, val != null ? ("" + val) : "", function(s:String) {
			var v = Std.parseFloat(s);
			if (!Math.isNaN(v)) {
				fd.classList.remove("error");
				fn(v);
			} else fd.classList.add("error");
		});
		fd = el.querySelectorAuto("input");
		return el;
	}
	private static function addButton(out:Element, text:String, fn:Void->Void):Element {
		var ctr = document.createDivElement();
		ctr.classList.add("button");
		var el = document.createAnchorElement();
		el.href = "#";
		el.appendChild(document.createTextNode(text));
		el.addEventListener("click", function(e:MouseEvent) {
			e.preventDefault();
			fn();
		});
		ctr.appendChild(el);
		out.appendChild(ctr);
		return ctr;
	}
	private static function addText(out:Element, text:String):Element {
		var ctr = document.createDivElement();
		ctr.classList.add("plaintext");
		ctr.appendChild(document.createTextNode(text));
		out.appendChild(ctr);
		return ctr;
	}
	private static function createShellAnchor(url:String, label:String) {
		var a = document.createAnchorElement();
		a.href = url;
		a.target = "_blank";
		a.onclick = function(_) {
			electron.Shell.openExternal(url);
			return false;
		};
		a.appendChild(document.createTextNode(label));
		return a;
	}
	private static function addWiki(to:Element, url:String, label:String = "wiki") {
		var lb = to.querySelector("label");
		lb.appendChild(document.createTextNode(" ("));
		lb.appendChild(createShellAnchor(url, label));
		lb.appendChild(document.createTextNode(")"));
	}
	//
	private static var menuMain:Element;
	private static function buildMain() {
		var out = document.createElement("div");
		var el:Element;
		//
		var themeList = ["default"];
		if (!FileSystem.canSync) {
			themeList.push("dark");
			themeList.push("gms2");
		} else {
			for (dir in [
				Main.relPath(Theme.path),
				FileWrap.userPath + "/themes" 
			]) if (FileSystem.existsSync(dir)
			) for (name in FileSystem.readdirSync(dir)) {
				if (name == "default") continue;
				var full = Path.join([dir, name, "config.json"]);
				if (FileSystem.existsSync(full)) themeList.push(name);
			}
		}
		el = addRadios(out, "Theme", current.theme, themeList, function(theme) {
			current.theme = theme;
			Theme.current = theme;
			save();
		});
		el = el.querySelector('legend');
		el.appendChild(document.createTextNode(" ("));
		el.append(createShellAnchor("https://github.com/GameMakerDiscord/GMEdit/wiki/Using-themes", "wiki"));
		el.appendChild(document.createTextNode("; "));
		el.append(createShellAnchor(FileWrap.userPath + "/themes", "manage"));
		el.appendChild(document.createTextNode(")"));
		//
		el = addCheckbox(out, "Use `#args` magic", current.argsMagic, function(z) {
			current.argsMagic = z;
			save();
		});
		el.title = "Allows writing `#args a, b` instead of `var a = argument0, b = argument1`.";
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/Using-%23args-magic");
		//
		var noAutoArgs = "Don't auto-generate";
		el = addDropdown(out, "JSDoc format for #args",
			current.argsFormat != "" ? current.argsFormat : noAutoArgs,
			[noAutoArgs, "@arg", "@param", "@argument"],
			function(v) {
				if (v == noAutoArgs) v = "";
				current.argsFormat = v;
				save();
			});
		//
		el = addCheckbox(out, "Use `#import` magic", current.importMagic, function(z) {
			current.importMagic = z;
			save();
		});
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/Using-%23import-magic");
		el.title = "Allows setting up rules for shortening names per-script.";
		//
		addCheckbox(out, "Allow undo-ing `#import`", current.allowImportUndo, function(z) {
			current.allowImportUndo = z;
			save();
		}).title = "Allows undoing name changes made after changing #import rules."
			+ "\nMakes it easier to break code, so be careful.";
		//
		el = addCheckbox(out, "Use coroutine magic", current.coroutineMagic, function(z) {
			current.coroutineMagic = z;
			save();
		});
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/Using-coroutine-magic");
		//
		el = addCheckbox(out, "Use lambda magic", current.lambdaMagic, function(z) {
			current.lambdaMagic = z;
			save();
		});
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/Using-%23lambda-magic");
		//
		el = addCheckbox(out, "Use GMHyper magic", current.hyperMagic, function(z) {
			current.hyperMagic = z;
			save();
		});
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/GMHyper-in-GMEdit");
		//
		#if !lwedit
		var optGMLive = ["Hide", "Show on items", "Show everywhere"];
		el = addDropdown(out, "Show GMLive badges", optGMLive[current.showGMLive], optGMLive, function(v) {
			var v0:PrefGMLive = current.showGMLive;
			var v1:PrefGMLive = optGMLive.indexOf(v);
			if (v0 == v1) return;
			current.showGMLive = v1;
			if (gml.Project.current.hasGMLive) {
				if (v0.isActive() != v1.isActive()) {
					for (el in TreeView.element.querySelectorEls(".item")) {
						if (v1.isActive()) {
							var data = parsers.GmlSeekData.map[el.getAttribute(TreeView.attrPath)];
							if (data != null) {
								if (data.hasGMLive) {
									el.setAttribute(GMLive.attr, "");
								} else el.removeAttribute(GMLive.attr);
							}
						} else el.removeAttribute(GMLive.attr);
					}
				}
				GMLive.updateAll(true);
			}
			save();
		});
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/GMLive-in-GMEdit");
		#end
		//
		addCheckbox(out, "UK spelling", current.ukSpelling, function(z) {
			current.ukSpelling = z;
			GmlAPI.ukSpelling = z;
			GmlAPI.init();
			save();
		}).title = "Displays UK versions of function/variable names (e.g. draw_set_colour) in auto-completion when available.";
		//
		var compMatchModes = [
			"Start of string (GMS1 style)",
			"Containing (GMS2 style)",
			"Smart (`icl` -> `io_clear`)",
			"Per-section (`icl` -> `instance_create_layer`)",
		];
		el = addDropdown(out, "Auto-completion mode", compMatchModes[current.compMatchMode], compMatchModes, function(s) {
			current.compMatchMode = compMatchModes.indexOf(s);
			save();
		});
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/Preferences#auto-completion-mode");
		//
		addCheckbox(out, "Auto-detect soft tabs", current.detectTab, function(z) {
			current.detectTab = z;
			save();
		}).title = "If enabled, will auto-detect whether to indent with tabs or spaces"
			+ " based on whether the file has lines starting with either.";
		//
		#if !lwedit
		addCheckbox(out, "Open with single click", current.singleClickOpen, function(z) {
			current.singleClickOpen = z;
			save();
			gml.Project.current.reload();
		}).title = "Allows to open treeview items with single click";
		addCheckbox(out, "Show asset thumbnails", current.assetThumbs, function(z) {
			current.assetThumbs = z;
			save();
			gml.Project.current.reload();
		}).title = "Loads and displays the assigned sprites as object thumbnails in resource tree.";
		//
		var eventOrder = [
			"As authored",
			"By event type",
		];
		addDropdown(out, "GMS2 event order", eventOrder[current.eventOrder], eventOrder, function(s:String) {
			current.eventOrder = eventOrder.indexOf(s);
			save();
		});
		#end
		//
		var tooltipDelay:InputElement = null;
		var tooltipKinds = ["None", "Custom"];
		addDropdown(out, "Code tooltips", tooltipKinds[current.tooltipKind], tooltipKinds, function(s) {
			current.tooltipKind = tooltipKinds.indexOf(s);
			save();
		});
		addIntInput(out, "Code tooltip delay (ms):", current.tooltipDelay, function(t) {
			current.tooltipDelay = t;
			save();
		});
		//
		addFloatInput(out, "Keep file sessions for (days):", current.fileSessionTime, function(v) {
			current.fileSessionTime = v; save();
		});
		#if !lwedit
		addFloatInput(out, "Keep project sessions for (days):", current.projectSessionTime, function(v) {
			current.projectSessionTime = v; save();
		});
		addIntInput(out, "Max recent project count:", current.recentProjectCount, function(v) {
			current.recentProjectCount = v; save();
		});
		var fileChangeActions = [
			"Do nothing",
			"Ask what to do",
			"Reload unless conflicting",
		];
		addDropdown(out, "If the source file changes", fileChangeActions[current.fileChangeAction], fileChangeActions, function(v) {
			current.fileChangeAction = fileChangeActions.indexOf(v); save();
		});
		#end
		//
		var optSnippets_0 = ["gml", "gml_search", "shader"];
		var optSnippets_1 = ["GML", "Search results", "Shaders"];
		var optSnippets_select:SelectElement = null;
		el = addDropdown(out, "Edit snippets", "", optSnippets_1, function(name) {
			var mode = optSnippets_0[optSnippets_1.indexOf(name)];
			GmlFile.openTab(new GmlFile(mode + ".snippets", mode, KSnippets.inst));
			optSnippets_select.value = "";
		});
		addWiki(el, "https://github.com/GameMakerDiscord/GMEdit/wiki/Using-snippets");
		optSnippets_select = el.querySelectorAuto("select");
		//
		if (FileSystem.canSync) addButton(out, "Backup settings", function() {
			setMenu(menuBackups);
		});
		addButton(out, "Code Editor Settings", function() {
			AceWrap.loadModule("ace/ext/settings_menu", function(module) {
				module.init(Main.aceEditor);
				untyped Main.aceEditor.showSettingsMenu();
			});
		});
		//
		addButton(out, "Close", function() {
			element.style.display = "none";
		});
		//
		return out;
	}
	//
	private static var menuBackups:Element;
	private static function buildBackups() {
		var out = document.createElement("div");
		//
		addText(out, "Values are numbers of backup copies per file."
			+ " See wiki for more information.");
		addIntInput(out, "for GMS1 projects", current.backupCount.v1, function(n) {
			current.backupCount.v1 = n; save();
		});
		addIntInput(out, "for GMS2 projects", current.backupCount.v2, function(n) {
			current.backupCount.v2 = n; save();
		});
		addIntInput(out, "for other projects", current.backupCount.live, function(n) {
			current.backupCount.live = n; save();
		});
		//
		addButton(out, "Back", function() {
			setMenu(menuMain);
		});
		//
		return out;
	}
	//
	private static function build() {
		element = document.querySelector("#preferences-window");
		menuMain = buildMain();
		menuBackups = buildBackups();
	}
	private static function createValidIdFromString(str:String) {
		//Lower case everything
		str = str.toLowerCase();
		//Make alphanumeric (removes all other characters)
		var alphanumeric = ~/[^a-z0-9_\s-]/g;
		str = alphanumeric.replace(str, "");
		//Clean up multiple dashes or whitespaces
		var dashes = ~/[\s-]+/g;
		str = dashes.replace(str, "");
		//Convert whitespaces and underscore to dash
		var whitespace = ~/[\s_]/g;
		str = whitespace.replace(str, "");
		return str;
	}
	public static function open() {
		if (element == null) build();
		if (element.style.display == "none") {
			setMenu(menuMain);
			element.style.display = "";
		} else element.style.display = "none";
	}
	public static function save() {
		FileWrap.writeConfigSync("config", path, current);
	}
	public static function load() {
		var pref:PrefData = null;
		try {
			pref = FileWrap.readConfigSync("config", path);
		} catch (e:Dynamic) {
			console.error("Error loading preferences: ", e);
		}
		// migrations:
		if (pref.compMatchMode == null && pref.compExactMatch != null) {
			pref.compMatchMode = pref.compExactMatch ? PrefMatchMode.StartsWith : PrefMatchMode.AceSmart;
		}
		// default settings:
		var def:PrefData = {
			theme: "dark",
			ukSpelling: false,
			compMatchMode: PrefMatchMode.StartsWith,
			argsMagic: true,
			argsFormat: "@param",
			importMagic: true,
			allowImportUndo: false,
			coroutineMagic: true,
			lambdaMagic: true,
			hyperMagic: true,
			fileSessionTime: 7,
			projectSessionTime: 14,
			singleClickOpen: false,
			assetThumbs: true,
			showGMLive: Everywhere,
			fileChangeAction: Ask,
			backupCount: { v1: 2, v2: 0, live: 0 },
			recentProjectCount: 16,
			tabSize: 4,
			tabSpaces: true,
			detectTab: true,
			eventOrder: 1,
			tooltipDelay: 350,
			tooltipKind: Custom,
		};
		// load/merge defaults:
		var doSave = false;
		if (pref == null) {
			pref = def;
			doSave = true;
		} else NativeObject.forField(def, function(k) {
			if (Reflect.field(pref, k) == null) {
				Reflect.setField(pref, k, Reflect.field(def, k));
				doSave = true;
			}
		});
		//
		current = pref;
		if (doSave) save();
		//
		if (pref.theme != null) Theme.current = pref.theme;
		GmlAPI.ukSpelling = pref.ukSpelling;
	}
	public static function init() {
		var isMac:Bool;
		var ep = untyped window.process;
		if (ep == null) {
			var np = Main.window.navigator.platform;
			isMac = np != null && np.toLowerCase().indexOf("mac") >= 0;
		} else isMac = ep.platform == "darwin";
		FileWrap.isMac = isMac;
		load();
	}
	public static function hookSetOption(obj:Dynamic):Void {
		if (obj.setOption_raw != null) return;
		obj.setOption_raw = obj.setOption;
		obj.setOption = function(key:String, val:Dynamic) {
			obj.setOption_raw(key, val);
			if (key == "tabSize" && val != current.tabSize) {
				current.tabSize = Std.parseInt(val);
				save();
			}
			if (key == "useSoftTabs" && val != current.tabSpaces) {
				current.tabSpaces = val;
				save();
			}
			if (Main.aceEditor != null) {
				var opts:DynamicAccess<Dynamic> = Main.aceEditor.getOptions();
				opts.remove("enableLiveAutocompletion");
				opts.remove("theme");
				opts.remove("enableSnippets");
				FileWrap.writeConfigSync("config", "aceOptions", cast opts);
				//Main.console.log("Ace settings saved.");
			}
		};
	}
	public static function bindEditor(editor:AceWrap) {
		// load Ace options:
		try {
			var opts:DynamicAccess<Dynamic> = cast FileWrap.readConfigSync("config", "aceOptions");
			if (opts != null) {
				opts.set("enableSnippets", true);
				opts.remove("mode");
				editor.setOptions(opts);
			}
		} catch (e:Dynamic) {
			console.error("Error loading Ace options: " + e);
		};
		editor.setOption("fixedWidthGutter", true);
		// flush Ace options on changes (usually only via Ctrl+,):
		hookSetOption(editor);
		hookSetOption(editor.renderer);
		if (editor.getOption("fontFamily") == null) {
			var font = FileWrap.isMac ? "Menlo, monospace" : "Consolas, Courier New, monospace";
			editor.setOption("fontFamily", font);
		}
	}
}
typedef PrefData = {
	theme:String,
	ukSpelling:Bool,
	?compExactMatch:Bool, // deprecated
	compMatchMode:PrefMatchMode,
	fileSessionTime:Float,
	projectSessionTime:Float,
	argsMagic:Bool,
	argsFormat:String,
	importMagic:Bool,
	allowImportUndo:Bool,
	coroutineMagic:Bool,
	lambdaMagic:Bool,
	hyperMagic:Bool,
	assetThumbs:Bool,
	singleClickOpen:Bool,
	showGMLive:PrefGMLive,
	fileChangeAction:PrefFileChangeAction,
	recentProjectCount:Int,
	tabSize:Int,
	tabSpaces:Bool,
	detectTab:Bool,
	eventOrder:Int,
	backupCount:{ v1:Int, v2:Int, live:Int },
	tooltipKind:PrefTooltipKind,
	tooltipDelay:Int,
}
enum abstract PrefMatchMode(Int) from Int to Int {
	/// GMS1 style
	var StartsWith = 0;
	/// GMS2 style, "debug" for "show_[debug]_message"
	var Includes = 1;
	/// "icl" for "[i]o_[cl]ear"
	var AceSmart = 2;
	/// "icl" for "[i]nstance_[c]reate_[l]ayer"
	var SectionStart = 3;
}
@:enum abstract PrefTooltipKind(Int) from Int to Int {
	var None = 0;
	var Custom = 1;
}
@:enum abstract PrefFileChangeAction(Int) from Int to Int {
	var Nothing = 0;
	var Ask = 1;
	var Reload = 2;
}
@:enum abstract PrefGMLive(Int) from Int to Int {
	var Nowhere = 0;
	var ItemsOnly = 1;
	var Everywhere = 2;
	public inline function isActive():Bool {
		return this > 0;
	}
}

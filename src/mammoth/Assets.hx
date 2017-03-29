/*
 * Copyright (c) 2017 Kenton Hamaluik
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/
package mammoth;

import haxe.io.Bytes;
import haxe.Json;
import js.html.ArrayBuffer;
import js.html.DataView;
import js.html.XMLHttpRequest;
import js.html.XMLHttpRequestResponseType;
import mammoth.debug.Exception;
import promhx.Deferred;
import promhx.Promise;

@:build(mammoth.macros.Assets.buildAssetList())
class Assets {
	public static function load(path:String):Promise<Bytes> {
		var d:Deferred<Bytes> = new Deferred<Bytes>();
		var p:Promise<Bytes> = d.promise();

		var xhr:XMLHttpRequest = new XMLHttpRequest();
		xhr.open("GET", path, true);
		xhr.overrideMimeType("text/plain; charset=x-user-defined");
		xhr.responseType = XMLHttpRequestResponseType.ARRAYBUFFER;
		xhr.onload = function() {
			if(xhr.status >= 200 && xhr.status < 300) {
				var buffer:ArrayBuffer = cast xhr.response;
				var view:DataView = new DataView(buffer);
				var bytes:Bytes = Bytes.alloc(view.byteLength);
				for(i in 0...view.byteLength) bytes.set(i, view.getUint8(i));
				d.resolve(bytes);
			}
			else {
				d.throwError(new Exception('error ${xhr.status}: ${xhr.statusText}', false, 'HTTPResponse'));
			}
		};
		xhr.onerror = function() d.throwError(new Exception('unknown error', false, 'HTTPRequest'));
		xhr.onabort = function() d.throwError(new Exception('aborted', false, 'HTTPRequest'));
		xhr.ontimeout = function() d.throwError(new Exception('timed out', false, 'HTTPRequest'));
		xhr.send();

		return p;
	}

	public static function loadJSON(path:String):Promise<Dynamic> {
		var d:Deferred<Dynamic> = new Deferred<Dynamic>();
		var p:Promise<Dynamic> = d.promise();

		load(path)
			.then(function(b:Bytes) { d.resolve(Json.parse(b.toString())); })
			.catchError(function(e:Dynamic) { d.throwError(e); });

		return p;
	}
}
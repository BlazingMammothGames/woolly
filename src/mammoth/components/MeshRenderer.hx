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
package mammoth.components;

import edge.IComponent;
import mammoth.render.Material;
import mammoth.render.Mesh;

import glm.Mat4;

class MeshRenderer implements IComponent {
	public var material:Material;
	public var mesh:Mesh;

	public var MVP:Mat4 = Mat4.identity(new Mat4());

	public function new() {}

	public function setMesh(mesh:Mesh):MeshRenderer {
		this.mesh = mesh;
		return this;
	}

	public function setMaterial(material:Material):MeshRenderer {
		this.material = material;
		return this;
	}
}
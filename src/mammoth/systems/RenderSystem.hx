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
package mammoth.systems;

import mammoth.gl.types.TTextureWrap;
import mammoth.gl.types.TTextureFilter;
import edge.ISystem;
import edge.View;
import mammoth.components.MeshRenderer;
import mammoth.components.Transform;
import mammoth.components.Camera;
import mammoth.components.DirectionalLight;
import mammoth.components.PointLight;
import mammoth.Mammoth;
import mammoth.gl.GL;
import mammoth.types.Material;
import mammoth.types.Mesh;
import mammoth.types.MeshAttribute;
import mammoth.gl.UniformLocation;
import mammoth.gl.types.TCullMode;
import mammoth.gl.types.TUniformData;
import mammoth.gl.Texture;

class RenderSystem implements ISystem {
    var objects:View<{ transform:Transform, renderer:MeshRenderer }>;
    var directionalLights:View<{ transform:Transform, light:DirectionalLight }>;
    var pointLights:View<{ transform:Transform, light:PointLight }>;

    private var MVP:Mat4 = Mat4.identity(new Mat4());

    private var defaultMissingTexture:Texture = null;

    public function before():Void {
        if(defaultMissingTexture == null) {
            defaultMissingTexture = Mammoth.gl.loadTexture(null, TTextureFilter.Nearest, TTextureFilter.Nearest, TTextureWrap.Clamp);
        }
    }

    private inline function isInPlane(a:Float, b:Float, c:Float, d:Float, mesh:Mesh):Bool {
        // calculate p-vertex // see http://www.txutxi.com/?p=584
        var px:Float = a > 0 ? mesh.extentsMax.x : mesh.extentsMin.x;
        var py:Float = b > 0 ? mesh.extentsMax.y : mesh.extentsMin.y;
        var pz:Float = c > 0 ? mesh.extentsMax.z : mesh.extentsMin.z;

        // normalize the plane
        // TODO: not sure if this is necessary
        /*var mag:Float = Math.sqrt(a*a + b*b + c*c);
        a /= mag;
        b /= mag;
        c /= mag;
        d /= mag;*/

        // if ax + by + cz + d > 0, we're on the *in* side!
        return (a * px) + (b * py) + (c * pz) + d >= 0;
    }

    private function shouldCull(mvp:Mat4, renderer:MeshRenderer):Bool {
        // order can maybe be changed here to ditch early for things that are more likely
        // but this gets messed up by the transformation, since this is happening
        // in the object space rather than any global space

        // near
        if(!isInPlane(mvp.r3c0 + mvp.r2c0, mvp.r3c1 + mvp.r2c1, mvp.r3c2 + mvp.r2c2, mvp.r3c3 + mvp.r2c3, renderer.mesh))
            return true;
        // far
        if(!isInPlane(mvp.r3c0 - mvp.r2c0, mvp.r3c1 - mvp.r2c1, mvp.r3c2 - mvp.r2c2, mvp.r3c3 - mvp.r2c3, renderer.mesh))
            return true;
        // left
        if(!isInPlane(mvp.r3c0 + mvp.r0c0, mvp.r3c1 + mvp.r0c1, mvp.r3c2 + mvp.r0c2, mvp.r3c3 + mvp.r0c3, renderer.mesh))
            return true;
        // right
        if(!isInPlane(mvp.r3c0 - mvp.r0c0, mvp.r3c1 - mvp.r0c1, mvp.r3c2 - mvp.r0c2, mvp.r3c3 - mvp.r0c3, renderer.mesh))
            return true;
        // top
        if(!isInPlane(mvp.r3c0 - mvp.r1c0, mvp.r3c1 - mvp.r1c1, mvp.r3c2 - mvp.r1c2, mvp.r3c3 - mvp.r1c3, renderer.mesh))
            return true;
        // bottom
        if(!isInPlane(mvp.r3c0 + mvp.r1c0, mvp.r3c1 + mvp.r1c1, mvp.r3c2 + mvp.r1c2, mvp.r3c3 + mvp.r1c3, renderer.mesh))
            return true;

        return false;
    }

    public function update(camera:Camera) {
        // calculate the viewport
        var vpX:Int = Std.int(camera.viewportMin.x * Mammoth.width);
        var vpY:Int = Std.int(camera.viewportMin.y * Mammoth.height);
        var vpW:Int = Std.int((camera.viewportMax.x - camera.viewportMin.x) * Mammoth.width);
        var vpH:Int = Std.int((camera.viewportMax.y - camera.viewportMin.y) * Mammoth.height);

        // clear our region of the screen
        Mammoth.gl.viewport(vpX, vpY, vpW, vpH);
        Mammoth.gl.scissor(vpX, vpY, vpW, vpH);
        Mammoth.gl.clearColor(camera.clearColour);
        Mammoth.gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);

        // render each object!
        for(o in objects) {
            // cache the things we care about
            var transform:Transform = o.data.transform;
            var renderer:MeshRenderer = o.data.renderer;
            var mesh:Mesh = renderer.mesh;
            var material:Material = renderer.material;

            // calculate the MVP for this object
            Mat4.multMat(camera.vp, transform.m, MVP);

            // TODO: more organized culling?
            // note: culling is done in object space, so MVP **must**
            // be calculated before the culling equation!
            if(shouldCull(MVP, renderer))
                continue;

            // apply the states
            if(material.cullMode == TCullMode.None)
                Mammoth.gl.disable(GL.CULL_FACE);
            else {
                Mammoth.gl.enable(GL.CULL_FACE);
                Mammoth.gl.cullFace(cast(material.cullMode));
            }
            Mammoth.gl.depthMask(material.depthWrite);
            if(material.depthTest)
                Mammoth.gl.enable(GL.DEPTH_TEST);
            else
                Mammoth.gl.disable(GL.DEPTH_TEST);
            Mammoth.gl.depthFunc(cast(material.depthFunction));
            if(material.blend) {
                Mammoth.gl.enable(GL.BLEND);
                Mammoth.gl.blendFunc(cast(material.srcBlend), cast(material.dstBlend));
            }
            else {
                Mammoth.gl.disable(GL.BLEND);
            }

            // switch to our material's program
            Mammoth.gl.useProgram(material.program);

            // set the M, V, P uniforms
            if(material.hasUniform('MVP')) {
                Mammoth.gl.uniformMatrix4fv(material.uniformLocation('MVP'), cast(MVP));
            }
            if(material.hasUniform('M')) {
                Mammoth.gl.uniformMatrix4fv(material.uniformLocation('M'), cast(transform.m));
            }
            if(material.hasUniform('VP')) {
                Mammoth.gl.uniformMatrix4fv(material.uniformLocation('VP'), cast(camera.vp));
            }
            if(material.hasUniform('V')) {
                Mammoth.gl.uniformMatrix4fv(material.uniformLocation('V'), cast(camera.v));
            }
            if(material.hasUniform('P')) {
                Mammoth.gl.uniformMatrix4fv(material.uniformLocation('P'), cast(camera.p));
            }
        
            // TODO: sort lights based on distance
            if(material.hasUniform('directionalLights[0].direction')) {
                var i:Int = 0;
                // TODO: only set lights if they exist in the material
                for(dl in directionalLights) {
                    var light:DirectionalLight = dl.data.light;
                    Mammoth.gl.uniform3f(material.uniformLocation('directionalLights[${i}].direction'), light.direction.x, light.direction.y, light.direction.z);
                    Mammoth.gl.uniform3f(material.uniformLocation('directionalLights[${i}].colour'), light.colour.r, light.colour.g, light.colour.b);
                    i++;
                }
            }
            // TODO: sort lights based on distance
            if(material.hasUniform('pointLights[0].position')) {
                var i:Int = 0;
                // TODO: only set lights if they exist in the material
                for(pl in pointLights) {
                    Mammoth.gl.uniform3f(material.uniformLocation('pointLights[${i}].position'),
                        pl.data.transform.position.x, pl.data.transform.position.y, pl.data.transform.position.z);
                    Mammoth.gl.uniform3f(material.uniformLocation('pointLights[${i}].colour'),
                        pl.data.light.colour.r, pl.data.light.colour.g, pl.data.light.colour.b);
                    Mammoth.gl.uniform1f(material.uniformLocation('pointLights[${i}].distance'), pl.data.light.distance);
                    i++;
                }
            }
            // TODO: spotlights

            // apply textures
            for(i in 0...material.textureSlots) {
                Mammoth.gl.activeTexture(GL.TEXTURE0 + i);
                if(i >= renderer.materialData.textures.length) {
                    Mammoth.gl.bindTexture(GL.TEXTURE_2D, defaultMissingTexture);
                }
                else {
                    Mammoth.gl.bindTexture(GL.TEXTURE_2D, renderer.materialData.textures[i].tex);
                }
            }

            // apply material data
            for(dataName in renderer.materialData.uniformValues.keys()) {
                if(!material.hasUniform(dataName)) continue;

                var location:UniformLocation = material.uniformLocation(dataName);
                var data:TUniformData = renderer.materialData.uniformValues.get(dataName);
                switch(data) {
                    case Bool(b): Mammoth.gl.uniform1i(location, b ? 1 : 0);
                    case Int(i): Mammoth.gl.uniform1i(location, i);
                    case Float(x): Mammoth.gl.uniform1f(location, x);
                    case Float2(x, y): Mammoth.gl.uniform2f(location, x, y);
                    case Float3(x, y, z): Mammoth.gl.uniform3f(location, x, y, z);
                    case Float4(x, y, z, w): Mammoth.gl.uniform4f(location, x, y, z, w);
                    case Vector2(v): Mammoth.gl.uniform2f(location, v.x, v.y);
                    case Vector3(v): Mammoth.gl.uniform3f(location, v.x, v.y, v.z);
                    case Vector4(v): Mammoth.gl.uniform4f(location, v.x, v.y, v.z, v.w);
                    case Matrix4(m): Mammoth.gl.uniformMatrix4fv(location, cast(m));
                    case RGB(c): Mammoth.gl.uniform3f(location, c.r, c.g, c.b);
                    case RGBA(c): Mammoth.gl.uniform4f(location, c.r, c.g, c.b, c.a);
                    case TextureSlot(x): Mammoth.gl.uniform1i(location, x);
                }
            }

            // set up the attributes
            Mammoth.gl.bindBuffer(GL.ARRAY_BUFFER, mesh.vertexBuffer);
            for(materialAttribute in material.attributes) {
                if(!mesh.hasAttribute(materialAttribute.name))
                    throw new mammoth.debug.Exception('Can\t use material ${material.name} with mesh ${mesh.name} as mesh is missing attribute ${materialAttribute.name}!', true);
                var meshAttribute:MeshAttribute = mesh.getAttribute(materialAttribute.name);

                Mammoth.gl.enableVertexAttribArray(materialAttribute.location);
                Mammoth.gl.vertexAttribPointer(materialAttribute.location,
                    switch(meshAttribute.type) {
                        case Float: 1;
                        case Vec2: 2;
                        case Vec3: 3;
                        case Vec4: 4;
                    },
                    GL.FLOAT,
                    false,
                    meshAttribute.stride, meshAttribute.offset);
            }

            // bind the index buffer to the vertices for triangles
            Mammoth.gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, mesh.indexBuffer);

            // and draw those suckers!
            Mammoth.gl.drawElements(GL.TRIANGLES, mesh.indexCount, GL.UNSIGNED_SHORT, 0);
            Mammoth.stats.drawCalls++;
            Mammoth.stats.triangles += Std.int(mesh.indexCount / 3);

            // disable the attrib arrays!
            for(materialAttribute in material.attributes) {
                Mammoth.gl.disableVertexAttribArray(materialAttribute.location);
            }
        }
    }
}
